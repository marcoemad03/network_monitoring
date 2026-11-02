package services

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

// SetLiveSource tells the group engine where devices are right now, so a device
// added by MAC gets its address from the router.
func (s *MarcoGroupService) SetLiveSource(ls liveIPSource) { s.sync.live = ls }

// SetInventory lets group pages show each device's name, type and usage.
func (s *MarcoGroupService) SetInventory(inv *ClientInventoryService, clients *repository.ClientRepository) {
	s.inventory = inv
	s.clientRepo = clients
	s.sync.live = inv
}

// SiteCatalog is what the "block websites" screen offers.
type SiteCatalog struct {
	Platforms []models.PlatformDefinition `json:"platforms"`
	Packs     []SitePack                  `json:"packs"`
	Allowed   AllowedSites                `json:"allowed"`
}

// AllowedSites are the websites that stay reachable for every group.
type AllowedSites struct {
	Defaults []string `json:"defaults"`
	Custom   []string `json:"custom"`
}

func (s *MarcoGroupService) Catalog(ctx context.Context, orgID uuid.UUID) (SiteCatalog, error) {
	custom, err := s.marcoRepo.ListAllowDomains(ctx, orgID)
	if err != nil {
		return SiteCatalog{}, err
	}
	return SiteCatalog{Platforms: MarcoPlatforms, Packs: MarcoSitePacks, Allowed: AllowedSites{Defaults: DefaultAllowedDomains, Custom: custom}}, nil
}

// CheckSite says what blocking a typed site would do, before it is added.
func (s *MarcoGroupService) CheckSite(ctx context.Context, input string) ResolvedSite {
	return s.sync.resolver.Resolve(ctx, input)
}

// SiteStatus returns what each blocked site pointed to at the last sync.
func (s *MarcoGroupService) SiteStatus(orgID uuid.UUID) map[string]ResolvedSite {
	return s.sync.LastSiteResolution(orgID)
}

func (s *MarcoGroupService) AddAllowedSite(ctx context.Context, orgID uuid.UUID, raw string) (string, error) {
	v, kind, err := NormalizeSite(raw)
	if err != nil {
		return "", err
	}
	if kind != SiteDomain {
		return "", &SiteInputError{"Add a website name, not an address"}
	}
	if err := s.marcoRepo.AddAllowDomain(ctx, orgID, v); err != nil {
		return "", err
	}
	s.log(ctx, orgID, nil, nil, "allow_added", fmt.Sprintf("%s will always stay reachable", v), "applied", "")
	s.scheduleSync(orgID, nil, nil)
	return v, nil
}

func (s *MarcoGroupService) RemoveAllowedSite(ctx context.Context, orgID uuid.UUID, domain string) error {
	if err := s.marcoRepo.RemoveAllowDomain(ctx, orgID, strings.ToLower(strings.TrimSpace(domain))); err != nil {
		return err
	}
	s.log(ctx, orgID, nil, nil, "allow_removed", fmt.Sprintf("%s is no longer always allowed", domain), "applied", "")
	s.scheduleSync(orgID, nil, nil)
	return nil
}

// ValidatePolicySites refuses a policy whose hand-typed sites cannot be blocked, and
// says which ones.
func ValidatePolicySites(p models.MarcoGroupPolicy) error {
	var bad []string
	for _, d := range p.BlockedDomains {
		if _, _, err := NormalizeSite(d); err != nil {
			bad = append(bad, fmt.Sprintf("%q (%s)", d, err.Error()))
		}
	}
	if len(bad) > 0 {
		return &SiteInputError{"These sites cannot be blocked: " + strings.Join(bad, "; ")}
	}
	return nil
}

// ---------------------------------------------------------------------------
// Devices blocked or limited one by one

const maxSpeedMbps = 10000

// DeviceControl is a device's own block or limit.
type DeviceControlInput struct {
	Blocked           bool     `json:"blocked"`
	DownloadLimitMbps *float64 `json:"download_limit_mbps"`
	UploadLimitMbps   *float64 `json:"upload_limit_mbps"`
	Reason            string   `json:"reason"`
}

func (s *MarcoGroupService) ListOverrides(ctx context.Context, orgID uuid.UUID) ([]models.MarcoDeviceOverride, error) {
	return s.marcoRepo.ListOverrides(ctx, orgID)
}

func validLimit(v *float64) (*float64, error) {
	if v == nil || *v <= 0 {
		return nil, nil
	}
	if *v > maxSpeedMbps {
		return nil, &SiteInputError{fmt.Sprintf("A speed limit can be at most %d Mbps", maxSpeedMbps)}
	}
	return v, nil
}

// SetDeviceControl blocks a device or limits its speed. No block and no limit
// removes the control.
func (s *MarcoGroupService) SetDeviceControl(ctx context.Context, orgID uuid.UUID, rawMAC string, in DeviceControlInput) error {
	mac := normalizeMAC(rawMAC)
	if mac == "" {
		return &SiteInputError{"Invalid MAC address"}
	}
	dl, err := validLimit(in.DownloadLimitMbps)
	if err != nil {
		return err
	}
	ul, err := validLimit(in.UploadLimitMbps)
	if err != nil {
		return err
	}
	reason := strings.TrimSpace(in.Reason)
	if len([]rune(reason)) > 200 {
		return &SiteInputError{"The reason can be at most 200 characters"}
	}
	o := models.MarcoDeviceOverride{MAC: mac, Blocked: in.Blocked, DownloadLimitMbps: dl, UploadLimitMbps: ul, Reason: reason}
	if err := s.marcoRepo.SaveOverride(ctx, orgID, o); err != nil {
		return err
	}
	name := mac
	if s.inventory != nil {
		if l, err := s.inventory.List(ctx, orgID); err == nil {
			for _, c := range l.Clients {
				if c.MAC == mac {
					name = c.DisplayName
				}
			}
		}
	}
	switch {
	case in.Blocked:
		s.log(ctx, orgID, nil, nil, "device_blocked", fmt.Sprintf("%s: internet blocked", name), "applied", "")
	case dl != nil || ul != nil:
		s.log(ctx, orgID, nil, nil, "device_limited", fmt.Sprintf("%s: %s", name, limitText(dl, ul)), "applied", "")
	default:
		s.log(ctx, orgID, nil, nil, "device_released", fmt.Sprintf("%s: block and limit removed", name), "applied", "")
	}
	s.scheduleSync(orgID, nil, nil)
	return nil
}

func limitText(dl, ul *float64) string {
	d, u := "no limit", "no limit"
	if dl != nil {
		d = fmt.Sprintf("%.4g Mbps", *dl)
	}
	if ul != nil {
		u = fmt.Sprintf("%.4g Mbps", *ul)
	}
	return fmt.Sprintf("limited to %s download, %s upload", d, u)
}

// ---------------------------------------------------------------------------
// Group details

// MemberDetail is a device in a group with what is known about it.
type MemberDetail struct {
	DeviceID    string                      `json:"device_id"`
	MAC         string                      `json:"mac"`
	Name        string                      `json:"name"`
	Kind        string                      `json:"kind"`
	IP          string                      `json:"ip"`
	Online      bool                        `json:"online"`
	Vendor      string                      `json:"vendor,omitempty"`
	TodayBytes  int64                       `json:"today_bytes"`
	MonthBytes  int64                       `json:"month_bytes"`
	DownloadBps int64                       `json:"download_bps"`
	UploadBps   int64                       `json:"upload_bps"`
	Place       string                      `json:"place,omitempty"`
	LastSeen    *time.Time                  `json:"last_seen,omitempty"`
	Control     *models.MarcoDeviceOverride `json:"control,omitempty"`
	Enforced    bool                        `json:"enforced"`
	NotEnforced string                      `json:"not_enforced_reason,omitempty"`
	AddedAt     time.Time                   `json:"added_at"`
}

// SiteLine is one blocked site with the outcome of its last lookup.
type SiteLine struct {
	Target  string `json:"target"`
	Kind    string `json:"kind"` // platform | pack | domain | ip
	Label   string `json:"label"`
	Status  string `json:"status"` // blocked | partial | cannot | pending
	Detail  string `json:"detail,omitempty"`
	From    string `json:"from,omitempty"` // the pack it came from
	Address int    `json:"addresses"`
}

// GroupDetails is everything the group page shows.
type GroupDetails struct {
	Group       models.MarcoGroupView   `json:"group"`
	Members     []MemberDetail          `json:"members"`
	Summary     []string                `json:"summary"`
	Sites       []SiteLine              `json:"sites"`
	Logs        []models.MarcoPolicyLog `json:"logs"`
	DryRun      bool                    `json:"dry_run"`
	TotalBytes  int64                   `json:"today_bytes"`
	OnlineCount int                     `json:"online_count"`
}

func (s *MarcoGroupService) Details(ctx context.Context, orgID, groupID uuid.UUID) (*GroupDetails, error) {
	view, err := s.GetGroup(ctx, orgID, groupID)
	if err != nil {
		return nil, err
	}
	overrides, err := s.marcoRepo.ListOverrides(ctx, orgID)
	if err != nil {
		return nil, err
	}
	ovByMAC := map[string]models.MarcoDeviceOverride{}
	for _, o := range overrides {
		ovByMAC[o.MAC] = o
	}
	clients := map[string]ClientView{}
	if s.inventory != nil {
		if l, err := s.inventory.List(ctx, orgID); err == nil {
			for _, c := range l.Clients {
				clients[c.MAC] = c
			}
		}
	}
	notes, _ := s.inventoryPlaces(ctx, orgID)

	det := &GroupDetails{Group: *view, DryRun: s.DryRun(), Members: []MemberDetail{}, Sites: []SiteLine{}}
	for _, m := range view.Members {
		mac := strings.ToUpper(orEmpty(m.MACAddress))
		md := MemberDetail{DeviceID: m.DeviceID.String(), MAC: mac, Name: m.DeviceName, IP: ipString(m.IPAddress), Online: m.IsOnline, AddedAt: m.CreatedAt, Kind: KindUnknown}
		if c, ok := clients[mac]; ok {
			md.Name, md.Kind, md.IP, md.Online, md.Vendor = c.DisplayName, c.Kind, pickText(c.IP, md.IP), c.Online, c.Vendor
			md.TodayBytes, md.MonthBytes = c.TodayDown+c.TodayUp, c.MonthDown+c.MonthUp
			md.DownloadBps, md.UploadBps, md.LastSeen = c.DownloadBps, c.UploadBps, c.LastSeen
		}
		md.Place = notes[mac]
		if o, ok := ovByMAC[mac]; ok {
			oc := o
			md.Control = &oc
		}
		md.Enforced = md.IP != "" && md.IP != "0.0.0.0"
		if !md.Enforced {
			md.NotEnforced = "The router has not seen this device yet, so the group's rules are not applied to it. They apply as soon as it connects."
		}
		det.TotalBytes += md.TodayBytes
		if md.Online {
			det.OnlineCount++
		}
		det.Members = append(det.Members, md)
	}
	sort.SliceStable(det.Members, func(i, j int) bool {
		a, b := det.Members[i], det.Members[j]
		if a.Online != b.Online {
			return a.Online
		}
		return strings.ToLower(a.Name) < strings.ToLower(b.Name)
	})
	det.Summary = policyLines(view.Policy)
	det.Sites = s.siteLines(orgID, view.Policy)
	if logs, err := s.marcoRepo.ListPolicyLogs(ctx, orgID, 200); err == nil {
		for _, l := range logs {
			if l.GroupID != nil && *l.GroupID == groupID {
				det.Logs = append(det.Logs, l)
				if len(det.Logs) >= 30 {
					break
				}
			}
		}
	}
	if det.Logs == nil {
		det.Logs = []models.MarcoPolicyLog{}
	}
	return det, nil
}

func (s *MarcoGroupService) inventoryPlaces(ctx context.Context, orgID uuid.UUID) (map[string]string, error) {
	out := map[string]string{}
	if s.clientRepo == nil {
		return out, nil
	}
	notes, err := s.clientRepo.Notes(ctx, orgID)
	if err != nil {
		return out, err
	}
	for mac, n := range notes {
		if p := strings.TrimSpace(n.Place); p != "" {
			out[mac] = p
		}
	}
	return out, nil
}

// policyLines describes in plain words what a group's policy does.
func policyLines(p models.MarcoGroupPolicy) []string {
	var out []string
	if p.InternetEnabled != nil && !*p.InternetEnabled {
		out = append(out, "Internet is switched off")
	}
	if p.UnlimitedSpeed != nil && !*p.UnlimitedSpeed && (p.DownloadLimitMbps != nil || p.UploadLimitMbps != nil) {
		out = append(out, "Speed is limited: "+limitText(p.DownloadLimitMbps, p.UploadLimitMbps)[len("limited to "):])
	}
	if p.ScheduleStartTime != nil && p.ScheduleEndTime != nil && *p.ScheduleStartTime != "" && *p.ScheduleEndTime != "" {
		days := "every day"
		if len(p.ScheduleDays) > 0 {
			days = strings.Join(p.ScheduleDays, ", ")
		}
		out = append(out, fmt.Sprintf("Internet is off from %s to %s (%s)", *p.ScheduleStartTime, *p.ScheduleEndTime, days))
	}
	if p.DailyQuotaGb != nil {
		out = append(out, fmt.Sprintf("Daily limit of %.4g GB per device", *p.DailyQuotaGb))
	}
	if p.MonthlyQuotaGb != nil {
		out = append(out, fmt.Sprintf("Monthly limit of %.4g GB per device", *p.MonthlyQuotaGb))
	}
	n := len(p.BlockedWebsites) + len(p.BlockedPacks) + len(p.BlockedDomains)
	if n > 0 {
		out = append(out, fmt.Sprintf("%d website group%s or site%s blocked", n, plural(n), plural(n)))
	}
	if len(out) == 0 {
		out = append(out, "No restrictions yet")
	}
	return out
}

// siteLines lists every site the group blocks with how well it can be blocked.
func (s *MarcoGroupService) siteLines(orgID uuid.UUID, p models.MarcoGroupPolicy) []SiteLine {
	res := s.sync.LastSiteResolution(orgID)
	var out []SiteLine
	seen := map[string]bool{}
	for _, key := range normalizedPlatforms(p.BlockedWebsites) {
		def := marcoPlatformByKey[key]
		line := SiteLine{Target: key, Kind: "platform", Label: def.Label, Status: "blocked"}
		if len(def.IPRanges) == 0 && s.cfg.RouterPlatformDstLists[key] == "" && !s.cfg.RouterEnableLayer7 {
			line.Status, line.Detail = "cannot", "This service cannot be blocked with this router setup."
		} else if s.cfg.RouterPlatformDstLists[key] != "" {
			line.Detail = "Blocked using your router's own list. Services that share its addresses stay reachable."
		}
		seen[key] = true
		out = append(out, line)
	}
	for _, k := range normalizedPacks(p.BlockedPacks) {
		pack := sitePackByKey[k]
		out = append(out, SiteLine{Target: k, Kind: "pack", Label: pack.Label, Status: "blocked", Detail: fmt.Sprintf("%d sites", len(pack.Domains)+len(pack.Platforms))})
	}
	for _, d := range normalizeSites(p.BlockedDomains) {
		line := SiteLine{Target: d, Kind: "domain", Label: d, Status: "pending", Detail: "Will be looked up at the next sync."}
		if _, kind, err := NormalizeSite(d); err == nil && kind != SiteDomain {
			line.Kind, line.Status, line.Detail, line.Address = string(kind), "blocked", "", 1
		} else if r, ok := res[d]; ok {
			line.Address = len(r.IPs)
			switch {
			case !r.Blockable():
				line.Status, line.Detail = "cannot", capitalise(r.Error)+"."
			case len(r.Shared) > 0:
				line.Status, line.Detail = "partial", fmt.Sprintf("%d of %d addresses are shared and were left out.", len(r.Shared), len(r.Shared)+len(r.IPs))
			default:
				line.Status, line.Detail = "blocked", ""
			}
		}
		out = append(out, line)
	}
	return out
}

func capitalise(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}
