package services

import (
	"context"
	"errors"
	"fmt"
	"net"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

var platformDomains = map[string][]string{
	"youtube":    {"youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "ggpht.com", "googleapis.com", "youtubei.googleapis.com", "youtube-nocookie.com"},
	"facebook":   {"facebook.com", "fbcdn.net", "fb.com", "messenger.com"},
	"tiktok":     {"tiktok.com", "tiktokcdn.com", "tiktokv.com", "musical.ly"},
	"instagram":  {"instagram.com", "cdninstagram.com"},
}

var platformIPRanges = map[string][]string{
	"youtube": {
		"173.194.0.0/16", "74.125.0.0/16", "216.58.0.0/16", "172.217.0.0/16",
		"172.253.0.0/16", "142.250.0.0/16", "142.251.0.0/16", "108.177.0.0/16",
		"216.239.32.0/19", "64.233.160.0/19", "66.249.64.0/19", "72.14.192.0/18",
		"209.85.128.0/17", "35.184.0.0/16", "35.186.0.0/16", "35.188.0.0/16",
		"35.190.0.0/16", "35.192.0.0/16", "35.196.0.0/16", "35.198.0.0/16",
		"35.200.0.0/16", "35.201.0.0/16", "35.202.0.0/16", "35.203.0.0/16",
		"35.204.0.0/16", "35.205.0.0/16", "35.206.0.0/16", "35.207.0.0/16",
		"35.208.0.0/16", "35.209.0.0/16", "35.210.0.0/16", "35.211.0.0/16",
		"35.212.0.0/16", "35.213.0.0/16", "35.214.0.0/16", "35.215.0.0/16",
		"35.216.0.0/16", "35.217.0.0/16", "35.220.0.0/16", "35.221.0.0/16",
		"35.222.0.0/16", "35.223.0.0/16", "35.224.0.0/16", "35.225.0.0/16",
		"35.226.0.0/16", "35.227.0.0/16", "35.228.0.0/16", "35.229.0.0/16",
		"35.230.0.0/16", "35.231.0.0/16", "35.232.0.0/16", "35.233.0.0/16",
		"35.234.0.0/16", "35.235.0.0/16", "35.236.0.0/16", "35.237.0.0/16",
		"35.238.0.0/16", "35.239.0.0/16", "35.240.0.0/16", "35.241.0.0/16",
		"35.242.0.0/16", "35.243.0.0/16", "35.244.0.0/16", "35.245.0.0/16",
		"35.246.0.0/16", "35.247.0.0/16", "104.154.0.0/15", "104.196.0.0/14",
		"107.167.160.0/19", "107.178.192.0/18", "130.211.0.0/16", "146.148.0.0/17",
		"162.216.148.0/22", "162.222.176.0/21", "172.110.32.0/21", "173.255.112.0/20",
		"192.158.28.0/22", "193.186.4.0/24", "199.192.112.0/22", "199.223.232.0/21",
		"207.223.160.0/20", "208.68.108.0/23", "209.85.128.0/17",
	},
}

const managedPlatformAddressList = "nms-blocked-platforms"
const managedPlatformDNS = "nms-dns-blocked"
const managedPolicyPrefix = "nms-policy-"

var ErrPolicyUnsupported = errors.New("policy type is not safely enforceable on MikroTik")

type routerCommander interface {
	Command(string, ...string) ([]map[string]string, error)
	Close() error
}

type desiredRouterEntry struct {
	path  string
	attrs map[string]string
}

type PolicySyncService struct {
	assetRepo    *repository.AssetRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	hub          *websocket.Hub
	telegramSvc  *TelegramService
	dialRouter   func(*models.VendorIntegration) (routerCommander, error)
}

func NewPolicySyncService(assetRepo *repository.AssetRepository, internetRepo *repository.InternetRepository, cfg *config.Config, hub *websocket.Hub, telegramSvc *TelegramService) *PolicySyncService {
	s := &PolicySyncService{assetRepo: assetRepo, internetRepo: internetRepo, cfg: cfg, hub: hub, telegramSvc: telegramSvc}
	s.dialRouter = s.dial
	return s
}

func (s *PolicySyncService) SyncPoliciesToMikroTik(ctx context.Context, orgID uuid.UUID) error {
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return fmt.Errorf("active MikroTik integration is not configured: %w", err)
	}
	log := &models.SyncLog{ID: uuid.New(), OrganizationID: orgID, VendorIntegrationID: &vendor.ID, Status: "in_progress", Details: map[string]interface{}{"started_at": time.Now().Format(time.RFC3339)}}
	_ = s.assetRepo.CreateSyncLog(ctx, log)

	targets, err := s.assetRepo.ListAssignedPolicyDevices(ctx, orgID)
	if err != nil {
		return s.fail(ctx, log, fmt.Errorf("resolve policy assignments: %w", err))
	}
	firewall, queues, err := desiredEntries(targets)
	if err != nil {
		return s.fail(ctx, log, err)
	}
	conn, err := s.dialRouter(vendor)
	if err != nil {
		return s.fail(ctx, log, fmt.Errorf("connect MikroTik: %w", err))
	}
	defer conn.Close()

	if err := reconcileEntries(conn, "/ip/firewall/filter", firewall); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile Internet access rules: %w", err))
	}
	if err := reconcileEntries(conn, "/queue/simple", queues); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile bandwidth queues: %w", err))
	}
	if err := s.reconcilePlatformAddressLists(ctx, conn, targets); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform address lists: %w", err))
	}
	if err := s.reconcilePlatformLayer7(ctx, conn, targets); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform layer7 protocols: %w", err))
	}
	if err := s.reconcilePlatformDNS(ctx, conn, targets); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform DNS blocks: %w", err))
	}

	log.ID = uuid.New()
	log.Status = "completed"
	log.Details = map[string]interface{}{"targets": len(targets), "firewall_rules": len(firewall), "queues": len(queues), "completed_at": time.Now().Format(time.RFC3339)}
	_ = s.assetRepo.CreateSyncLog(ctx, log)

	if len(targets) > 0 {
		if s.hub != nil {
			s.hub.BroadcastMessage("notification", models.LiveNotification{
				Title:   "Policy sync completed",
				Message: fmt.Sprintf("Synced %d policy rules to MikroTik (%d firewall, %d bandwidth queues)", len(targets), len(firewall), len(queues)),
				Type:    "policy_sync",
			})
		}
		if s.telegramSvc != nil {
			go func() {
				for _, target := range targets {
					d := target.Device
					mac := ""
					if d.MACAddress != nil {
						mac = *d.MACAddress
					}
					ip := ""
					if d.IPAddress != nil {
						ip = d.IPAddress.String()
					}
					_ = s.telegramSvc.Notify(context.Background(), target.Policy.OrganizationID, models.TelegramEventPolicyViolation, mac, d.Name, ip, "")
				}
			}()
		}
	}
	return nil
}

func (s *PolicySyncService) fail(ctx context.Context, log *models.SyncLog, err error) error {
	log.ID = uuid.New()
	log.Status = "failed"
	log.Details = map[string]interface{}{"error": err.Error(), "failed_at": time.Now().Format(time.RFC3339)}
	_ = s.assetRepo.CreateSyncLog(ctx, log)
	return err
}

func (s *PolicySyncService) dial(vendor *models.VendorIntegration) (routerCommander, error) {
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, s.cfg.MikroTikAPITimeout)
	if err != nil {
		return nil, err
	}
	conn := mikrotik.NewAPIConnection(client.Host(), client.Port(), client.Username(), client.Password(), s.cfg.MikroTikAPITimeout)
	if err := conn.Connect(); err != nil {
		return nil, err
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, err
	}
	return conn, nil
}

func desiredEntries(targets []models.AssignedPolicyDevice) (map[string]desiredRouterEntry, map[string]desiredRouterEntry, error) {
	firewall := make(map[string]desiredRouterEntry)
	queues := make(map[string]desiredRouterEntry)
	for _, target := range targets {
		p, d := target.Policy, target.Device
		if d.MACAddress == nil || strings.TrimSpace(*d.MACAddress) == "" || d.IPAddress == nil || d.IPAddress.IsUnspecified() {
			return nil, nil, fmt.Errorf("policy %s device %s has no current MAC/IP identity", p.ID, d.ID)
		}
		comment := managedPolicyPrefix + p.ID.String() + "-" + d.ID.String()
		switch p.PolicyType {
		case "internet_access":
			enabled, ok := p.Config["enabled"].(bool)
			if !ok {
				return nil, nil, fmt.Errorf("policy %s: internet_access requires boolean enabled", p.ID)
			}
			if !enabled {
				firewall[comment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: map[string]string{"chain": "forward", "action": "drop", "src-address": hostCIDR(d.IPAddress), "src-mac-address": strings.ToUpper(*d.MACAddress), "comment": comment}}
			}
		case "bandwidth_limit", "upload_limit", "download_limit":
			upload, uok := positiveInt64(p.Config["upload_limit_bps"])
			download, dok := positiveInt64(p.Config["download_limit_bps"])
			if p.PolicyType == "upload_limit" && !uok || p.PolicyType == "download_limit" && !dok || p.PolicyType == "bandwidth_limit" && !uok && !dok {
				return nil, nil, fmt.Errorf("policy %s: %s requires a positive applicable limit", p.ID, p.PolicyType)
			}
			queues[comment] = desiredRouterEntry{path: "/queue/simple", attrs: map[string]string{"name": comment, "target": hostCIDR(d.IPAddress), "max-limit": fmt.Sprintf("%d/%d", upload, download), "comment": comment}}
		case "website_blacklist":
			platforms, ok := p.Config["platforms"].([]interface{})
			if !ok {
				return nil, nil, fmt.Errorf("policy %s: website_blacklist requires platforms array", p.ID)
			}
			for _, raw := range platforms {
				name, ok2 := raw.(string)
				if !ok2 || name == "" {
					continue
				}
				name = strings.ToLower(name)
				_, found := platformDomains[name]
				if !found {
					continue
				}
				ruleComment := comment + "-block-" + name

				dnsDropComment := ruleComment + "-dns"
				firewall[dnsDropComment] = desiredRouterEntry{
					path:  "/ip/firewall/filter",
					attrs: map[string]string{"chain": "forward", "action": "drop", "src-mac-address": strings.ToUpper(*d.MACAddress), "dst-address-list": managedPlatformAddressList + "-" + name, "comment": dnsDropComment},
				}

				layer7Comment := ruleComment + "-l7"
				firewall[layer7Comment] = desiredRouterEntry{
					path:  "/ip/firewall/filter",
					attrs: map[string]string{"chain": "forward", "action": "drop", "src-mac-address": strings.ToUpper(*d.MACAddress), "layer7-protocol": "nms-" + name, "comment": layer7Comment},
				}
			}
		case "website_whitelist":
			return nil, nil, fmt.Errorf("%w: %s policy requires allowlist-first mode on RouterOS", ErrPolicyUnsupported, p.PolicyType)
		case "schedule":
			enabled, ok := p.Config["enabled"].(bool)
			if !ok {
				enabled = true
			}
			scheduleType, _ := p.Config["type"].(string)
			startTime, _ := p.Config["start_time"].(string)
			endTime, _ := p.Config["end_time"].(string)
			days, _ := p.Config["days"].(string)
			var action string
			switch scheduleType {
			case "internet_off":
				action = "drop"
			default:
				action = "accept"
			}
			if !enabled {
				continue
			}
			scheduleComment := comment + "-schedule"
			ruleAttrs := map[string]string{"chain": "forward", "action": action, "comment": scheduleComment}
			if startTime != "" && endTime != "" {
				ruleAttrs["time"] = startTime + "-" + endTime
			}
			if days != "" {
				ruleAttrs["days"] = days
			}
			firewall[scheduleComment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: ruleAttrs}
		default:
			return nil, nil, fmt.Errorf("%w: unknown policy type %q", ErrPolicyUnsupported, p.PolicyType)
		}
	}
	return firewall, queues, nil
}

func reconcileEntries(conn routerCommander, basePath string, desired map[string]desiredRouterEntry) error {
	existing, err := conn.Command(basePath+"/print", "?comment="+managedPolicyPrefix)
	if err != nil {
		return err
	}
	seen := make(map[string]bool)
	for _, current := range existing {
		comment := current["comment"]
		if !strings.HasPrefix(comment, managedPolicyPrefix) {
			continue
		}
		want, ok := desired[comment]
		if !ok {
			if _, err := conn.Command(basePath+"/remove", "=.id="+current[".id"]); err != nil {
				return err
			}
			continue
		}
		seen[comment] = true
		changed := false
		for key, value := range want.attrs {
			if current[key] != value {
				changed = true
				break
			}
		}
		if changed {
			attrs := attributeWords(want.attrs)
			attrs = append([]string{"=.id=" + current[".id"]}, attrs...)
			if _, err := conn.Command(basePath+"/set", attrs...); err != nil {
				return err
			}
		}
	}
	for comment, want := range desired {
		if seen[comment] {
			continue
		}
		if _, err := conn.Command(want.path+"/add", attributeWords(want.attrs)...); err != nil {
			return err
		}
	}
	return nil
}

func attributeWords(attrs map[string]string) []string {
	words := make([]string, 0, len(attrs))
	for key, value := range attrs {
		words = append(words, "="+key+"="+value)
	}
	return words
}

func positiveInt64(value interface{}) (int64, bool) {
	var n int64
	switch value := value.(type) {
	case float64:
		n = int64(value)
	case int:
		n = int64(value)
	case int64:
		n = value
	case string:
		n, _ = strconv.ParseInt(value, 10, 64)
	}
	return n, n > 0
}

func hostCIDR(ip net.IP) string {
	if ip.To4() != nil {
		return ip.String() + "/32"
	}
	return ip.String() + "/128"
}

func (s *PolicySyncService) reconcilePlatformAddressLists(ctx context.Context, conn routerCommander, targets []models.AssignedPolicyDevice) error {
	activePlatforms := getActivePlatforms(targets)
	managedPrefix := managedPlatformAddressList + "-"

	existing, err := conn.Command("/ip/firewall/address-list/print")
	if err != nil {
		return err
	}
	seen := make(map[string]map[string]bool)
	for _, entry := range existing {
		listName := entry["list"]
		if !strings.HasPrefix(listName, managedPrefix) {
			continue
		}
		platform := strings.TrimPrefix(listName, managedPrefix)
		if !activePlatforms[platform] {
			if _, err := conn.Command("/ip/firewall/address-list/remove", "=.id="+entry[".id"]); err != nil {
				return err
			}
			continue
		}
		if seen[platform] == nil {
			seen[platform] = make(map[string]bool)
		}
		seen[platform][entry["address"]] = true
	}

	for name := range activePlatforms {
		ranges, ok := platformIPRanges[name]
		if !ok {
			continue
		}
		listName := fmt.Sprintf("%s-%s", managedPlatformAddressList, name)
		for _, ipRange := range ranges {
			if seen[name] != nil && seen[name][ipRange] {
				continue
			}
			content := fmt.Sprintf("nms-%s-%s", name, strings.ReplaceAll(ipRange, "/", "-"))
			if _, err := conn.Command("/ip/firewall/address-list/add",
				"=list="+listName,
				"=address="+ipRange,
				"=comment="+content,
			); err != nil {
				_ = s.fail(ctx, &models.SyncLog{ID: uuid.New(), OrganizationID: uuid.Nil, Status: "failed",
					Details: map[string]interface{}{"error": err.Error(), "platform": name, "range": ipRange}},
					fmt.Errorf("add address-list range: %w", err))
			}
		}
	}
	return nil
}

func (s *PolicySyncService) reconcilePlatformLayer7(ctx context.Context, conn routerCommander, targets []models.AssignedPolicyDevice) error {
	activePlatforms := getActivePlatforms(targets)

	existing, err := conn.Command("/ip/firewall/layer7-protocol/print")
	if err != nil {
		return err
	}
	seen := make(map[string]bool)
	for _, entry := range existing {
		name := entry["name"]
		if !strings.HasPrefix(name, "nms-") {
			continue
		}
		platform := strings.TrimPrefix(name, "nms-")
		if !activePlatforms[platform] {
			if _, err := conn.Command("/ip/firewall/layer7-protocol/remove", "=.id="+entry[".id"]); err != nil {
				return err
			}
			continue
		}
		seen[platform] = true
	}

	for name := range activePlatforms {
		if seen[name] {
			continue
		}
		domains, ok := platformDomains[name]
		if !ok || len(domains) == 0 {
			continue
		}
		sort.Strings(domains)
		escapedParts := make([]string, len(domains))
		for i, d := range domains {
			pattern := strings.ReplaceAll(d, ".", "\\.")
			pattern = strings.ReplaceAll(pattern, "-", "\\-")
			escapedParts[i] = pattern
		}
		regexp := ".*(" + strings.Join(escapedParts, "|") + ").*"

		layer7Name := "nms-" + name
		if _, err := conn.Command("/ip/firewall/layer7-protocol/add",
			"=name="+layer7Name,
			"=regexp="+regexp,
		); err != nil {
			_ = s.fail(ctx, &models.SyncLog{ID: uuid.New(), OrganizationID: uuid.Nil, Status: "failed",
				Details: map[string]interface{}{"error": err.Error(), "platform": name}},
				fmt.Errorf("add layer7 protocol: %w", err))
		}
	}
	return nil
}

func (s *PolicySyncService) reconcilePlatformDNS(ctx context.Context, conn routerCommander, targets []models.AssignedPolicyDevice) error {
	activePlatforms := getActivePlatforms(targets)

	existing, err := conn.Command("/ip/dns/static/print")
	if err != nil {
		return err
	}
	seen := make(map[string]bool)
	for _, entry := range existing {
		comment := entry["comment"]
		if !strings.HasPrefix(comment, managedPlatformDNS) {
			continue
		}
		domain := strings.TrimPrefix(comment, managedPlatformDNS+"-")
		stillBlocked := false
		for platform, domains := range platformDomains {
			if !activePlatforms[platform] {
				continue
			}
			for _, d := range domains {
				if d == domain {
					stillBlocked = true
					break
				}
			}
			if stillBlocked {
				break
			}
		}
		if !stillBlocked {
			if _, err := conn.Command("/ip/dns/static/remove", "=.id="+entry[".id"]); err != nil {
				return err
			}
			continue
		}
		seen[domain] = true
	}

	for name := range activePlatforms {
		domains, ok := platformDomains[name]
		if !ok {
			continue
		}
		for _, domain := range domains {
			if seen[domain] {
				continue
			}
			comment := fmt.Sprintf("%s-%s", managedPlatformDNS, domain)
			if _, err := conn.Command("/ip/dns/static/add",
				"=name="+domain,
				"=address=127.0.0.1",
				"=comment="+comment,
				"=ttl=1d",
			); err != nil {
				_ = s.fail(ctx, &models.SyncLog{ID: uuid.New(), OrganizationID: uuid.Nil, Status: "failed",
					Details: map[string]interface{}{"error": err.Error(), "platform": name, "domain": domain}},
					fmt.Errorf("add dns block: %w", err))
			}
		}
	}
	return nil
}

func getActivePlatforms(targets []models.AssignedPolicyDevice) map[string]bool {
	activePlatforms := make(map[string]bool)
	for _, target := range targets {
		if target.Policy.PolicyType != "website_blacklist" {
			continue
		}
		enabledVal, ok := target.Policy.Config["enabled"]
		if ok {
			if enabled, isBool := enabledVal.(bool); isBool && !enabled {
				continue
			}
		}
		platforms, ok := target.Policy.Config["platforms"].([]interface{})
		if !ok {
			continue
		}
		for _, raw := range platforms {
			name, ok2 := raw.(string)
			if !ok2 || name == "" {
				continue
			}
			activePlatforms[strings.ToLower(name)] = true
		}
	}
	return activePlatforms
}
