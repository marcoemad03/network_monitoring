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
)

// MarcoGroupService is the business layer for the Marco Groups feature:
// MAC based membership, group policies, instant MikroTik sync and policy logs.
type MarcoGroupService struct {
	marcoRepo   *repository.MarcoRepository
	deviceRepo  *repository.DeviceRepository
	sync        *MarcoSyncService
	cfg         *config.Config
	hub         *websocket.Hub
	telegramSvc *TelegramService
	async       asyncSyncer
	inventory   *ClientInventoryService
	clientRepo  *repository.ClientRepository
}

func NewMarcoGroupService(marcoRepo *repository.MarcoRepository, deviceRepo *repository.DeviceRepository, internetRepo *repository.InternetRepository, cfg *config.Config, hub *websocket.Hub, telegramSvc *TelegramService) *MarcoGroupService {
	s := &MarcoGroupService{
		marcoRepo: marcoRepo, deviceRepo: deviceRepo, cfg: cfg, hub: hub, telegramSvc: telegramSvc,
	}
	s.sync = NewMarcoSyncService(marcoRepo, deviceRepo, internetRepo, cfg, hub, telegramSvc)
	return s
}

// ---------------------------------------------------------------------------
// Read

func (s *MarcoGroupService) ListGroups(ctx context.Context, orgID uuid.UUID) ([]models.MarcoGroupView, error) {
	groups, err := s.marcoRepo.ListGroups(ctx, orgID)
	if err != nil {
		return nil, err
	}
	members, err := s.marcoRepo.ListAllMembers(ctx, orgID)
	if err != nil {
		return nil, err
	}
	byGroup := groupMembersByGroup(members)
	views := make([]models.MarcoGroupView, 0, len(groups))
	for _, g := range groups {
		views = append(views, buildGroupView(g, byGroup[g.ID]))
	}
	return views, nil
}

func (s *MarcoGroupService) GetGroup(ctx context.Context, orgID, id uuid.UUID) (*models.MarcoGroupView, error) {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, id)
	if err != nil {
		return nil, err
	}
	members, err := s.marcoRepo.ListMembers(ctx, id)
	if err != nil {
		return nil, err
	}
	view := buildGroupView(*g, members)
	return &view, nil
}

// ---------------------------------------------------------------------------
// Write

type CreateGroupRequest struct {
	Name        string                   `json:"name"`
	Description *string                  `json:"description,omitempty"`
	Color       string                   `json:"color,omitempty"`
	Icon        string                   `json:"icon,omitempty"`
	Policy      *models.MarcoGroupPolicy `json:"policy,omitempty"`
}

func (s *MarcoGroupService) CreateGroup(ctx context.Context, orgID uuid.UUID, req CreateGroupRequest) (*models.MarcoGroupView, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, fmt.Errorf("group name is required")
	}
	color := req.Color
	if color == "" {
		color = "blue"
	}
	icon := req.Icon
	if icon == "" {
		icon = "group"
	}
	policy := models.MarcoGroupPolicy{}
	if req.Policy != nil {
		policy = *req.Policy
		if err := ValidatePolicySites(policy); err != nil {
			return nil, err
		}
	}
	policy = NormalizeMarcoPolicy(policy)
	g := &models.MarcoGroup{
		ID: uuid.New(), OrganizationID: orgID, Name: name, Description: req.Description,
		Color: color, Icon: icon, Policy: policy,
	}
	if err := s.marcoRepo.CreateGroup(ctx, g); err != nil {
		return nil, err
	}
	s.log(ctx, orgID, &g.ID, nil, "group_created", fmt.Sprintf("Group %q created", name), "applied", "")
	view, err := s.GetGroup(ctx, orgID, g.ID)
	if err != nil {
		return nil, err
	}
	return view, nil
}

type UpdateGroupRequest struct {
	Name        *string `json:"name,omitempty"`
	Description *string `json:"description,omitempty"`
	Color       *string `json:"color,omitempty"`
	Icon        *string `json:"icon,omitempty"`
}

func (s *MarcoGroupService) UpdateGroup(ctx context.Context, orgID, id uuid.UUID, req UpdateGroupRequest) (*models.MarcoGroupView, error) {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, id)
	if err != nil {
		return nil, err
	}
	if req.Name != nil {
		g.Name = strings.TrimSpace(*req.Name)
	}
	if g.Name == "" {
		return nil, fmt.Errorf("group name is required")
	}
	if req.Description != nil {
		g.Description = req.Description
	}
	if req.Color != nil && *req.Color != "" {
		g.Color = *req.Color
	}
	if req.Icon != nil && *req.Icon != "" {
		g.Icon = *req.Icon
	}
	if err := s.marcoRepo.UpdateGroup(ctx, g); err != nil {
		return nil, err
	}
	s.log(ctx, orgID, &g.ID, nil, "group_updated", fmt.Sprintf("Group %q updated", g.Name), "applied", "")
	view, err := s.GetGroup(ctx, orgID, id)
	if err != nil {
		return nil, err
	}
	return view, nil
}

func (s *MarcoGroupService) DeleteGroup(ctx context.Context, orgID, id uuid.UUID) error {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, id)
	if err != nil {
		return err
	}
	if err := s.marcoRepo.DeleteGroup(ctx, orgID, id); err != nil {
		return err
	}
	s.log(ctx, orgID, &id, nil, "group_deleted", fmt.Sprintf("Group %q deleted, policies removed", g.Name), "applied", "")
	s.scheduleSync(orgID, &id, nil)
	return nil
}

// AddMembers resolves MAC addresses to devices (creating placeholder device
// records for unknown MACs), moves each device out of its previous Marco group
// and applies the group policy immediately.
func (s *MarcoGroupService) AddMembers(ctx context.Context, orgID, groupID uuid.UUID, macs []string) ([]models.MarcoGroupMember, error) {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, groupID)
	if err != nil {
		return nil, err
	}
	known := map[string]ClientView{}
	if s.inventory != nil {
		if l, err := s.inventory.List(ctx, orgID); err == nil {
			for _, c := range l.Clients {
				known[c.MAC] = c
			}
		}
	}
	var added []models.MarcoGroupMember
	for _, raw := range macs {
		mac := strings.ToUpper(strings.TrimSpace(raw))
		if mac == "" {
			continue
		}
		device, err := s.resolveDeviceByMAC(ctx, orgID, mac, known[mac])
		if err != nil {
			return added, fmt.Errorf("resolve MAC %s: %w", mac, err)
		}
		// A device can only belong to one Marco group: leave the previous one.
		if err := s.marcoRepo.RemoveDeviceFromAllGroups(ctx, orgID, device.ID); err != nil {
			return added, err
		}
		if err := s.marcoRepo.AddMember(ctx, groupID, device.ID); err != nil {
			return added, err
		}
		added = append(added, models.MarcoGroupMember{ID: uuid.New(), GroupID: groupID, DeviceID: device.ID, DeviceName: device.Name, MACAddress: device.MACAddress, IPAddress: device.IPAddress})
		s.log(ctx, orgID, &groupID, &device.ID, "member_added", fmt.Sprintf("%s added to group %q", deviceName(device), g.Name), "applied", "")
	}

	if len(added) == 0 {
		return added, nil
	}
	s.scheduleSync(orgID, &groupID, func() { s.logMemberPolicyChanges(context.Background(), orgID, g) })
	return added, nil
}

func (s *MarcoGroupService) RemoveMember(ctx context.Context, orgID, groupID, deviceID uuid.UUID) error {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, groupID)
	if err != nil {
		return err
	}
	if err := s.marcoRepo.RemoveMember(ctx, groupID, deviceID); err != nil {
		return err
	}
	s.log(ctx, orgID, &groupID, &deviceID, "member_removed", fmt.Sprintf("Device removed from group %q", g.Name), "applied", "")
	s.scheduleSync(orgID, &groupID, nil)
	return nil
}

// MoveDevice moves a device to a Marco group (removes old group policies and
// applies the new ones immediately). groupID must be a valid Marco group.
func (s *MarcoGroupService) MoveDevice(ctx context.Context, orgID, deviceID, targetGroupID uuid.UUID) error {
	target, err := s.marcoRepo.GetGroupByID(ctx, orgID, targetGroupID)
	if err != nil {
		return fmt.Errorf("target Marco group not found: %w", err)
	}
	device, err := s.deviceRepo.GetByIDForOrganization(ctx, orgID, deviceID)
	if err != nil {
		return err
	}
	// Leave any previous Marco group.
	if err := s.marcoRepo.RemoveDeviceFromAllGroups(ctx, orgID, deviceID); err != nil {
		return err
	}
	if err := s.marcoRepo.AddMember(ctx, targetGroupID, deviceID); err != nil {
		return err
	}
	s.log(ctx, orgID, &targetGroupID, &deviceID, "member_moved", fmt.Sprintf("%s moved to group %q - old policies removed, new policies applied", deviceName(device), target.Name), "applied", "")
	s.scheduleSync(orgID, &targetGroupID, func() { s.logMemberPolicyChanges(context.Background(), orgID, target) })
	return nil
}

func (s *MarcoGroupService) UpdatePolicy(ctx context.Context, orgID, groupID uuid.UUID, policy models.MarcoGroupPolicy) error {
	g, err := s.marcoRepo.GetGroupByID(ctx, orgID, groupID)
	if err != nil {
		return err
	}
	if err := ValidatePolicySites(policy); err != nil {
		return err
	}
	policy = NormalizeMarcoPolicy(policy)
	if err := s.marcoRepo.UpdateGroupPolicy(ctx, orgID, groupID, policy); err != nil {
		return err
	}
	g.Policy = policy
	s.log(ctx, orgID, &groupID, nil, "policy_applied", fmt.Sprintf("Policy applied to group %q", g.Name), "applied", "")
	s.scheduleSync(orgID, &groupID, func() { s.logMemberPolicyChanges(context.Background(), orgID, g) })
	return nil
}

// DryRun reports whether router writes are disabled: policies are saved and
// planned, but nothing is changed on the MikroTik.
func (s *MarcoGroupService) DryRun() bool {
	return !s.cfg.RouterPolicyWrites
}

// MarcoSyncSummary is returned by an explicit sync request.
type MarcoSyncSummary struct {
	DryRun   bool     `json:"dry_run"`
	Planned  []string `json:"planned_changes"`
	Warnings []string `json:"warnings"`
	// PruneSkipped is how many old entries are still on the router waiting for a confirmed removal.
	PruneSkipped int `json:"prune_pending"`
}

func (s *MarcoGroupService) Sync(ctx context.Context, orgID uuid.UUID, confirmRemovals bool) (*MarcoSyncSummary, error) {
	res, err := s.sync.SyncWith(ctx, orgID, confirmRemovals)
	if err != nil {
		return nil, err
	}
	return &MarcoSyncSummary{DryRun: res.DryRun, Planned: res.Planned, Warnings: res.Warnings, PruneSkipped: res.PruneSkipped}, nil
}

func (s *MarcoGroupService) ListLogs(ctx context.Context, orgID uuid.UUID, limit int) ([]models.MarcoPolicyLog, error) {
	return s.marcoRepo.ListPolicyLogs(ctx, orgID, limit)
}

// DeviceStatuses computes the policy status for every Marco-managed device.
func (s *MarcoGroupService) DeviceStatuses(ctx context.Context, orgID uuid.UUID) ([]models.MarcoDeviceStatus, error) {
	groups, err := s.marcoRepo.ListGroups(ctx, orgID)
	if err != nil {
		return nil, err
	}
	members, err := s.marcoRepo.ListAllMembers(ctx, orgID)
	if err != nil {
		return nil, err
	}
	groupByID := make(map[uuid.UUID]models.MarcoGroup, len(groups))
	for _, g := range groups {
		groupByID[g.ID] = g
	}
	now := time.Now()
	dayKey := now.Format("2006-01-02")
	monthKey := now.Format("2006-01")

	statuses := make([]models.MarcoDeviceStatus, 0, len(members))
	for _, m := range members {
		g, ok := groupByID[m.GroupID]
		if !ok {
			continue
		}
		st := models.MarcoDeviceStatus{
			DeviceID:        m.DeviceID.String(),
			MACAddress:      orEmpty(m.MACAddress),
			DeviceName:      m.DeviceName,
			IPAddress:       ipString(m.IPAddress),
			IsOnline:        m.IsOnline,
			GroupID:         &g.ID,
			GroupName:       g.Name,
			GroupColor:      g.Color,
			BlockedWebsites: g.Policy.BlockedWebsites,
		}
		internetEnabled := true
		if g.Policy.InternetEnabled != nil {
			internetEnabled = *g.Policy.InternetEnabled
		}
		st.InternetEnabled = internetEnabled
		unlimited := true
		if g.Policy.UnlimitedSpeed != nil {
			unlimited = *g.Policy.UnlimitedSpeed
		}
		if g.Policy.DownloadLimitMbps != nil {
			st.DownloadLimitMbps = g.Policy.DownloadLimitMbps
		}
		if g.Policy.UploadLimitMbps != nil {
			st.UploadLimitMbps = g.Policy.UploadLimitMbps
		}
		if g.Policy.ScheduleStartTime != nil {
			st.ScheduleStart = *g.Policy.ScheduleStartTime
		}
		if g.Policy.ScheduleEndTime != nil {
			st.ScheduleEnd = *g.Policy.ScheduleEndTime
		}
		st.DailyQuotaGB = g.Policy.DailyQuotaGb
		st.MonthlyQuotaGB = g.Policy.MonthlyQuotaGb

		switch {
		case !internetEnabled:
			st.Status = "blocked"
		case !unlimited && (g.Policy.DownloadLimitMbps != nil || g.Policy.UploadLimitMbps != nil):
			st.Status = "limited"
		case g.Policy.DailyQuotaGb != nil || g.Policy.MonthlyQuotaGb != nil:
			st.Status = "limited"
		default:
			st.Status = "allowed"
		}

		if g.Policy.DailyQuotaGb != nil {
			if u, err := s.marcoRepo.GetQuotaUsage(ctx, m.DeviceID, "day", dayKey); err == nil {
				st.QuotaUsedGB = float64(u.BytesUsed) / 1e9
			}
		}
		if g.Policy.MonthlyQuotaGb != nil && st.QuotaUsedGB == 0 {
			if u, err := s.marcoRepo.GetQuotaUsage(ctx, m.DeviceID, "month", monthKey); err == nil {
				st.QuotaUsedGB = float64(u.BytesUsed) / 1e9
			}
		}
		statuses = append(statuses, st)
	}
	return statuses, nil
}

// ---------------------------------------------------------------------------
// Helpers

func (s *MarcoGroupService) resolveDeviceByMAC(ctx context.Context, orgID uuid.UUID, mac string, seen ClientView) (*models.Device, error) {
	device, err := s.deviceRepo.GetByMACForOrganization(ctx, orgID, mac)
	if err == nil {
		return device, nil
	}
	// A device the router has seen starts with its real name and address.
	ip := net.ParseIP(seen.IP)
	if ip == nil {
		ip = net.ParseIP("0.0.0.0")
	}
	name := mac
	if seen.DisplayName != "" {
		name = seen.DisplayName
	}
	macCopy := mac
	placeholder := &models.Device{
		ID: uuid.New(), OrganizationID: orgID, Name: name, IPAddress: ip,
		MACAddress: &macCopy, DeviceType: "unknown", Status: "unknown",
	}
	id, _, err := s.deviceRepo.UpsertDiscovered(ctx, placeholder)
	if err != nil {
		return nil, err
	}
	placeholder.ID = id
	return placeholder, nil
}

func (s *MarcoGroupService) logMemberPolicyChanges(ctx context.Context, orgID uuid.UUID, g *models.MarcoGroup) {
	members, err := s.marcoRepo.ListMembers(ctx, g.ID)
	if err != nil {
		return
	}
	parts := policySummary(g.Policy)
	for _, m := range members {
		name := m.DeviceName
		if name == "" {
			name = orEmpty(m.MACAddress)
		}
		msg := fmt.Sprintf("%s: %s", name, parts)
		s.log(ctx, orgID, &g.ID, &m.DeviceID, "policy_applied", msg, "applied", "")
	}
}

func policySummary(p models.MarcoGroupPolicy) string {
	var parts []string
	if p.InternetEnabled != nil && !*p.InternetEnabled {
		parts = append(parts, "internet disabled")
	} else {
		parts = append(parts, "internet enabled")
	}
	if p.UnlimitedSpeed != nil && !*p.UnlimitedSpeed {
		if p.DownloadLimitMbps != nil || p.UploadLimitMbps != nil {
			dl := "unlimited"
			ul := "unlimited"
			if p.DownloadLimitMbps != nil {
				dl = fmt.Sprintf("%.0f Mbps", *p.DownloadLimitMbps)
			}
			if p.UploadLimitMbps != nil {
				ul = fmt.Sprintf("%.0f Mbps", *p.UploadLimitMbps)
			}
			parts = append(parts, fmt.Sprintf("limits %s download / %s upload", dl, ul))
		}
	} else {
		parts = append(parts, "unlimited speed")
	}
	if len(p.BlockedWebsites) > 0 {
		labels := make([]string, 0, len(p.BlockedWebsites))
		for _, k := range p.BlockedWebsites {
			if def, ok := marcoPlatformByKey[k]; ok {
				labels = append(labels, def.Label)
			}
		}
		parts = append(parts, "blocked: "+strings.Join(labels, ", "))
	}
	if len(parts) == 0 {
		return "no restrictions"
	}
	return strings.Join(parts, "; ")
}

func (s *MarcoGroupService) log(ctx context.Context, orgID uuid.UUID, groupID, deviceID *uuid.UUID, action, message, status, routerError string) {
	// While router writes are disabled a policy is only saved, never applied.
	if s.DryRun() && status == "applied" {
		switch action {
		case "policy_applied", "member_added", "member_moved", "member_removed":
			status = "saved"
		}
	}
	l := &models.MarcoPolicyLog{
		ID: uuid.New(), OrganizationID: orgID, GroupID: groupID, DeviceID: deviceID,
		Action: action, Message: message, Status: status,
	}
	if routerError != "" {
		l.RouterError = &routerError
	}
	_ = s.marcoRepo.CreatePolicyLog(ctx, l)
}

func buildGroupView(g models.MarcoGroup, members []models.MarcoGroupMember) models.MarcoGroupView {
	return models.MarcoGroupView{
		MarcoGroup:  g,
		Members:     members,
		MemberCount: len(members),
	}
}

func groupMembersByGroup(members []models.MarcoGroupMember) map[uuid.UUID][]models.MarcoGroupMember {
	out := make(map[uuid.UUID][]models.MarcoGroupMember)
	for _, m := range members {
		out[m.GroupID] = append(out[m.GroupID], m)
	}
	return out
}

func deviceName(d *models.Device) string {
	if d.Name != "" {
		return d.Name
	}
	if d.MACAddress != nil {
		return *d.MACAddress
	}
	return d.ID.String()
}

func orEmpty(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func ipString(ip net.IP) string {
	if ip == nil {
		return ""
	}
	return ip.String()
}

// NormalizeMarcoPolicy validates and normalizes a group policy.
func NormalizeMarcoPolicy(p models.MarcoGroupPolicy) models.MarcoGroupPolicy {
	if p.InternetEnabled == nil {
		v := true
		p.InternetEnabled = &v
	}
	if p.UnlimitedSpeed == nil {
		v := true
		p.UnlimitedSpeed = &v
	}
	if p.BurstTimeSeconds == nil {
		v := 16
		p.BurstTimeSeconds = &v
	}
	if p.QosPriority != nil {
		if *p.QosPriority < 1 || *p.QosPriority > 8 {
			p.QosPriority = nil
		}
	}
	p.ScheduleDays = normalizeDays(p.ScheduleDays)
	p.BlockedWebsites = sortedPlatformKeys(p.BlockedWebsites)
	p.BlockedPacks = normalizedPacks(p.BlockedPacks)
	p.BlockedDomains = normalizeSites(p.BlockedDomains)
	return p
}

func normalizeDays(days []string) []string {
	valid := map[string]bool{"mon": true, "tue": true, "wed": true, "thu": true, "fri": true, "sat": true, "sun": true}
	var out []string
	seen := make(map[string]bool)
	for _, d := range days {
		d = strings.ToLower(strings.TrimSpace(d))
		if valid[d] && !seen[d] {
			seen[d] = true
			out = append(out, d)
		}
	}
	sort.Strings(out)
	return out
}

func sortedPlatformKeys(keys []string) []string {
	var out []string
	seen := make(map[string]bool)
	for _, k := range keys {
		key := strings.ToLower(strings.TrimSpace(k))
		if _, ok := marcoPlatformByKey[key]; ok && !seen[key] {
			seen[key] = true
			out = append(out, key)
		}
	}
	sort.Strings(out)
	return out
}
