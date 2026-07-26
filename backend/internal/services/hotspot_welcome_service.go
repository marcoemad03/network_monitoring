package services

import (
	"context"
	"fmt"
	"html/template"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

var (
	hotspotColorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)
	hotspotNamePattern  = regexp.MustCompile(`^[A-Za-z0-9_. -]{1,64}$`)
	hotspotDirPattern   = regexp.MustCompile(`^[A-Za-z0-9_.-]{1,64}$`)
)

type HotspotWelcomeService struct {
	repo *repository.HotspotWelcomeRepository
}

func NewHotspotWelcomeService(repo *repository.HotspotWelcomeRepository) *HotspotWelcomeService {
	return &HotspotWelcomeService{repo: repo}
}

func DefaultHotspotWelcomeConfig(orgID uuid.UUID) *models.HotspotWelcomeConfig {
	return &models.HotspotWelcomeConfig{OrganizationID: orgID, HospitalName: "Hospital Guest Wi-Fi", PrimaryColor: "#0B6E69", AccentColor: "#F2B134", WelcomeMessage: "Welcome. Sign in to access the hospital guest network.", Announcements: []string{}, Enabled: true}
}

func (s *HotspotWelcomeService) Get(ctx context.Context, orgID uuid.UUID) (*models.HotspotWelcomeConfig, error) {
	config, err := s.repo.Get(ctx, orgID)
	if repository.IsHotspotWelcomeNotFound(err) {
		return DefaultHotspotWelcomeConfig(orgID), nil
	}
	return config, err
}

func (s *HotspotWelcomeService) Save(ctx context.Context, config *models.HotspotWelcomeConfig) error {
	config.HospitalName = strings.TrimSpace(config.HospitalName)
	config.LogoURL = strings.TrimSpace(config.LogoURL)
	config.WelcomeMessage = strings.TrimSpace(config.WelcomeMessage)
	if config.HospitalName == "" || len(config.HospitalName) > 200 {
		return fmt.Errorf("hospital_name must be between 1 and 200 characters")
	}
	if !hotspotColorPattern.MatchString(config.PrimaryColor) || !hotspotColorPattern.MatchString(config.AccentColor) {
		return fmt.Errorf("colors must use #RRGGBB format")
	}
	if config.LogoURL != "" {
		u, err := url.Parse(config.LogoURL)
		if err != nil || (u.IsAbs() && u.Scheme != "https" && u.Scheme != "http") || strings.HasPrefix(config.LogoURL, "//") {
			return fmt.Errorf("logo_url must be an HTTP(S) URL or relative hotspot path")
		}
	}
	if len(config.WelcomeMessage) > 2000 || len(config.Announcements) > 20 {
		return fmt.Errorf("welcome message or announcements exceed allowed size")
	}
	for i := range config.Announcements {
		config.Announcements[i] = strings.TrimSpace(config.Announcements[i])
		if len(config.Announcements[i]) > 500 {
			return fmt.Errorf("announcement exceeds 500 characters")
		}
	}
	return s.repo.Upsert(ctx, config)
}

func (s *HotspotWelcomeService) Generate(ctx context.Context, orgID uuid.UUID) ([]byte, error) {
	config, err := s.Get(ctx, orgID)
	if err != nil {
		return nil, err
	}
	return GenerateHotspotLoginHTML(config)
}

func (s *HotspotWelcomeService) ConfigureProfile(endpoint, username, password, profile, htmlDirectory string) (*models.HotspotProfileResult, error) {
	profile, htmlDirectory = strings.TrimSpace(profile), strings.TrimSpace(htmlDirectory)
	if !hotspotNamePattern.MatchString(profile) || !hotspotDirPattern.MatchString(htmlDirectory) {
		return nil, fmt.Errorf("profile or html_directory contains unsupported characters")
	}
	client, err := mikrotik.NewClientFromEndpoint(endpoint, username, password, 10*time.Second)
	if err != nil {
		return nil, err
	}
	profiles, err := client.RouterOSCommand("/ip/hotspot/profile/print")
	if err != nil {
		return nil, err
	}
	var id string
	for _, candidate := range profiles {
		if candidate["name"] == profile {
			id = candidate[".id"]
			break
		}
	}
	if id == "" {
		return nil, fmt.Errorf("hotspot profile %q was not found", profile)
	}
	if _, err := client.ExecuteCommand("/ip/hotspot/profile/set", map[string]string{".id": id, "html-directory": htmlDirectory}); err != nil {
		return nil, err
	}
	return &models.HotspotProfileResult{ProfileConfigured: true, FileUploaded: false, HTMLDirectory: htmlDirectory, Message: "RouterOS profile configured. The native RouterOS v6 API did not upload login.html; download it and transfer it into the selected Files directory."}, nil
}

type hotspotTemplateData struct {
	HospitalName, LogoURL, PrimaryColor, AccentColor, WelcomeMessage string
	Announcements                                                    []string
	Enabled                                                          bool
}

func GenerateHotspotLoginHTML(config *models.HotspotWelcomeConfig) ([]byte, error) {
	data := hotspotTemplateData{config.HospitalName, config.LogoURL, config.PrimaryColor, config.AccentColor, config.WelcomeMessage, config.Announcements, config.Enabled}
	var output strings.Builder
	if err := template.Must(template.New("login").Parse(hotspotLoginTemplate)).Execute(&output, data); err != nil {
		return nil, err
	}
	return []byte(output.String()), nil
}

const hotspotLoginTemplate = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{{.HospitalName}} Wi-Fi</title><style>
:root{--primary:{{.PrimaryColor}};--accent:{{.AccentColor}}}*{box-sizing:border-box}body{margin:0;font-family:Arial,sans-serif;background:linear-gradient(145deg,var(--primary),#102a43);color:#17324d;min-height:100vh;display:grid;place-items:center;padding:20px}.card{width:min(440px,100%);background:#fff;border-radius:18px;padding:30px;box-shadow:0 20px 60px #0005}.logo{display:block;max-width:180px;max-height:72px;margin:0 auto 18px}h1{margin:0;text-align:center;color:var(--primary);font-size:25px}.meta,.greeting{text-align:center}.meta{color:#60758a;font-size:13px}.greeting{font-size:17px;font-weight:bold;margin:18px 0 6px}.message{line-height:1.5}.announcements{border-left:4px solid var(--accent);background:#fff8e5;padding:10px 14px;margin:18px 0}.announcements p{margin:6px 0}.error{background:#fee2e2;color:#991b1b;padding:10px;border-radius:8px}label{display:block;font-size:13px;font-weight:bold;margin:14px 0 6px}input{width:100%;padding:12px;border:1px solid #bdc9d4;border-radius:9px;font-size:16px}button{width:100%;margin-top:20px;padding:13px;border:0;border-radius:9px;background:var(--accent);color:#17202a;font-weight:bold;font-size:16px;cursor:pointer}.disabled{padding:16px;text-align:center;background:#edf2f7;border-radius:9px}</style></head>
<body><main class="card">{{if .LogoURL}}<img class="logo" src="{{.LogoURL}}" alt="{{.HospitalName}} logo">{{end}}<h1>{{.HospitalName}}</h1><p class="meta"><span id="date">$(date)</span> <span id="time"></span></p><p class="greeting"><span id="greeting">Welcome</span>, <span id="guest-name">$(if username)$(username)$(else)Guest$(endif)</span></p><p class="message">{{.WelcomeMessage}}</p>
{{if .Announcements}}<section class="announcements" aria-label="Announcements">{{range .Announcements}}<p>{{.}}</p>{{end}}</section>{{end}}
$(if error)<p class="error">$(error)</p>$(endif)
{{if .Enabled}}$(if chap-id)<form name="sendin" action="$(link-login-only)" method="post"><input type="hidden" name="username"><input type="hidden" name="password"><input type="hidden" name="dst" value="$(link-orig)"><input type="hidden" name="popup" value="true"></form><script src="/md5.js"></script>$(endif)
<form name="login" action="$(link-login-only)" method="post" onsubmit="return submitLogin()"><input type="hidden" name="dst" value="$(link-orig)"><input type="hidden" name="popup" value="true"><label for="username">Username</label><input id="username" name="username" value="$(username)" autocomplete="username" required><label for="password">Password</label><input id="password" name="password" type="password" autocomplete="current-password" required><button type="submit">Connect securely</button></form>{{else}}<div class="disabled">Guest Wi-Fi access is currently unavailable.</div>{{end}}</main>
<script>(function(){var now=new Date(),hour=now.getHours(),g=hour<12?'Good morning':hour<18?'Good afternoon':'Good evening';document.getElementById('greeting').textContent=g;document.getElementById('date').textContent=now.toLocaleDateString();document.getElementById('time').textContent=now.toLocaleTimeString([], {hour:'2-digit',minute:'2-digit'});var u=document.getElementById('username');if(u)u.addEventListener('input',function(){document.getElementById('guest-name').textContent=u.value.trim()||'Guest'})})();function submitLogin(){$(if chap-id)document.sendin.username.value=document.login.username.value;document.sendin.password.value=hexMD5('$(chap-id)'+document.login.password.value+'$(chap-challenge)');document.sendin.submit();return false;$(else)return true;$(endif)}</script></body></html>`
