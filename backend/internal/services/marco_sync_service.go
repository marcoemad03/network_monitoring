package services

import (
	"context"
	"fmt"
	"net"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/websocket"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

const marcoManagedPrefix = "nms-marco-"
const marcoSrcListPrefix = "nms-marco-src-"
const marcoPlatListPrefix = "nms-marco-plat-"
const marcoLayer7Prefix = "nms-marco-l7-"
const marcoQueuePrefix = "nms-marco-q-"
const marcoQuotaPrefix = "nms-marco-quota-"

const marcoSyncTimeout = 90 * time.Second

// MarcoSyncService reconciles the desired state of all Marco groups onto the
// MikroTik router. It only touches entries whose comment starts with
// "nms-marco-", never writes unless ROUTER_POLICY_WRITES is enabled, refuses
// unscoped drop rules, and undoes its own changes if applying or verifying fails.
type MarcoSyncService struct {
	marcoRepo    *repository.MarcoRepository
	deviceRepo   *repository.DeviceRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	hub          *websocket.Hub
	telegramSvc  *TelegramService
	dialRouter   func(*models.VendorIntegration, *config.Config) (routerCommander, error)
}

func NewMarcoSyncService(marcoRepo *repository.MarcoRepository, deviceRepo *repository.DeviceRepository, internetRepo *repository.InternetRepository, cfg *config.Config, hub *websocket.Hub, telegramSvc *TelegramService) *MarcoSyncService {
	s := &MarcoSyncService{
		marcoRepo: marcoRepo, deviceRepo: deviceRepo, internetRepo: internetRepo,
		cfg: cfg, hub: hub, telegramSvc: telegramSvc,
	}
	s.dialRouter = dialRouterConnection
	return s
}

func dialRouterConnection(vendor *models.VendorIntegration, cfg *config.Config) (routerCommander, error) {
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	client, err := mikrotik.NewClientFromEndpoint(vendor.BaseURL, username, password, cfg.MikroTikAPITimeout)
	if err != nil {
		return nil, err
	}
	conn := mikrotik.NewAPIConnection(client.Host(), client.Port(), client.Username(), client.Password(), cfg.MikroTikAPITimeout)
	if err := conn.Connect(); err != nil {
		return nil, err
	}
	if err := conn.Login(); err != nil {
		conn.Close()
		return nil, err
	}
	return conn, nil
}

type marcoDesiredState struct {
	firewall  map[string]desiredRouterEntry
	queues    map[string]desiredRouterEntry
	addrLists map[string]desiredRouterEntry
	layer7    map[string]desiredRouterEntry
	warnings  []string
}

type marcoBuildOptions struct {
	layer7    bool
	protected []*net.IPNet
}

type marcoSyncResult struct {
	groups   []models.MarcoGroup
	members  map[uuid.UUID][]models.MarcoGroupMember
	firewall map[string]desiredRouterEntry
	queues   map[string]desiredRouterEntry

	// DryRun is true when router writes are disabled: the plan was computed but
	// nothing was changed on the router.
	DryRun   bool
	Planned  []string
	Warnings []string
}

// SyncAll applies the desired Marco state. In dry-run mode (default) the router
// is only read.
func (s *MarcoSyncService) SyncAll(ctx context.Context, orgID uuid.UUID) (*marcoSyncResult, error) {
	ctx, cancel := context.WithTimeout(ctx, marcoSyncTimeout)
	defer cancel()

	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("active MikroTik integration is not configured: %w", err)
	}

	groups, err := s.marcoRepo.ListGroups(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("load Marco groups: %w", err)
	}
	members, err := s.marcoRepo.ListAllMembers(ctx, orgID)
	if err != nil {
		return nil, fmt.Errorf("load Marco members: %w", err)
	}

	membersByGroup := make(map[uuid.UUID][]models.MarcoGroupMember, len(groups))
	for _, m := range members {
		membersByGroup[m.GroupID] = append(membersByGroup[m.GroupID], m)
	}

	desired := buildMarcoDesiredState(groups, membersByGroup, marcoBuildOptions{
		layer7:    s.cfg.RouterEnableLayer7,
		protected: protectedNetworks(vendor, s.cfg),
	})
	if err := validateFirewallScope(desired.firewall); err != nil {
		return nil, err
	}
	if err := validateEntryCount(s.cfg, len(desired.firewall), len(desired.queues), len(desired.addrLists), len(desired.layer7)); err != nil {
		return nil, err
	}

	sess, err := openRouterSession(ctx, vendor, s.cfg, s.dialRouter, true)
	if err != nil {
		return nil, fmt.Errorf("connect MikroTik: %w", err)
	}
	defer sess.Close()

	journal := &changeJournal{}
	fail := func(step string, err error) error {
		if !sess.write {
			return fmt.Errorf("%s: %w", step, err)
		}
		if rbErr := journal.rollback(sess.inner); rbErr != nil {
			return fmt.Errorf("%s: %w (rollback also failed: %v)", step, err, rbErr)
		}
		return fmt.Errorf("%s: %w (changes rolled back)", step, err)
	}

	if err := applyMarcoDesiredState(sess, desired, journal); err != nil {
		return nil, fail("apply RouterOS configuration", err)
	}
	if sess.write {
		if err := verifyMarcoDesiredState(sess, desired); err != nil {
			return nil, fail("verify RouterOS configuration", err)
		}
	}

	res := &marcoSyncResult{
		groups: groups, members: membersByGroup, firewall: desired.firewall, queues: desired.queues,
		DryRun: sess.DryRun(), Planned: sess.Planned(), Warnings: desired.warnings,
	}
	s.logOutcome(orgID, res)
	if !res.DryRun {
		s.notifyCompletion(ctx, orgID, res)
	}
	return res, nil
}

// logOutcome records the result of a sync in the policy log. A dry-run is
// logged with status "dry_run" together with the number of router changes it
// would have made, so the plan can be reviewed before enabling writes.
func (s *MarcoSyncService) logOutcome(orgID uuid.UUID, res *marcoSyncResult) {
	action, status := "sync_completed", "applied"
	message := fmt.Sprintf("Synced %d firewall rules and %d bandwidth queues to MikroTik", len(res.firewall), len(res.queues))
	if res.DryRun {
		action, status = "sync_dry_run", "dry_run"
		message = fmt.Sprintf("Dry-run: %d router changes planned (%d firewall rules, %d queues desired). Router writes are disabled.", len(res.Planned), len(res.firewall), len(res.queues))
	}
	if len(res.Warnings) > 0 {
		message += " Warnings: " + strings.Join(res.Warnings, "; ")
	}
	_ = s.marcoRepo.CreatePolicyLog(context.Background(), &models.MarcoPolicyLog{
		ID: uuid.New(), OrganizationID: orgID, Action: action, Message: message, Status: status,
	})
}

func (s *MarcoSyncService) notifyCompletion(ctx context.Context, orgID uuid.UUID, res *marcoSyncResult) {
	if s.hub != nil {
		s.hub.BroadcastMessage("notification", models.LiveNotification{
			Title:   "Marco policies synced",
			Message: fmt.Sprintf("Synced %d firewall rules and %d bandwidth queues to MikroTik", len(res.firewall), len(res.queues)),
			Type:    "policy_sync",
		})
	}
	if s.telegramSvc != nil {
		go func() {
			_ = s.telegramSvc.Notify(context.Background(), orgID, models.TelegramEventPolicyViolation, "", "Marco policy sync", fmt.Sprintf("%d firewall rules, %d queues", len(res.firewall), len(res.queues)), "")
		}()
	}
}

// ---------------------------------------------------------------------------
// Desired state construction

func (d *marcoDesiredState) addFirewall(comment string, attrs map[string]string, top bool) {
	attrs["comment"] = comment
	attrs["disabled"] = "no"
	d.firewall[comment] = desiredRouterEntry{path: "/ip/firewall/filter", attrs: attrs, top: top}
}

func (d *marcoDesiredState) addAddress(comment, list, address string) {
	d.addrLists[comment] = desiredRouterEntry{path: "/ip/firewall/address-list", attrs: map[string]string{
		"list": list, "address": address, "comment": comment, "disabled": "no",
	}}
}

// scheduleClock converts "8:00" / "08:00" / "08:00:00" to HH:MM:SS.
func scheduleClock(v string) string {
	pad := func(s string) string {
		if len(s) == 1 {
			return "0" + s
		}
		return s
	}
	v = strings.TrimSpace(v)
	switch strings.Count(v, ":") {
	case 0:
		return pad(v) + ":00:00"
	case 1:
		parts := strings.SplitN(v, ":", 2)
		return pad(parts[0]) + ":" + pad(parts[1]) + ":00"
	}
	return v
}

func buildMarcoDesiredState(groups []models.MarcoGroup, membersByGroup map[uuid.UUID][]models.MarcoGroupMember, opts marcoBuildOptions) marcoDesiredState {
	d := marcoDesiredState{
		firewall:  make(map[string]desiredRouterEntry),
		queues:    make(map[string]desiredRouterEntry),
		addrLists: make(map[string]desiredRouterEntry),
		layer7:    make(map[string]desiredRouterEntry),
	}

	blockedPlatforms := make(map[string]bool)

	// usableMembers drops devices without a real IP or inside protected networks.
	usableMembers := func(g *models.MarcoGroup) []models.MarcoGroupMember {
		var out []models.MarcoGroupMember
		for _, m := range membersByGroup[g.ID] {
			label := m.DeviceName
			if label == "" {
				label = orEmpty(m.MACAddress)
			}
			if m.IPAddress == nil || m.IPAddress.IsUnspecified() {
				d.warnings = append(d.warnings, fmt.Sprintf("%s (%s): no IP address yet, policy not enforced until the device is discovered", label, g.Name))
				continue
			}
			if isProtectedIP(m.IPAddress, opts.protected) {
				d.warnings = append(d.warnings, fmt.Sprintf("%s (%s): protected address %s, no rules created", label, g.Name, m.IPAddress))
				continue
			}
			out = append(out, m)
		}
		return out
	}

	for i := range groups {
		g := &groups[i]
		if isZeroPolicy(g.Policy) {
			continue
		}
		if len(membersByGroup[g.ID]) == 0 {
			continue
		}
		g8 := marcoShortID(g.ID)
		srcList := marcoSrcListPrefix + g8
		members := usableMembers(g)

		internetEnabled := true
		if g.Policy.InternetEnabled != nil {
			internetEnabled = *g.Policy.InternetEnabled
		}
		unlimited := true
		if g.Policy.UnlimitedSpeed != nil {
			unlimited = *g.Policy.UnlimitedSpeed
		}
		hasSchedule := g.Policy.ScheduleStartTime != nil && g.Policy.ScheduleEndTime != nil && *g.Policy.ScheduleStartTime != "" && *g.Policy.ScheduleEndTime != ""
		platforms := normalizedPlatforms(g.Policy.BlockedWebsites)

		// A source rule is only created when the group has at least one usable
		// member, so every drop rule references a non-empty address list.
		needsSrcList := (!internetEnabled || hasSchedule || len(platforms) > 0) && len(members) > 0
		if needsSrcList {
			for _, m := range members {
				comment := fmt.Sprintf("%s%s-%s", marcoSrcListPrefix, g8, marcoShortID(m.DeviceID))
				d.addAddress(comment, srcList, hostCIDR(m.IPAddress))
			}
		}

		if needsSrcList && !internetEnabled {
			comment := fmt.Sprintf("%s%s-net-off", marcoManagedPrefix, g8)
			d.addFirewall(comment, map[string]string{"chain": "forward", "action": "drop", "src-address-list": srcList}, true)
		}

		if needsSrcList && hasSchedule {
			comment := fmt.Sprintf("%s%s-schedule", marcoManagedPrefix, g8)
			attrs := map[string]string{"chain": "forward", "action": "drop", "src-address-list": srcList}
			attrs["time"] = scheduleClock(*g.Policy.ScheduleStartTime) + "-" + scheduleClock(*g.Policy.ScheduleEndTime)
			if len(g.Policy.ScheduleDays) > 0 {
				attrs["days"] = strings.Join(g.Policy.ScheduleDays, ",")
			}
			d.addFirewall(comment, attrs, true)
		}

		if needsSrcList {
			for _, key := range platforms {
				def := marcoPlatformByKey[key]
				enforced := false
				if len(def.IPRanges) > 0 {
					blockedPlatforms[key] = true
					enforced = true
					comment := fmt.Sprintf("%s%s-plat-%s", marcoManagedPrefix, g8, key)
					d.addFirewall(comment, map[string]string{
						"chain": "forward", "action": "drop", "src-address-list": srcList,
						"dst-address-list": marcoPlatListPrefix + key,
					}, true)
				}
				if opts.layer7 && len(def.Domains) > 0 {
					blockedPlatforms[key] = true
					enforced = true
					l7Comment := fmt.Sprintf("%s%s-l7-%s", marcoManagedPrefix, g8, key)
					d.addFirewall(l7Comment, map[string]string{
						"chain": "forward", "action": "drop", "src-address-list": srcList,
						"layer7-protocol": marcoLayer7Prefix + key,
					}, true)
				}
				if !enforced {
					d.warnings = append(d.warnings, fmt.Sprintf("%s: %q cannot be enforced (no IP ranges and layer7 matching is disabled)", g.Name, def.Label))
				}
			}
		}

		// Bandwidth queues (per device). Skipped when internet is fully disabled.
		if internetEnabled && !unlimited {
			dl, hasDL := mbpsToBps(g.Policy.DownloadLimitMbps)
			ul, hasUL := mbpsToBps(g.Policy.UploadLimitMbps)
			if hasDL || hasUL {
				for _, m := range members {
					d8 := marcoShortID(m.DeviceID)
					name := marcoQueuePrefix + d8
					attrs := map[string]string{"name": name, "target": hostCIDR(m.IPAddress), "comment": name, "disabled": "no"}
					// RouterOS simple queue limits are "upload/download" from the client's view.
					attrs["max-limit"] = queueRatePair(ul, hasUL, dl, hasDL)
					burstDL, bHasDL := mbpsToBps(g.Policy.BurstDownloadMbps)
					burstUL, bHasUL := mbpsToBps(g.Policy.BurstUploadMbps)
					threshDL, tHasDL := mbpsToBps(g.Policy.BurstThresholdDownloadMbps)
					threshUL, tHasUL := mbpsToBps(g.Policy.BurstThresholdUploadMbps)
					if !bHasDL && hasDL {
						burstDL, bHasDL = dl*2, true
					}
					if !bHasUL && hasUL {
						burstUL, bHasUL = ul*2, true
					}
					if bHasDL || bHasUL {
						attrs["burst-limit"] = queueRatePair(burstUL, bHasUL, burstDL, bHasDL)
						if !tHasDL && hasDL {
							threshDL, tHasDL = dl, true
						}
						if !tHasUL && hasUL {
							threshUL, tHasUL = ul, true
						}
						attrs["burst-threshold"] = queueRatePair(threshUL, tHasUL, threshDL, tHasDL)
						burstTime := 16
						if g.Policy.BurstTimeSeconds != nil && *g.Policy.BurstTimeSeconds > 0 {
							burstTime = *g.Policy.BurstTimeSeconds
						}
						attrs["burst-time"] = fmt.Sprintf("%d/%d", burstTime, burstTime)
					}
					if g.Policy.QosPriority != nil && *g.Policy.QosPriority >= 1 && *g.Policy.QosPriority <= 8 {
						attrs["priority"] = fmt.Sprintf("%d", *g.Policy.QosPriority)
					}
					d.queues[name] = desiredRouterEntry{path: "/queue/simple", attrs: attrs}
				}
			}
		}
	}

	// Global platform definitions (address-list ranges + layer7 regexps).
	keys := make([]string, 0, len(blockedPlatforms))
	for key := range blockedPlatforms {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	for _, key := range keys {
		def := marcoPlatformByKey[key]
		for _, r := range def.IPRanges {
			comment := fmt.Sprintf("%s%s-%s", marcoPlatListPrefix, key, strings.ReplaceAll(r, "/", "-"))
			d.addAddress(comment, marcoPlatListPrefix+key, r)
		}
		if opts.layer7 && len(def.Domains) > 0 {
			name := marcoLayer7Prefix + key
			d.layer7[name] = desiredRouterEntry{path: "/ip/firewall/layer7-protocol", attrs: map[string]string{
				"name": name, "regexp": buildLayer7Regexp(def.Domains), "comment": name,
			}}
		}
	}

	return d
}

// isZeroPolicy reports whether a group has no policy configuration at all.
func isZeroPolicy(p models.MarcoGroupPolicy) bool {
	return p.InternetEnabled == nil && p.UnlimitedSpeed == nil &&
		p.DownloadLimitMbps == nil && p.UploadLimitMbps == nil &&
		p.BurstDownloadMbps == nil && p.BurstUploadMbps == nil &&
		p.BurstThresholdDownloadMbps == nil && p.BurstThresholdUploadMbps == nil &&
		p.BurstTimeSeconds == nil && p.QosPriority == nil &&
		p.DailyQuotaGb == nil && p.MonthlyQuotaGb == nil &&
		p.ScheduleStartTime == nil && p.ScheduleEndTime == nil &&
		len(p.ScheduleDays) == 0 && len(p.BlockedWebsites) == 0
}

func buildLayer7Regexp(domains []string) string {
	sorted := append([]string(nil), domains...)
	sort.Strings(sorted)
	escaped := make([]string, len(sorted))
	for i, d := range sorted {
		pattern := strings.ReplaceAll(d, ".", "\\.")
		pattern = strings.ReplaceAll(pattern, "-", "\\-")
		escaped[i] = pattern
	}
	return ".*(" + strings.Join(escaped, "|") + ").*"
}

func normalizedPlatforms(raw []string) []string {
	seen := make(map[string]bool)
	var out []string
	for _, r := range raw {
		key := strings.ToLower(strings.TrimSpace(r))
		if key == "" {
			continue
		}
		if _, ok := marcoPlatformByKey[key]; !ok {
			continue
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		out = append(out, key)
	}
	sort.Strings(out)
	return out
}

func marcoShortID(id uuid.UUID) string {
	s := strings.ReplaceAll(id.String(), "-", "")
	if len(s) > 8 {
		s = s[:8]
	}
	return s
}

func mbpsToBps(v *float64) (int64, bool) {
	if v == nil || *v <= 0 {
		return 0, false
	}
	return int64(*v * 1_000_000), true
}

// queueRatePair formats "first/second" as RouterOS bps. A missing side becomes 0
// which RouterOS interprets as unlimited.
func queueRatePair(first int64, hasFirst bool, second int64, hasSecond bool) string {
	if !hasFirst {
		first = 0
	}
	if !hasSecond {
		second = 0
	}
	return fmt.Sprintf("%d/%d", first, second)
}

// ---------------------------------------------------------------------------
// Reconciliation (diff based, prefix aware)

type marcoTable struct {
	path    string
	desired map[string]desiredRouterEntry
	top     bool
}

func marcoTables(d marcoDesiredState) map[string]marcoTable {
	return map[string]marcoTable{
		"/ip/firewall/filter":          {path: "/ip/firewall/filter", desired: d.firewall, top: true},
		"/queue/simple":                {path: "/queue/simple", desired: d.queues},
		"/ip/firewall/address-list":    {path: "/ip/firewall/address-list", desired: d.addrLists},
		"/ip/firewall/layer7-protocol": {path: "/ip/firewall/layer7-protocol", desired: d.layer7},
	}
}

// Stale entries are removed users-first (rules before the lists/protocols they
// reference); new entries are added dependencies-first.
var (
	marcoRemoveOrder = []string{"/ip/firewall/filter", "/queue/simple", "/ip/firewall/address-list", "/ip/firewall/layer7-protocol"}
	marcoApplyOrder  = []string{"/ip/firewall/layer7-protocol", "/ip/firewall/address-list", "/ip/firewall/filter", "/queue/simple"}
)

func sortedKeys(m map[string]desiredRouterEntry) []string {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	return keys
}

func applyMarcoDesiredState(conn routerCommander, d marcoDesiredState, journal *changeJournal) error {
	tables := marcoTables(d)
	existing := make(map[string]map[string]map[string]string)
	dups := make(map[string][]map[string]string)
	for path := range tables {
		byComment, dup, err := listManaged(conn, path, marcoManagedPrefix, isMarcoExcluded)
		if err != nil {
			return err
		}
		existing[path] = byComment
		dups[path] = dup
	}

	for _, path := range marcoRemoveOrder {
		t := tables[path]
		for _, e := range dups[path] {
			if _, err := conn.Command(path+"/remove", "=.id="+e[".id"]); err != nil {
				return err
			}
		}
		stale := make([]string, 0)
		for comment := range existing[path] {
			if _, ok := t.desired[comment]; !ok {
				stale = append(stale, comment)
			}
		}
		sort.Strings(stale)
		for _, comment := range stale {
			e := existing[path][comment]
			if _, err := conn.Command(path+"/remove", "=.id="+e[".id"]); err != nil {
				return err
			}
			journal.removed = append(journal.removed, journalRemoved{path: path, attrs: whitelistAttrs(path, e), top: t.top})
			delete(existing[path], comment)
		}
	}

	for _, path := range marcoApplyOrder {
		t := tables[path]
		for _, comment := range sortedKeys(t.desired) {
			want := t.desired[comment]
			current, ok := existing[path][comment]
			if !ok {
				if err := addRouterEntry(conn, path, want.attrs, want.top); err != nil {
					return fmt.Errorf("add %s %q: %w", path, comment, err)
				}
				journal.added = append(journal.added, journalAdded{path: path, comment: comment})
				continue
			}
			if entryMatches(current, want.attrs) {
				continue
			}
			old := make(map[string]string)
			for key := range want.attrs {
				if v, present := current[key]; present {
					old[key] = v
				}
			}
			args := append([]string{"=.id=" + current[".id"]}, attributeWords(want.attrs)...)
			if _, err := conn.Command(path+"/set", args...); err != nil {
				return fmt.Errorf("update %s %q: %w", path, comment, err)
			}
			journal.modified = append(journal.modified, journalModified{path: path, id: current[".id"], old: old})
		}
	}
	return nil
}

// ---------------------------------------------------------------------------
// Verification

func verifyMarcoDesiredState(conn routerCommander, d marcoDesiredState) error {
	for _, path := range marcoApplyOrder {
		t := marcoTables(d)[path]
		byComment, dups, err := listManaged(conn, path, marcoManagedPrefix, isMarcoExcluded)
		if err != nil {
			return err
		}
		if len(dups) > 0 {
			return fmt.Errorf("verification mismatch on %s: %d duplicate managed entries", path, len(dups))
		}
		if len(byComment) != len(t.desired) {
			return fmt.Errorf("verification mismatch on %s: found %d managed entries, expected %d", path, len(byComment), len(t.desired))
		}
		for comment, want := range t.desired {
			got, ok := byComment[comment]
			if !ok {
				return fmt.Errorf("verification mismatch on %s: missing entry %q", path, comment)
			}
			for key, value := range want.attrs {
				if !attrMatches(key, got[key], value) {
					return fmt.Errorf("verification mismatch on %s: entry %q attribute %q = %q, expected %q", path, comment, key, got[key], value)
				}
			}
		}
	}
	return nil
}

// isMarcoExcluded reports whether a managed comment belongs to the quota
// enforcement rules, which are reconciled separately.
func isMarcoExcluded(comment string) bool {
	return strings.HasPrefix(comment, marcoQuotaPrefix)
}

var (
	managedFirewallAttrs = []string{"chain", "action", "src-address-list", "dst-address-list", "layer7-protocol", "src-mac-address", "src-address", "time", "days", "comment", "disabled"}
	managedQueueAttrs    = []string{"name", "target", "max-limit", "burst-limit", "burst-threshold", "burst-time", "priority", "comment", "disabled"}
	managedAddrListAttrs = []string{"list", "address", "comment"}
	managedLayer7Attrs   = []string{"name", "regexp", "comment"}
)

func whitelistAttrs(path string, e map[string]string) map[string]string {
	var allowed []string
	switch path {
	case "/ip/firewall/filter":
		allowed = managedFirewallAttrs
	case "/queue/simple":
		allowed = managedQueueAttrs
	case "/ip/firewall/address-list":
		allowed = managedAddrListAttrs
	case "/ip/firewall/layer7-protocol":
		allowed = managedLayer7Attrs
	}
	out := make(map[string]string)
	for _, key := range allowed {
		if v, ok := e[key]; ok && v != "" {
			out[key] = v
		}
	}
	return out
}
