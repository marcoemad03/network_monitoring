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
	"youtube":    {"youtube.com", "m.youtube.com", "music.youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "youtubei.googleapis.com", "youtube-nocookie.com"},
	"facebook":   {"facebook.com", "fbcdn.net", "fb.com", "messenger.com"},
	"tiktok":     {"tiktok.com", "tiktokcdn.com", "tiktokv.com", "musical.ly"},
	"instagram":  {"instagram.com", "cdninstagram.com"},
}

var platformIPRanges = map[string][]string{
	"youtube": youtubeIPRanges,
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
	// top places a new filter rule at the head of its chain.
	top bool
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

// legacyOptions switches the heavier enforcement mechanisms of the legacy
// policy engine. Both default to off (see ROUTER_ENABLE_LAYER7 / ROUTER_ENABLE_DNS_BLOCK).
type legacyOptions struct {
	layer7 bool
	dns    bool
}

func (s *PolicySyncService) options() legacyOptions {
	return legacyOptions{layer7: s.cfg.RouterEnableLayer7, dns: s.cfg.RouterEnableDNSBlock}
}

func (s *PolicySyncService) SyncPoliciesToMikroTik(ctx context.Context, orgID uuid.UUID) error {
	ctx, cancel := context.WithTimeout(ctx, marcoSyncTimeout)
	defer cancel()

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
	opts := s.options()
	firewall, queues, err := desiredEntriesWith(targets, opts)
	if err != nil {
		return s.fail(ctx, log, err)
	}
	if err := validateFirewallScope(firewall); err != nil {
		return s.fail(ctx, log, err)
	}
	if err := validateEntryCount(s.cfg, len(firewall), len(queues)); err != nil {
		return s.fail(ctx, log, err)
	}
	conn, err := openRouterSession(ctx, vendor, s.cfg, func(v *models.VendorIntegration, _ *config.Config) (routerCommander, error) {
		return s.dialRouter(v)
	}, true)
	if err != nil {
		return s.fail(ctx, log, fmt.Errorf("connect MikroTik: %w", err))
	}
	defer conn.Close()
	if conn.DryRun() {
		log.Details["dry_run"] = true
	}

	if err := reconcileEntries(conn, "/ip/firewall/filter", firewall); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile Internet access rules: %w", err))
	}
	if err := reconcileEntries(conn, "/queue/simple", queues); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile bandwidth queues: %w", err))
	}
	if err := s.reconcilePlatformAddressLists(ctx, conn, targets); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform address lists: %w", err))
	}
	if err := s.reconcilePlatformLayer7(ctx, conn, activeTargets(targets, opts.layer7)); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform layer7 protocols: %w", err))
	}
	if err := s.reconcilePlatformDNS(ctx, conn, activeTargets(targets, opts.dns)); err != nil {
		return s.fail(ctx, log, fmt.Errorf("reconcile platform DNS blocks: %w", err))
	}

	log.ID = uuid.New()
	log.Status = "completed"
	log.Details = map[string]interface{}{"targets": len(targets), "firewall_rules": len(firewall), "queues": len(queues), "completed_at": time.Now().Format(time.RFC3339), "dry_run": conn.DryRun()}
	if conn.DryRun() {
		log.Details["planned_changes"] = conn.Planned()
	}
	_ = s.assetRepo.CreateSyncLog(ctx, log)

	if len(targets) > 0 && !conn.DryRun() {
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

// activeTargets returns the targets when enabled, or none, so reconciliation
// removes previously created entries of a mechanism that was switched off.
func activeTargets(targets []models.AssignedPolicyDevice, enabled bool) []models.AssignedPolicyDevice {
	if enabled {
		return targets
	}
	return nil
}

func desiredEntries(targets []models.AssignedPolicyDevice) (map[string]desiredRouterEntry, map[string]desiredRouterEntry, error) {
	return desiredEntriesWith(targets, legacyOptions{layer7: true, dns: true})
}

func desiredEntriesWith(targets []models.AssignedPolicyDevice, opts legacyOptions) (map[string]desiredRouterEntry, map[string]desiredRouterEntry, error) {
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
				firewall[comment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: map[string]string{"chain": "forward", "action": "drop", "src-address": hostCIDR(d.IPAddress), "src-mac-address": strings.ToUpper(*d.MACAddress), "comment": comment}, top: true}
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
						top:   true,
				}

				if !opts.layer7 {
						continue
					}
					layer7Comment := ruleComment + "-l7"
				firewall[layer7Comment] = desiredRouterEntry{
					path:  "/ip/firewall/filter",
					attrs: map[string]string{"chain": "forward", "action": "drop", "src-mac-address": strings.ToUpper(*d.MACAddress), "layer7-protocol": "nms-" + name, "comment": layer7Comment},
						top:   true,
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
			// Scoped to this device. An unscoped time rule would drop (or accept)
			// the traffic of every device on the network.
			ruleAttrs := map[string]string{"chain": "forward", "action": action, "comment": scheduleComment,
				"src-address": hostCIDR(d.IPAddress), "src-mac-address": strings.ToUpper(*d.MACAddress)}
			if startTime != "" && endTime != "" {
				ruleAttrs["time"] = scheduleClock(startTime) + "-" + scheduleClock(endTime)
			}
			if days != "" {
				ruleAttrs["days"] = days
			}
			firewall[scheduleComment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: ruleAttrs, top: true}
		default:
			return nil, nil, fmt.Errorf("%w: unknown policy type %q", ErrPolicyUnsupported, p.PolicyType)
		}
	}
	return firewall, queues, nil
}

// reconcileEntries diffs the "nms-policy-" entries of one table against the
// desired set. The RouterOS API "?comment=" query is an exact match, so the
// table is printed and filtered by prefix here.
func reconcileEntries(conn routerCommander, basePath string, desired map[string]desiredRouterEntry) error {
	existing, dups, err := listManaged(conn, basePath, managedPolicyPrefix, nil)
	if err != nil {
		return err
	}
	for _, e := range dups {
		if _, err := conn.Command(basePath+"/remove", "=.id="+e[".id"]); err != nil {
			return err
		}
	}
	for comment, current := range existing {
		if _, ok := desired[comment]; ok {
			continue
		}
		if _, err := conn.Command(basePath+"/remove", "=.id="+current[".id"]); err != nil {
			return err
		}
	}
	for _, comment := range sortedKeys(desired) {
		want := desired[comment]
		current, ok := existing[comment]
		if !ok {
			if err := addRouterEntry(conn, want.path, want.attrs, want.top); err != nil {
				return fmt.Errorf("add %s %q: %w", want.path, comment, err)
			}
			continue
		}
		if entryMatches(current, want.attrs) {
			continue
		}
		args := append([]string{"=.id=" + current[".id"]}, attributeWords(want.attrs)...)
		if _, err := conn.Command(basePath+"/set", args...); err != nil {
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
		if !strings.HasPrefix(name, "nms-") || strings.HasPrefix(name, marcoManagedPrefix) {
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
