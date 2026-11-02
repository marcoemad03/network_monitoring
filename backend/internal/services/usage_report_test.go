package services

import (
	"strings"
	"testing"
	"time"

	"github.com/hospital/nms-backend/internal/repository"
)

func day(s string) time.Time {
	t, err := time.ParseInLocation("2006-01-02", s, time.Local)
	if err != nil {
		panic(err)
	}
	return t
}

func TestParseReportRange(t *testing.T) {
	now := day("2026-11-10").Add(15 * time.Hour)
	from, to, err := ParseReportRange("2026-11-01", "2026-11-07", now)
	if err != nil || !from.Equal(day("2026-11-01")) || !to.Equal(day("2026-11-08")) {
		t.Fatalf("range = %v %v %v", from, to, err)
	}
	bad := [][2]string{{"x", "2026-11-07"}, {"2026-11-01", "y"}, {"2026-11-08", "2026-11-01"}, {"2025-01-01", "2026-11-01"}, {"2026-11-20", "2026-11-21"}}
	for _, b := range bad {
		if _, _, err := ParseReportRange(b[0], b[1], now); err == nil {
			t.Errorf("%v should be refused", b)
		} else if _, ok := err.(*ReportRangeError); !ok {
			t.Errorf("%v: wrong error type %T", b, err)
		}
	}
}

func baseInputs() usageInputs {
	from, to := day("2026-11-01"), day("2026-11-04") // 3 days
	return usageInputs{
		from: from, to: to, prevFrom: from.AddDate(0, 0, -3), prevTo: from,
		now: day("2026-11-04").Add(time.Hour), deviceLimit: 15,
		wan:     repository.WANTotals{Down: 8 << 30, Up: 2 << 30, PeakDownBps: 90_000_000, PeakUpBps: 10_000_000},
		prevWAN: repository.WANTotals{Down: 4 << 30, Up: 1 << 30},
		wanDaily: map[string][2]int64{
			"2026-11-01": {1 << 30, 1 << 29}, "2026-11-02": {6 << 30, 1 << 30}, "2026-11-03": {1 << 30, 1 << 29},
		},
		hourly: []repository.HourOfDay{{Hour: 11, Down: 5 << 30, Up: 1 << 30, AvgBp: 5_000_000}, {Hour: 3, Down: 1 << 20}},
		clientDaily: map[string]repository.DayTotals{
			"2026-11-01": {ClientDown: 1 << 29, ClientUp: 1 << 20, ActiveCount: 3},
			"2026-11-02": {ClientDown: 3 << 30, ClientUp: 1 << 28, ActiveCount: 4},
		},
		prevDeviceTotal: 1 << 30,
		usage: []repository.DeviceUsage{
			{MAC: "AA:AA:AA:00:00:01", Down: 3 << 30, Up: 1 << 28, ActiveDays: 2},
			{MAC: "AA:AA:AA:00:00:02", Down: 1 << 29, Up: 1 << 20, ActiveDays: 1},
			{MAC: "AA:AA:AA:00:00:09", Down: 1 << 20, Up: 0, ActiveDays: 1},
		},
		firstWAN: day("2026-10-01"), firstUsage: day("2026-10-01"),
		newDevices: 2, seenDevices: 40,
		alerts: []repository.AlertCount{{Severity: "high", Status: "open", Count: 2}, {Severity: "low", Status: "resolved", Count: 1}},
		events: []repository.EventCount{{Type: "device_offline", Count: 5}},
		clients: map[string]ClientView{
			"AA:AA:AA:00:00:01": {MAC: "AA:AA:AA:00:00:01", DisplayName: "Radiology PC", NameSource: "custom", IP: "172.16.0.10", Kind: KindComputer, Online: true},
			"AA:AA:AA:00:00:02": {MAC: "AA:AA:AA:00:00:02", DisplayName: "172.16.0.11", NameSource: "ip", IP: "172.16.0.11", Kind: KindPhone},
		},
		notes: map[string]repository.ClientNote{"AA:AA:AA:00:00:01": {Place: "Radiology"}},
		scan:  &ScanSnapshot{TakenAt: day("2026-11-03"), Findings: []Finding{{Severity: "high"}, {Severity: "low"}}},
	}
}

func TestComposeUsageReportTotalsAndRanking(t *testing.T) {
	r := composeUsageReport(baseInputs())
	if r.Period.From != "2026-11-01" || r.Period.To != "2026-11-03" || r.Period.Days != 3 || len(r.Daily) != 3 {
		t.Fatalf("period = %+v daily=%d", r.Period, len(r.Daily))
	}
	if r.Totals.WANTotal != 10<<30 || r.Totals.AvgPerDay != (10<<30)/3 {
		t.Errorf("wan total %d avg %d", r.Totals.WANTotal, r.Totals.AvgPerDay)
	}
	if r.Totals.ActiveDevices != 3 || r.Totals.NewDevices != 2 || r.Totals.SeenDevices != 40 {
		t.Errorf("devices = %+v", r.Totals)
	}
	if r.Daily[2].DeviceDown != 0 || r.Daily[1].ActiveDevices != 4 {
		t.Errorf("daily = %+v", r.Daily)
	}
	if c := r.Compare.WANChangePct; c == nil || int(*c) != 100 {
		t.Errorf("wan change = %v", c)
	}
	if len(r.Hourly) != 24 || r.Hourly[11].Down != 5<<30 || r.Hourly[0].Down != 0 {
		t.Errorf("hourly wrong: %+v", r.Hourly[11])
	}
	top := r.TopDevices
	if len(top) != 3 || top[0].Name != "Radiology PC" || top[0].Place != "Radiology" || top[0].Rank != 1 || !top[0].Online {
		t.Fatalf("top = %+v", top)
	}
	if top[2].Name != "AA:AA:AA:00:00:09" {
		t.Errorf("device that is no longer listed keeps its MAC as the name: %+v", top[2])
	}
	var share float64
	for _, d := range top {
		share += d.SharePct
	}
	if share < 99.9 || share > 100.1 {
		t.Errorf("shares add up to %.2f", share)
	}
	if len(r.ByKind) != 3 || r.ByKind[0].Key != KindComputer {
		t.Errorf("by kind = %+v", r.ByKind)
	}
	if len(r.ByPlace) != 2 || r.ByPlace[0].Key != "Radiology" || r.ByPlace[1].Key != "Not set" || r.ByPlace[1].Devices != 2 {
		t.Errorf("by place = %+v", r.ByPlace)
	}
	if r.Alerts.Total != 3 || r.Alerts.Open != 2 || r.Alerts.BySeverity["high"] != 2 {
		t.Errorf("alerts = %+v", r.Alerts)
	}
	if r.Security == nil || r.Security.Findings != 2 || r.Security.BySeverity["high"] != 1 {
		t.Errorf("security = %+v", r.Security)
	}
	if r.Coverage.NoData || r.Coverage.Partial {
		t.Errorf("coverage = %+v", r.Coverage)
	}
}

func TestComposeUsageReportInsights(t *testing.T) {
	r := composeUsageReport(baseInputs())
	var all []string
	for _, i := range r.Insights {
		all = append(all, i.Text)
	}
	text := strings.Join(all, "\n")
	for _, want := range []string{"up 100%", "busiest day", "11:00 to 12:00", "Radiology PC used", "have no name", "still open", "high-severity"} {
		if !strings.Contains(text, want) {
			t.Errorf("missing insight %q in:\n%s", want, text)
		}
	}
}

func TestComposeUsageReportNoDataAndPartial(t *testing.T) {
	empty := usageInputs{from: day("2026-11-01"), to: day("2026-11-02"), prevFrom: day("2026-10-31"), prevTo: day("2026-11-01"), now: day("2026-11-02"), deviceLimit: 15}
	r := composeUsageReport(empty)
	if !r.Coverage.NoData || !strings.Contains(r.Coverage.Note, "Nothing has been measured") || len(r.Insights) != 0 || len(r.Daily) != 1 {
		t.Errorf("empty = %+v", r.Coverage)
	}
	if r.Totals.CoveragePct != nil || r.Compare.WANChangePct != nil {
		t.Error("no percentages without data")
	}

	in := baseInputs()
	in.firstWAN, in.firstUsage = day("2026-11-02"), day("2026-11-02")
	r = composeUsageReport(in)
	if !r.Coverage.Partial || !strings.Contains(r.Coverage.Note, "2 Nov 2026") {
		t.Errorf("partial = %+v", r.Coverage)
	}
}

func TestComposeUsageReportProjectionOnlyForARunningMonth(t *testing.T) {
	in := baseInputs()
	in.from, in.to = day("2026-11-01"), day("2026-12-01")
	in.now = day("2026-11-11")
	in.wan = repository.WANTotals{Down: 10 << 30}
	r := composeUsageReport(in)
	if r.Projection == nil || r.Projection.DaysElapsed != 10 || r.Projection.DaysInMonth != 30 || r.Projection.ProjectedBytes != 30<<30 {
		t.Fatalf("projection = %+v", r.Projection)
	}
	in.now = day("2026-12-05")
	if composeUsageReport(in).Projection != nil {
		t.Error("a finished month needs no projection")
	}
}

func TestUsageCSV(t *testing.T) {
	in := baseInputs()
	in.clients["AA:AA:AA:00:00:02"] = ClientView{MAC: "AA:AA:AA:00:00:02", DisplayName: `=HYPERLINK("x")`, NameSource: "hostname", Kind: KindPhone}
	r := composeUsageReport(in)
	out := string(usageCSV(r, ExportDevices))
	if !strings.HasPrefix(out, "\xef\xbb\xbf") || !strings.Contains(out, "Radiology PC,computer,172.16.0.10") {
		t.Errorf("devices csv:\n%s", out)
	}
	if strings.Contains(out, ",=HYPERLINK") || strings.Contains(out, `,"=HYPERLINK`) || !strings.Contains(out, "'=HYPERLINK") {
		t.Errorf("a name starting with = must not become a formula:\n%s", out)
	}
	if lines := strings.Count(strings.TrimSpace(string(usageCSV(r, ExportDaily))), "\n"); lines != 3 {
		t.Errorf("daily csv has %d data rows", lines)
	}
	if lines := strings.Count(strings.TrimSpace(string(usageCSV(r, ExportHourly))), "\n"); lines != 24 {
		t.Errorf("hourly csv has %d data rows", lines)
	}
	if !strings.Contains(string(usageCSV(r, ExportPlaces)), "Not set") || !strings.Contains(string(usageCSV(r, ExportKinds)), "computer") {
		t.Error("kinds/places csv incomplete")
	}
}

func TestHumanBytes(t *testing.T) {
	cases := map[int64]string{0: "0 B", 999: "999 B", 1500: "1.5 KB", 5_000_000_000: "5.0 GB", 150_000_000: "150 MB"}
	for in, want := range cases {
		if got := HumanBytes(in); got != want {
			t.Errorf("HumanBytes(%d)=%q want %q", in, got, want)
		}
	}
}
