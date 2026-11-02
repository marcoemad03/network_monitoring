package services

import (
	"fmt"
	"net"
	"net/netip"
	"sort"
	"strings"

	"golang.org/x/net/idna"
	"golang.org/x/net/publicsuffix"
)

// SitePack is a ready-made set of sites a group can block in one tick. A pack lists
// platforms (blocked the way each platform is already blocked) and plain domains
// (looked up and blocked by address).
type SitePack struct {
	Key         string   `json:"key"`
	Label       string   `json:"label"`
	Description string   `json:"description"`
	Icon        string   `json:"icon"`
	Platforms   []string `json:"platforms,omitempty"`
	Domains     []string `json:"domains"`
}

// MarcoSitePacks is the catalog shown when blocking sites. Domains are the sites
// people actually use; the lists are meant to be edited by adding sites by hand.
var MarcoSitePacks = []SitePack{
	{
		Key: "games", Label: "Games", Icon: "sports_esports",
		Description: "Game stores, launchers and online game services, including the popular mobile games.",
		Platforms:   []string{"steam", "epicgames"},
		Domains: []string{
			"roblox.com", "rbxcdn.com", "minecraft.net", "mojang.com", "riotgames.com", "leagueoflegends.com",
			"playvalorant.com", "battle.net", "blizzard.com", "ea.com", "origin.com", "ubisoft.com", "pubg.com",
			"pubgmobile.com", "krafton.com", "garena.com", "supercell.com", "callofduty.com", "activision.com",
			"moonton.com", "mobilelegends.com", "miniclip.com", "poki.com", "crazygames.com", "y8.com", "friv.com",
			"kongregate.com", "itch.io", "gog.com",
		},
	},
	{
		Key: "social", Label: "Social media", Icon: "groups",
		Description: "Facebook, Instagram, TikTok, X, Snapchat, Pinterest and similar.",
		Platforms:   []string{"facebook", "instagram", "tiktok", "twitter", "reddit"},
		Domains:     []string{"snapchat.com", "sc-cdn.net", "pinterest.com", "pinimg.com", "threads.net", "tumblr.com"},
	},
	{
		Key: "video", Label: "Video and streaming", Icon: "smart_display",
		Description: "YouTube, Netflix, Twitch and other video services.",
		Platforms:   []string{"youtube", "netflix"},
		Domains: []string{
			"twitch.tv", "ttvnw.net", "vimeo.com", "dailymotion.com", "primevideo.com", "disneyplus.com",
			"hbomax.com", "max.com", "shahid.net", "hulu.com", "crunchyroll.com",
		},
	},
	{
		Key: "music", Label: "Music", Icon: "music_note",
		Description: "Music streaming services.",
		Domains:     []string{"spotify.com", "scdn.co", "anghami.com", "soundcloud.com", "deezer.com", "tidal.com"},
	},
	{
		Key: "messaging", Label: "Chat apps", Icon: "chat",
		Description: "Telegram, Discord, WhatsApp Web and other chat services.",
		Platforms:   []string{"telegram", "whatsappweb", "discord"},
		Domains:     []string{"signal.org", "viber.com", "line.me", "wechat.com"},
	},
	{
		Key: "ai", Label: "AI assistants", Icon: "smart_toy",
		Description: "ChatGPT, Gemini, Claude, Copilot and other AI tools.",
		Platforms:   []string{"chatgpt", "gemini", "claude", "copilot"},
		Domains:     []string{"perplexity.ai", "character.ai", "poe.com", "deepseek.com", "midjourney.com", "huggingface.co"},
	},
	{
		Key: "torrents", Label: "Torrents and file sharing", Icon: "cloud_download",
		Description: "Torrent sites and clients' websites.",
		Domains: []string{
			"thepiratebay.org", "1337x.to", "yts.mx", "nyaa.si", "limetorrents.info", "utorrent.com",
			"bittorrent.com", "qbittorrent.org",
		},
	},
	{
		Key: "vpn", Label: "VPN and proxy sites", Icon: "vpn_lock",
		Description: "Websites that sell or download VPNs. A VPN that is already installed keeps working.",
		Domains: []string{
			"nordvpn.com", "expressvpn.com", "protonvpn.com", "surfshark.com", "windscribe.com", "tunnelbear.com",
			"hotspotshield.com", "hide.me", "privateinternetaccess.com", "cyberghostvpn.com", "ipvanish.com",
			"psiphon.ca", "hola.org", "torproject.org", "browsec.com", "urban-vpn.com", "betternet.co",
		},
	},
}

var sitePackByKey = func() map[string]SitePack {
	m := make(map[string]SitePack, len(MarcoSitePacks))
	for _, p := range MarcoSitePacks {
		m[p.Key] = p
	}
	return m
}()

// DefaultAllowedDomains keep working for every group even when a block would
// otherwise catch the address they share. YouTube's API, Firebase, Translate and
// Google's other services run on the same Google addresses, so blocking one by
// address breaks the rest unless these are let through first.
var DefaultAllowedDomains = []string{
	"www.google.com", "accounts.google.com", "mail.google.com", "smtp.gmail.com", "imap.gmail.com",
	"translate.google.com", "translate.googleapis.com", "www.googleapis.com", "fonts.googleapis.com",
	"fonts.gstatic.com", "www.gstatic.com", "connectivitycheck.gstatic.com", "android.clients.google.com",
	"firebaseinstallations.googleapis.com", "firestore.googleapis.com", "firebase.googleapis.com",
	"fcm.googleapis.com", "mtalk.google.com", "play.googleapis.com", "play.google.com", "firebaseio.com",
	"www.msftconnecttest.com", "login.microsoftonline.com", "outlook.office365.com", "download.windowsupdate.com",
}

// ---------------------------------------------------------------------------
// What a typed site can be

// SiteKind says what the user typed.
type SiteKind string

const (
	SiteDomain SiteKind = "domain"
	SiteIP     SiteKind = "ip"
	SiteCIDR   SiteKind = "cidr"
)

// SiteInputError explains why something typed cannot be blocked.
type SiteInputError struct{ Message string }

func (e *SiteInputError) Error() string { return e.Message }

// NormalizeSite turns what the user typed (a website address, a domain, an IPv4
// address or a small network) into the form that is stored.
func NormalizeSite(raw string) (string, SiteKind, error) {
	v := strings.TrimSpace(strings.ToLower(raw))
	if v == "" {
		return "", "", &SiteInputError{"Type a website such as example.com"}
	}
	if i := strings.Index(v, "://"); i >= 0 {
		v = v[i+3:]
	}
	if p, err := netip.ParsePrefix(v); err == nil {
		if !p.Addr().Is4() {
			return "", "", &SiteInputError{"Only IPv4 addresses can be blocked"}
		}
		if p.Bits() < 20 {
			return "", "", &SiteInputError{"That network is too large. Use /20 or smaller."}
		}
		if err := checkBlockableAddr(p.Addr()); err != nil {
			return "", "", err
		}
		return p.Masked().String(), SiteCIDR, nil
	}
	if i := strings.IndexAny(v, "/?#"); i >= 0 {
		v = v[:i]
	}
	if at := strings.LastIndexByte(v, '@'); at >= 0 {
		v = v[at+1:]
	}
	if strings.Count(v, ":") == 1 {
		v = v[:strings.LastIndexByte(v, ':')] // drop a port
	}
	v = strings.TrimSuffix(v, ".")
	if v == "" {
		return "", "", &SiteInputError{"Type a website such as example.com"}
	}
	if a, err := netip.ParseAddr(v); err == nil {
		if !a.Is4() {
			return "", "", &SiteInputError{"Only IPv4 addresses can be blocked"}
		}
		if err := checkBlockableAddr(a); err != nil {
			return "", "", err
		}
		return a.String(), SiteIP, nil
	}
	v = strings.TrimPrefix(v, "www.")
	ascii, err := idna.Lookup.ToASCII(v)
	if err != nil {
		return "", "", &SiteInputError{"That does not look like a website name"}
	}
	v = ascii
	if len(v) > 253 || !strings.Contains(v, ".") {
		return "", "", &SiteInputError{"Type the full website name, such as example.com"}
	}
	for _, label := range strings.Split(v, ".") {
		if label == "" || len(label) > 63 || label[0] == '-' || label[len(label)-1] == '-' {
			return "", "", &SiteInputError{"That does not look like a website name"}
		}
		for _, c := range label {
			if !(c >= 'a' && c <= 'z' || c >= '0' && c <= '9' || c == '-') {
				return "", "", &SiteInputError{"That does not look like a website name"}
			}
		}
	}
	if suffix, icann := publicsuffix.PublicSuffix(v); icann && suffix == v {
		return "", "", &SiteInputError{"Type a full website name, such as example.com, not just an ending like .com"}
	}
	return v, SiteDomain, nil
}

func checkBlockableAddr(a netip.Addr) error {
	if a.IsPrivate() || a.IsLoopback() || a.IsLinkLocalUnicast() || a.IsMulticast() || a.IsUnspecified() {
		return &SiteInputError{"That is a private address inside the hospital, not a website"}
	}
	return nil
}

// normalizeSites cleans a list of typed sites, dropping what cannot be blocked and
// duplicates, and keeps the order stable.
func normalizeSites(raw []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, r := range raw {
		v, _, err := NormalizeSite(r)
		if err != nil || seen[v] {
			continue
		}
		seen[v] = true
		out = append(out, v)
	}
	sort.Strings(out)
	return out
}

func normalizedPacks(raw []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, r := range raw {
		k := strings.ToLower(strings.TrimSpace(r))
		if _, ok := sitePackByKey[k]; ok && !seen[k] {
			seen[k] = true
			out = append(out, k)
		}
	}
	sort.Strings(out)
	return out
}

// groupBlockTargets lists everything a group's policy blocks by address: the
// domains of its packs plus the sites typed by hand. Platforms are handled on
// their own.
func groupBlockTargets(blockedPacks, blockedDomains []string) (domains, ips []string, platforms []string) {
	seen := map[string]bool{}
	add := func(v string) {
		if seen[v] {
			return
		}
		seen[v] = true
		if _, kind, err := NormalizeSite(v); err == nil && kind != SiteDomain {
			ips = append(ips, v)
		} else {
			domains = append(domains, v)
		}
	}
	platSeen := map[string]bool{}
	for _, k := range normalizedPacks(blockedPacks) {
		p := sitePackByKey[k]
		for _, pl := range p.Platforms {
			if !platSeen[pl] {
				platSeen[pl] = true
				platforms = append(platforms, pl)
			}
		}
		for _, d := range p.Domains {
			add(d)
		}
	}
	for _, d := range normalizedSites(blockedDomains) {
		add(d)
	}
	sort.Strings(domains)
	sort.Strings(ips)
	sort.Strings(platforms)
	return
}

func normalizedSites(raw []string) []string { return normalizeSites(raw) }

// ---------------------------------------------------------------------------
// Addresses that cannot be blocked without breaking other sites

var sharedRangeNames = []struct {
	name  string
	cidrs []string
}{
	{"Cloudflare", []string{
		"173.245.48.0/20", "103.21.244.0/22", "103.22.200.0/22", "103.31.4.0/22", "141.101.64.0/18",
		"108.162.192.0/18", "190.93.240.0/20", "188.114.96.0/20", "197.234.240.0/22", "198.41.128.0/17",
		"162.158.0.0/15", "104.16.0.0/13", "104.24.0.0/14", "172.64.0.0/13", "131.0.72.0/22",
	}},
	{"Fastly", []string{"151.101.0.0/16", "199.232.0.0/16", "146.75.0.0/16"}},
	{"Google", youtubeIPRanges},
}

type sharedNet struct {
	name string
	net  *net.IPNet
}

var sharedNets = func() []sharedNet {
	var out []sharedNet
	for _, g := range sharedRangeNames {
		for _, c := range g.cidrs {
			if _, n, err := net.ParseCIDR(c); err == nil {
				out = append(out, sharedNet{g.name, n})
			}
		}
	}
	return out
}()

// sharedProvider names the provider when the address belongs to space that serves
// thousands of unrelated sites, so blocking it would break them too.
func sharedProvider(ip net.IP) string {
	for _, s := range sharedNets {
		if s.net.Contains(ip) {
			return s.name
		}
	}
	return ""
}

func describeShared(provider string) string {
	return fmt.Sprintf("hosted on %s, shared with thousands of other sites, so it cannot be blocked by address without breaking them", provider)
}

// isMainDomain reports whether a name is a site's main domain (example.com or
// example.co.uk) rather than one of its subdomains. A top-level domain the list
// does not know is treated by its last label.
func isMainDomain(name string) bool {
	suffix, _ := publicsuffix.PublicSuffix(name)
	rest := strings.TrimSuffix(name, "."+suffix)
	return rest != name && rest != "" && !strings.Contains(rest, ".")
}
