package services

import (
	"context"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

// MarcoQuotaService enforces daily/monthly data quotas. RouterOS 6.x simple
// queues have no native quota, so this service periodically reads the byte
// counters of each managed queue, accumulates consumption in the database and
// drops a firewall rule once the quota is exhausted (and removes it again when
// the period rolls over). It shares the router session gate with the policy
// sync and never waits for it: if a sync is running, the tick is skipped.
type MarcoQuotaService struct {
	marcoRepo    *repository.MarcoRepository
	internetRepo *repository.InternetRepository
	cfg          *config.Config
	mu           sync.Mutex
	baselines    map[string]quotaBaseline
	blockedLog   map[string]bool
	dialRouter   func(*models.VendorIntegration, *config.Config) (routerCommander, error)
}

type quotaBaseline struct {
	periodKey string
	lastBytes int64
}

func NewMarcoQuotaService(marcoRepo *repository.MarcoRepository, internetRepo *repository.InternetRepository, cfg *config.Config) *MarcoQuotaService {
	return &MarcoQuotaService{
		marcoRepo: marcoRepo, internetRepo: internetRepo, cfg: cfg,
		baselines:  make(map[string]quotaBaseline),
		blockedLog: make(map[string]bool),
		dialRouter: dialRouterConnection,
	}
}

func (s *MarcoQuotaService) Start(ctx context.Context, interval time.Duration) {
	if interval <= 0 {
		interval = 60 * time.Second
	}
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		s.runOnce(ctx)
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				s.runOnce(ctx)
			}
		}
	}()
}

func (s *MarcoQuotaService) runOnce(ctx context.Context) {
	orgs, err := s.marcoRepo.ListOrganizationIDs(ctx)
	if err != nil {
		return
	}
	for _, orgID := range orgs {
		s.enforceOrg(ctx, orgID)
	}
}

func (s *MarcoQuotaService) enforceOrg(ctx context.Context, orgID uuid.UUID) {
	groups, err := s.marcoRepo.ListGroups(ctx, orgID)
	if err != nil {
		return
	}
	hasQuota := false
	for i := range groups {
		if groups[i].Policy.DailyQuotaGb != nil || groups[i].Policy.MonthlyQuotaGb != nil {
			hasQuota = true
			break
		}
	}
	if !hasQuota {
		return
	}
	vendor, err := s.internetRepo.GetActiveMikroTikIntegration(ctx, orgID)
	if err != nil {
		return
	}
	members, err := s.marcoRepo.ListAllMembers(ctx, orgID)
	if err != nil {
		return
	}
	membersByGroup := make(map[uuid.UUID][]models.MarcoGroupMember)
	for _, m := range members {
		membersByGroup[m.GroupID] = append(membersByGroup[m.GroupID], m)
	}

	ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
	defer cancel()

	// Never wait for the router: if a policy sync is running, try again next tick.
	conn, err := openRouterSession(ctx, vendor, s.cfg, s.dialRouter, false)
	if err != nil || conn == nil {
		return
	}
	defer conn.Close()

	protected := protectedNetworks(vendor, s.cfg)
	quotaRules, _, err := listManaged(conn, "/ip/firewall/filter", marcoQuotaPrefix, nil)
	if err != nil {
		return
	}

	overQuota := make(map[string]bool)

	now := time.Now()
	dayKey := now.Format("2006-01-02")
	monthKey := now.Format("2006-01")

	for i := range groups {
		g := &groups[i]
		if g.Policy.DailyQuotaGb == nil && g.Policy.MonthlyQuotaGb == nil {
			continue
		}
		for _, m := range membersByGroup[g.ID] {
			if m.MACAddress == nil || strings.TrimSpace(*m.MACAddress) == "" {
				continue
			}
			if m.IPAddress != nil && isProtectedIP(m.IPAddress, protected) {
				continue
			}
			d8 := marcoShortID(m.DeviceID)
			total := s.readQueueBytes(conn, marcoQueuePrefix+d8)
			if total < 0 {
				continue
			}
			mac := strings.ToUpper(strings.TrimSpace(*m.MACAddress))
			blocked := false

			if g.Policy.DailyQuotaGb != nil && *g.Policy.DailyQuotaGb > 0 {
				usage := s.accumulate(ctx, orgID, m.DeviceID, g.ID, "day", dayKey, total)
				if usage >= *g.Policy.DailyQuotaGb*1e9 {
					blocked = true
				}
			}
			if g.Policy.MonthlyQuotaGb != nil && *g.Policy.MonthlyQuotaGb > 0 {
				usage := s.accumulate(ctx, orgID, m.DeviceID, g.ID, "month", monthKey, total)
				if usage >= *g.Policy.MonthlyQuotaGb*1e9 {
					blocked = true
				}
			}

			ruleComment := marcoQuotaPrefix + d8
			if blocked {
				if _, exists := quotaRules[ruleComment]; !exists {
					s.ensureQuotaRule(conn, ruleComment, mac)
				}
				overQuota[ruleComment] = true
			} else if e, exists := quotaRules[ruleComment]; exists {
				_, _ = conn.Command("/ip/firewall/filter/remove", "=.id="+e[".id"])
			}
			s.logTransition(orgID, g.ID, m.DeviceID, ruleComment, mac, m.DeviceName, blocked, conn.DryRun())
		}
	}

	// Remove block rules of devices that left quota-managed groups.
	for comment, e := range quotaRules {
		if !overQuota[comment] {
			_, _ = conn.Command("/ip/firewall/filter/remove", "=.id="+e[".id"])
		}
	}
}

// logTransition logs a quota block/unblock event only once per state change.
func (s *MarcoQuotaService) logTransition(orgID, groupID, deviceID uuid.UUID, ruleComment, mac, deviceName string, blocked, dryRun bool) {
	if deviceName == "" {
		deviceName = mac
	}
	s.mu.Lock()
	wasBlocked := s.blockedLog[ruleComment]
	if wasBlocked == blocked {
		s.mu.Unlock()
		return
	}
	s.blockedLog[ruleComment] = blocked
	s.mu.Unlock()

	action := "quota_blocked"
	message := fmt.Sprintf("Quota exhausted for %s - internet blocked", deviceName)
	status := "applied"
	if !blocked {
		action = "quota_reset"
		message = fmt.Sprintf("Quota window reset for %s - internet re-enabled", deviceName)
	}
	if dryRun {
		status = "dry_run"
		message += " (dry-run: router writes are disabled)"
	}
	_ = s.marcoRepo.CreatePolicyLog(context.Background(), &models.MarcoPolicyLog{
		ID: uuid.New(), OrganizationID: orgID, GroupID: &groupID, DeviceID: &deviceID,
		Action: action, Message: message, Status: status,
	})
}

// accumulate updates the persisted byte usage for a device/period and returns
// the resulting usage in bytes.
func (s *MarcoQuotaService) accumulate(ctx context.Context, orgID uuid.UUID, deviceID, groupID uuid.UUID, periodType, periodKey string, totalBytes int64) float64 {
	s.mu.Lock()
	defer s.mu.Unlock()

	bucket := deviceID.String() + "|" + periodType
	bl, ok := s.baselines[bucket]
	delta := int64(0)
	if !ok || bl.periodKey != periodKey {
		// New period (or first observation): reset baseline to current counter.
		bl = quotaBaseline{periodKey: periodKey, lastBytes: totalBytes}
		s.baselines[bucket] = bl
		// Keep usage already stored for this period (e.g. after a restart).
		if existing, err := s.marcoRepo.GetQuotaUsage(ctx, deviceID, periodType, periodKey); err == nil {
			return float64(existing.BytesUsed)
		}
		_ = s.resetUsage(ctx, orgID, deviceID, groupID, periodType, periodKey)
		return 0
	}
	if totalBytes >= bl.lastBytes {
		delta = totalBytes - bl.lastBytes
	} else {
		delta = 0 // counter reset on the router (reboot), avoid a bogus spike
	}
	bl.lastBytes = totalBytes
	s.baselines[bucket] = bl

	existing, err := s.marcoRepo.GetQuotaUsage(ctx, deviceID, periodType, periodKey)
	if err != nil {
		existing = &models.MarcoQuotaUsage{ID: uuid.New(), OrganizationID: orgID, DeviceID: deviceID, GroupID: groupID, PeriodType: periodType, PeriodKey: periodKey}
	}
	existing.BytesUsed += delta
	existing.GroupID = groupID
	_ = s.marcoRepo.UpsertQuotaUsage(ctx, existing)

	return float64(existing.BytesUsed)
}

func (s *MarcoQuotaService) resetUsage(ctx context.Context, orgID uuid.UUID, deviceID, groupID uuid.UUID, periodType, periodKey string) error {
	return s.marcoRepo.UpsertQuotaUsage(ctx, &models.MarcoQuotaUsage{
		ID: uuid.New(), OrganizationID: orgID, DeviceID: deviceID, GroupID: groupID,
		PeriodType: periodType, PeriodKey: periodKey, BytesUsed: 0,
	})
}

func (s *MarcoQuotaService) readQueueBytes(conn routerCommander, name string) int64 {
	entries, err := conn.Command("/queue/simple/print", "?name="+name)
	if err != nil || len(entries) == 0 {
		return -1
	}
	var total int64
	for _, e := range entries {
		bi, bo := parseBytePair(e["bytes"])
		if bi == 0 && bo == 0 {
			bi, _ = strconv.ParseInt(e["bytes-in"], 10, 64)
			bo, _ = strconv.ParseInt(e["bytes-out"], 10, 64)
		}
		total += bi + bo
	}
	return total
}

// parseBytePair parses the RouterOS simple-queue "bytes" counter ("up/down").
func parseBytePair(v string) (int64, int64) {
	parts := strings.SplitN(v, "/", 2)
	if len(parts) != 2 {
		return 0, 0
	}
	a, _ := strconv.ParseInt(parts[0], 10, 64)
	b, _ := strconv.ParseInt(parts[1], 10, 64)
	return a, b
}

func (s *MarcoQuotaService) ensureQuotaRule(conn routerCommander, comment, mac string) {
	_ = addRouterEntry(conn, "/ip/firewall/filter", map[string]string{
		"chain": "forward", "action": "drop", "src-mac-address": mac, "comment": comment,
	}, true)
}
