package services

import (
	"context"
	"fmt"
	"sort"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
)

const (
	maxReportDays   = 366
	topDevicesShown = 15
)

// ReportRangeError is returned for a period that cannot be reported on.
type ReportRangeError struct{ Message string }

func (e *ReportRangeError) Error() string { return e.Message }

// ReportPeriod is a range of whole days. To is the last day included.
type ReportPeriod struct {
	From string `json:"from"`
	To   string `json:"to"`
	Days int    `json:"days"`
}

// ReportCoverage says how much of the period was actually measured.
type ReportCoverage struct {
	NoData       bool       `json:"no_data"`
	Partial      bool       `json:"partial"`
	WANSince     *time.Time `json:"wan_since,omitempty"`
	DevicesSince *time.Time `json:"devices_since,omitempty"`
	Note         string     `json:"note,omitempty"`
}

// ReportTotals are the headline numbers of the period.
type ReportTotals struct {
	WANDown       int64 `json:"wan_download_bytes"`
	WANUp         int64 `json:"wan_upload_bytes"`
	WANTotal      int64 `json:"wan_total_bytes"`
	DeviceDown    int64 `json:"device_download_bytes"`
	DeviceUp      int64 `json:"device_upload_bytes"`
	DeviceTotal   int64 `json:"device_total_bytes"`
	ActiveDevices int   `json:"active_devices"`
	NewDevices    int   `json:"new_devices"`
	SeenDevices   int   `json:"seen_devices"`
	PeakDownBps   int64 `json:"peak_download_bps"`
	PeakUpBps     int64 `json:"peak_upload_bps"`
	AvgPerDay     int64 `json:"avg_bytes_per_day"`
	// CoveragePct is the share of the internet traffic that is attributed to a device.
	CoveragePct *float64 `json:"device_coverage_pct,omitempty"`
}

// ReportCompare sets the period against the one just before it, of the same length.
type ReportCompare struct {
	Previous        ReportPeriod `json:"previous"`
	WANTotalPrev    int64        `json:"wan_total_bytes"`
	DeviceTotalPrev int64        `json:"device_total_bytes"`
	WANChangePct    *float64     `json:"wan_change_pct,omitempty"`
	DeviceChangePct *float64     `json:"device_change_pct,omitempty"`
}

// DayPoint is one day of the chart.
type DayPoint struct {
	Day           string `json:"day"`
	WANDown       int64  `json:"wan_download_bytes"`
	WANUp         int64  `json:"wan_upload_bytes"`
	DeviceDown    int64  `json:"device_download_bytes"`
	DeviceUp      int64  `json:"device_upload_bytes"`
	ActiveDevices int    `json:"active_devices"`
}

// HourPoint is the internet traffic of one hour of the day over the period.
type HourPoint struct {
	Hour   int   `json:"hour"`
	Down   int64 `json:"download_bytes"`
	Up     int64 `json:"upload_bytes"`
	AvgBps int64 `json:"avg_bps"`
}

// ReportDevice is one row of the top-devices table.
type ReportDevice struct {
	Rank       int     `json:"rank"`
	MAC        string  `json:"mac"`
	Name       string  `json:"name"`
	NameSource string  `json:"name_source"`
	IP         string  `json:"ip"`
	Kind       string  `json:"kind"`
	Place      string  `json:"place"`
	Down       int64   `json:"download_bytes"`
	Up         int64   `json:"upload_bytes"`
	Total      int64   `json:"total_bytes"`
	SharePct   float64 `json:"share_pct"`
	ActiveDays int     `json:"active_days"`
	Online     bool    `json:"online"`
}

// ReportGroup is traffic grouped by device type or place.
type ReportGroup struct {
	Key      string  `json:"key"`
	Down     int64   `json:"download_bytes"`
	Up       int64   `json:"upload_bytes"`
	Total    int64   `json:"total_bytes"`
	Devices  int     `json:"devices"`
	SharePct float64 `json:"share_pct"`
}

// ReportAlerts summarises the alerts raised in the period.
type ReportAlerts struct {
	Total      int            `json:"total"`
	Open       int            `json:"open"`
	BySeverity map[string]int `json:"by_severity"`
}

// ReportEvent is a count of one kind of device event.
type ReportEvent struct {
	Type  string `json:"type"`
	Count int    `json:"count"`
}

// ReportSecurity is the latest connection scan.
type ReportSecurity struct {
	TakenAt    time.Time      `json:"taken_at"`
	Findings   int            `json:"findings"`
	BySeverity map[string]int `json:"by_severity"`
}

// ReportProjection estimates the month's total from what was used so far.
type ReportProjection struct {
	UsedBytes      int64 `json:"used_bytes"`
	ProjectedBytes int64 `json:"projected_bytes"`
	DaysElapsed    int   `json:"days_elapsed"`
	DaysInMonth    int   `json:"days_in_month"`
}

// ReportInsight is a sentence worth reading.
type ReportInsight struct {
	Level string `json:"level"` // info | warning
	Text  string `json:"text"`
}

// UsageReport is the response of the report endpoint.
type UsageReport struct {
	GeneratedAt time.Time         `json:"generated_at"`
	Period      ReportPeriod      `json:"period"`
	Coverage    ReportCoverage    `json:"coverage"`
	Totals      ReportTotals      `json:"totals"`
	Compare     ReportCompare     `json:"compare"`
	Daily       []DayPoint        `json:"daily"`
	Hourly      []HourPoint       `json:"hourly"`
	TopDevices  []ReportDevice    `json:"top_devices"`
	DeviceCount int               `json:"device_count"`
	ByKind      []ReportGroup     `json:"by_kind"`
	ByPlace     []ReportGroup     `json:"by_place"`
	Alerts      ReportAlerts      `json:"alerts"`
	Events      []ReportEvent     `json:"events"`
	Security    *ReportSecurity   `json:"security,omitempty"`
	Projection  *ReportProjection `json:"projection,omitempty"`
	Insights    []ReportInsight   `json:"insights"`
}

// UsageReportService builds the usage report from what the NMS has recorded.
type UsageReportService struct {
	repo      *repository.UsageReportRepository
	clients   *repository.ClientRepository
	inventory *ClientInventoryService
	security  *SecurityScanService
}

func NewUsageReportService(repo *repository.UsageReportRepository, clients *repository.ClientRepository, inventory *ClientInventoryService, security *SecurityScanService) *UsageReportService {
	return &UsageReportService{repo: repo, clients: clients, inventory: inventory, security: security}
}

// ParseReportRange reads two dates (YYYY-MM-DD, both days included) in the server's
// time zone and returns the instants [from, to) that cover them.
func ParseReportRange(fromStr, toStr string, now time.Time) (time.Time, time.Time, error) {
	loc := now.Location()
	from, err := time.ParseInLocation("2006-01-02", strings.TrimSpace(fromStr), loc)
	if err != nil {
		return time.Time{}, time.Time{}, &ReportRangeError{"The start date must look like 2026-11-02"}
	}
	last, err := time.ParseInLocation("2006-01-02", strings.TrimSpace(toStr), loc)
	if err != nil {
		return time.Time{}, time.Time{}, &ReportRangeError{"The end date must look like 2026-11-02"}
	}
	if last.Before(from) {
		return time.Time{}, time.Time{}, &ReportRangeError{"The end date is before the start date"}
	}
	to := last.AddDate(0, 0, 1)
	if int(to.Sub(from).Hours()/24+0.5) > maxReportDays {
		return time.Time{}, time.Time{}, &ReportRangeError{"A report can cover at most one year"}
	}
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, loc)
	if from.After(today) {
		return time.Time{}, time.Time{}, &ReportRangeError{"The start date is in the future"}
	}
	return from, to, nil
}

// Build reports on the days from..to (instants, whole days).
func (s *UsageReportService) Build(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*UsageReport, error) {
	return s.build(ctx, orgID, from, to, topDevicesShown)
}

func (s *UsageReportService) build(ctx context.Context, orgID uuid.UUID, from, to time.Time, deviceLimit int) (*UsageReport, error) {
	days := daysBetween(from, to)
	prevTo := from
	prevFrom := from.AddDate(0, 0, -days)

	in := usageInputs{from: from, to: to, prevFrom: prevFrom, prevTo: prevTo, now: time.Now(), deviceLimit: deviceLimit}
	var err error
	if in.wan, err = s.repo.WANRange(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.prevWAN, err = s.repo.WANRange(ctx, orgID, prevFrom, prevTo); err != nil {
		return nil, err
	}
	if in.wanDaily, err = s.repo.WANDaily(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.hourly, err = s.repo.WANHourly(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.clientDaily, err = s.repo.ClientDaily(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	prevDaily, err := s.repo.ClientDaily(ctx, orgID, prevFrom, prevTo)
	if err != nil {
		return nil, err
	}
	for _, d := range prevDaily {
		in.prevDeviceTotal += d.ClientDown + d.ClientUp
	}
	if in.usage, err = s.repo.ClientUsage(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.firstWAN, err = s.repo.FirstWAN(ctx, orgID); err != nil {
		return nil, err
	}
	if in.firstUsage, err = s.repo.FirstUsageDay(ctx, orgID); err != nil {
		return nil, err
	}
	if in.newDevices, in.seenDevices, err = s.repo.DeviceCounts(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.alerts, err = s.repo.Alerts(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	if in.events, err = s.repo.Events(ctx, orgID, from, to); err != nil {
		return nil, err
	}
	list, err := s.inventory.List(ctx, orgID)
	if err != nil {
		return nil, err
	}
	in.clients = make(map[string]ClientView, len(list.Clients))
	for _, c := range list.Clients {
		in.clients[c.MAC] = c
	}
	if in.notes, err = s.clients.Notes(ctx, orgID); err != nil {
		return nil, err
	}
	if s.security != nil {
		in.scan = s.security.Latest(ctx, orgID)
	}
	return composeUsageReport(in), nil
}

// usageInputs is everything composeUsageReport needs, so it can run without a
// database.
type usageInputs struct {
	from, to, prevFrom, prevTo time.Time
	now                        time.Time
	wan, prevWAN               repository.WANTotals
	wanDaily                   map[string][2]int64
	hourly                     []repository.HourOfDay
	clientDaily                map[string]repository.DayTotals
	prevDeviceTotal            int64
	usage                      []repository.DeviceUsage
	firstWAN, firstUsage       time.Time
	newDevices, seenDevices    int
	alerts                     []repository.AlertCount
	events                     []repository.EventCount
	clients                    map[string]ClientView
	notes                      map[string]repository.ClientNote
	scan                       *ScanSnapshot
	deviceLimit                int
}

func daysBetween(from, to time.Time) int {
	d := int(to.Sub(from).Hours()/24 + 0.5)
	if d < 1 {
		d = 1
	}
	return d
}

func dayKey(t time.Time) string { return t.Format("2006-01-02") }

func pctChange(now, before int64) *float64 {
	if before <= 0 {
		return nil
	}
	v := (float64(now) - float64(before)) / float64(before) * 100
	return &v
}

func composeUsageReport(in usageInputs) *UsageReport {
	days := daysBetween(in.from, in.to)
	last := in.to.AddDate(0, 0, -1)
	r := &UsageReport{
		GeneratedAt: in.now,
		Period:      ReportPeriod{From: dayKey(in.from), To: dayKey(last), Days: days},
		Hourly:      make([]HourPoint, 24),
		TopDevices:  []ReportDevice{},
		ByKind:      []ReportGroup{},
		ByPlace:     []ReportGroup{},
		Events:      []ReportEvent{},
		Insights:    []ReportInsight{},
	}
	r.Compare.Previous = ReportPeriod{From: dayKey(in.prevFrom), To: dayKey(in.prevTo.AddDate(0, 0, -1)), Days: days}

	// Days.
	var busiest *DayPoint
	for i := 0; i < days; i++ {
		d := in.from.AddDate(0, 0, i)
		key := dayKey(d)
		p := DayPoint{Day: key}
		if w, ok := in.wanDaily[key]; ok {
			p.WANDown, p.WANUp = w[0], w[1]
		}
		if c, ok := in.clientDaily[key]; ok {
			p.DeviceDown, p.DeviceUp, p.ActiveDevices = c.ClientDown, c.ClientUp, c.ActiveCount
		}
		r.Daily = append(r.Daily, p)
	}
	for i := range r.Daily {
		p := &r.Daily[i]
		if busiest == nil || p.WANDown+p.WANUp > busiest.WANDown+busiest.WANUp {
			busiest = p
		}
	}

	// Totals.
	t := &r.Totals
	t.WANDown, t.WANUp = in.wan.Down, in.wan.Up
	t.WANTotal = t.WANDown + t.WANUp
	for _, p := range r.Daily {
		t.DeviceDown += p.DeviceDown
		t.DeviceUp += p.DeviceUp
	}
	t.DeviceTotal = t.DeviceDown + t.DeviceUp
	t.ActiveDevices = len(in.usage)
	t.NewDevices, t.SeenDevices = in.newDevices, in.seenDevices
	t.PeakDownBps, t.PeakUpBps = in.wan.PeakDownBps, in.wan.PeakUpBps
	t.AvgPerDay = t.WANTotal / int64(days)
	if t.WANTotal > 0 && t.DeviceTotal > 0 {
		v := float64(t.DeviceTotal) / float64(t.WANTotal) * 100
		t.CoveragePct = &v
	}
	r.Compare.WANTotalPrev = in.prevWAN.Down + in.prevWAN.Up
	r.Compare.DeviceTotalPrev = in.prevDeviceTotal
	r.Compare.WANChangePct = pctChange(t.WANTotal, r.Compare.WANTotalPrev)
	r.Compare.DeviceChangePct = pctChange(t.DeviceTotal, r.Compare.DeviceTotalPrev)

	// Hours of the day.
	for h := range r.Hourly {
		r.Hourly[h].Hour = h
	}
	for _, h := range in.hourly {
		if h.Hour >= 0 && h.Hour < 24 {
			r.Hourly[h.Hour] = HourPoint{Hour: h.Hour, Down: h.Down, Up: h.Up, AvgBps: h.AvgBp}
		}
	}

	// Coverage: what part of the period was measured.
	if !in.firstWAN.IsZero() {
		f := in.firstWAN
		r.Coverage.WANSince = &f
	}
	if !in.firstUsage.IsZero() {
		f := in.firstUsage
		r.Coverage.DevicesSince = &f
	}
	r.Coverage.NoData = t.WANTotal == 0 && t.DeviceTotal == 0
	switch {
	case r.Coverage.NoData && in.firstWAN.IsZero() && in.firstUsage.IsZero():
		r.Coverage.Note = "Nothing has been measured yet. The server records internet and device usage while it runs."
	case r.Coverage.NoData:
		r.Coverage.Note = "Nothing was measured in this period. Measuring started on " + earliest(in.firstWAN, in.firstUsage).Format("2 Jan 2006") + "."
	default:
		if start := earliest(in.firstWAN, in.firstUsage); !start.IsZero() && start.After(in.from) {
			r.Coverage.Partial = true
			r.Coverage.Note = "Measuring started on " + start.Format("2 Jan 2006") + ", so the days before it are empty, not zero."
		}
	}

	// Devices.
	type agg struct{ down, up int64 }
	kinds, places := map[string]*agg{}, map[string]*agg{}
	kindDevs, placeDevs := map[string]int{}, map[string]int{}
	for i, u := range in.usage {
		c, known := in.clients[u.MAC]
		name, nameSource, ip, kind := u.MAC, "ip", "", KindUnknown
		online := false
		if known {
			name, nameSource, ip, kind, online = c.DisplayName, c.NameSource, c.IP, c.Kind, c.Online
		}
		place := strings.TrimSpace(in.notes[u.MAC].Place)
		total := u.Down + u.Up
		share := 0.0
		if t.DeviceTotal > 0 {
			share = float64(total) / float64(t.DeviceTotal) * 100
		}
		if i < in.deviceLimit {
			r.TopDevices = append(r.TopDevices, ReportDevice{
				Rank: i + 1, MAC: u.MAC, Name: name, NameSource: nameSource, IP: ip, Kind: kind, Place: place,
				Down: u.Down, Up: u.Up, Total: total, SharePct: share, ActiveDays: u.ActiveDays, Online: online,
			})
		}
		if kinds[kind] == nil {
			kinds[kind] = &agg{}
		}
		kinds[kind].down += u.Down
		kinds[kind].up += u.Up
		kindDevs[kind]++
		pk := place
		if pk == "" {
			pk = "Not set"
		}
		if places[pk] == nil {
			places[pk] = &agg{}
		}
		places[pk].down += u.Down
		places[pk].up += u.Up
		placeDevs[pk]++
	}
	r.DeviceCount = len(in.usage)
	groups := func(m map[string]*agg, devs map[string]int) []ReportGroup {
		out := make([]ReportGroup, 0, len(m))
		for k, a := range m {
			g := ReportGroup{Key: k, Down: a.down, Up: a.up, Total: a.down + a.up, Devices: devs[k]}
			if t.DeviceTotal > 0 {
				g.SharePct = float64(g.Total) / float64(t.DeviceTotal) * 100
			}
			out = append(out, g)
		}
		sort.Slice(out, func(i, j int) bool {
			if out[i].Total != out[j].Total {
				return out[i].Total > out[j].Total
			}
			return out[i].Key < out[j].Key
		})
		return out
	}
	r.ByKind = groups(kinds, kindDevs)
	r.ByPlace = groups(places, placeDevs)

	// Alerts, events, security.
	r.Alerts.BySeverity = map[string]int{}
	for _, a := range in.alerts {
		r.Alerts.Total += a.Count
		r.Alerts.BySeverity[a.Severity] += a.Count
		if a.Status == "open" || a.Status == "acknowledged" {
			r.Alerts.Open += a.Count
		}
	}
	for _, e := range in.events {
		r.Events = append(r.Events, ReportEvent{Type: e.Type, Count: e.Count})
	}
	if in.scan != nil {
		sec := &ReportSecurity{TakenAt: in.scan.TakenAt, Findings: len(in.scan.Findings), BySeverity: map[string]int{}}
		for _, f := range in.scan.Findings {
			sec.BySeverity[f.Severity]++
		}
		r.Security = sec
	}

	// Projection for a whole calendar month that is still running.
	if in.from.Day() == 1 && in.to.Equal(time.Date(in.from.Year(), in.from.Month()+1, 1, 0, 0, 0, 0, in.from.Location())) &&
		!in.now.Before(in.from) && in.now.Before(in.to) && t.WANTotal > 0 {
		elapsed := in.now.Sub(in.from).Hours() / 24
		inMonth := daysBetween(in.from, in.to)
		if elapsed >= 1 {
			r.Projection = &ReportProjection{
				UsedBytes: t.WANTotal, ProjectedBytes: int64(float64(t.WANTotal) / elapsed * float64(inMonth)),
				DaysElapsed: int(elapsed), DaysInMonth: inMonth,
			}
		}
	}

	r.Insights = insightsFor(r, busiest, in)
	return r
}

func earliest(a, b time.Time) time.Time {
	switch {
	case a.IsZero():
		return b
	case b.IsZero():
		return a
	case a.Before(b):
		return a
	}
	return b
}

// HumanBytes writes a byte count the way the pages do: decimal units, as ISPs state them.
func HumanBytes(n int64) string {
	const unit = 1000
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	v, i := float64(n), 0
	units := []string{"B", "KB", "MB", "GB", "TB"}
	for v >= unit && i < len(units)-1 {
		v /= unit
		i++
	}
	if v >= 100 {
		return fmt.Sprintf("%.0f %s", v, units[i])
	}
	return fmt.Sprintf("%.1f %s", v, units[i])
}

func insightsFor(r *UsageReport, busiest *DayPoint, in usageInputs) []ReportInsight {
	var out []ReportInsight
	add := func(level, text string) { out = append(out, ReportInsight{Level: level, Text: text}) }
	t := r.Totals
	if r.Coverage.NoData {
		return out
	}
	if r.Coverage.Partial {
		add("warning", r.Coverage.Note)
	}
	if c := r.Compare.WANChangePct; c != nil && (*c >= 10 || *c <= -10) && !r.Coverage.Partial {
		dir := "up"
		if *c < 0 {
			dir = "down"
		}
		add("info", fmt.Sprintf("Internet use is %s %.0f%% compared with the %d days before (%s against %s).",
			dir, abs(*c), r.Period.Days, HumanBytes(t.WANTotal), HumanBytes(r.Compare.WANTotalPrev)))
	}
	if busiest != nil && busiest.WANDown+busiest.WANUp > 0 && r.Period.Days > 1 {
		d, _ := time.ParseInLocation("2006-01-02", busiest.Day, in.from.Location())
		add("info", fmt.Sprintf("The busiest day was %s with %s of internet traffic.", d.Format("Monday 2 Jan"), HumanBytes(busiest.WANDown+busiest.WANUp)))
	}
	bestHour, bestBytes := -1, int64(0)
	for _, h := range r.Hourly {
		if h.Down+h.Up > bestBytes {
			bestHour, bestBytes = h.Hour, h.Down+h.Up
		}
	}
	if bestHour >= 0 {
		add("info", fmt.Sprintf("The busiest hour of the day is %02d:00 to %02d:00.", bestHour, (bestHour+1)%24))
	}
	if len(r.TopDevices) > 0 {
		top := r.TopDevices[0]
		if top.SharePct >= 25 {
			add("info", fmt.Sprintf("%s used %.0f%% of all device traffic (%s).", top.Name, top.SharePct, HumanBytes(top.Total)))
		}
		unnamed := 0
		limit := len(r.TopDevices)
		if limit > 10 {
			limit = 10
		}
		for _, d := range r.TopDevices[:limit] {
			if d.NameSource == "ip" || d.NameSource == "guess" || d.Name == d.IP || d.Name == d.MAC {
				unnamed++
			}
		}
		if unnamed > 0 {
			add("warning", fmt.Sprintf("%d of the %d biggest users have no name. Name them in the Network Map so this report says who they are.", unnamed, limit))
		}
	}
	if t.CoveragePct != nil && *t.CoveragePct < 50 {
		add("info", fmt.Sprintf("Device counters explain %.0f%% of the internet traffic. The rest cannot be traced to a device from the router's counters.", *t.CoveragePct))
	}
	if r.Alerts.Open > 0 {
		add("warning", fmt.Sprintf("%d alert%s from this period %s still open.", r.Alerts.Open, plural(r.Alerts.Open), isAre(r.Alerts.Open)))
	}
	if r.Security != nil {
		high := r.Security.BySeverity["high"] + r.Security.BySeverity["critical"]
		if high > 0 {
			add("warning", fmt.Sprintf("The latest security scan has %d high-severity finding%s.", high, plural(high)))
		}
	}
	if p := r.Projection; p != nil {
		add("info", fmt.Sprintf("At this pace the month will end near %s of internet traffic (%s used in %d days).", HumanBytes(p.ProjectedBytes), HumanBytes(p.UsedBytes), p.DaysElapsed))
	}
	return out
}

func abs(f float64) float64 {
	if f < 0 {
		return -f
	}
	return f
}

func plural(n int) string {
	if n == 1 {
		return ""
	}
	return "s"
}

func isAre(n int) string {
	if n == 1 {
		return "is"
	}
	return "are"
}
