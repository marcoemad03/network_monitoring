package services

import (
	"bytes"
	"context"
	"encoding/csv"
	"fmt"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Export views the report can be saved as.
const (
	ExportDevices = "devices"
	ExportDaily   = "daily"
	ExportHourly  = "hourly"
	ExportKinds   = "kinds"
	ExportPlaces  = "places"
)

// ExportUsageCSV writes one view of the report as a CSV file that Excel opens
// correctly, including Arabic names. It returns the file name and the bytes.
func (s *UsageReportService) ExportUsageCSV(ctx context.Context, orgID uuid.UUID, from, to time.Time, view string) (string, []byte, error) {
	switch view {
	case ExportDevices, ExportDaily, ExportHourly, ExportKinds, ExportPlaces:
	default:
		return "", nil, &ReportRangeError{"Unknown export. Choose devices, daily, hourly, kinds or places."}
	}
	limit := topDevicesShown
	if view == ExportDevices {
		limit = 1 << 30
	}
	r, err := s.build(ctx, orgID, from, to, limit)
	if err != nil {
		return "", nil, err
	}
	name := fmt.Sprintf("usage-%s-%s-to-%s.csv", view, r.Period.From, r.Period.To)
	return name, usageCSV(r, view), nil
}

func usageCSV(r *UsageReport, view string) []byte {
	var buf bytes.Buffer
	buf.WriteString("\xef\xbb\xbf") // byte order mark so Excel reads UTF-8
	w := csv.NewWriter(&buf)
	n := func(v int64) string { return strconv.FormatInt(v, 10) }
	pct := func(v float64) string { return strconv.FormatFloat(v, 'f', 1, 64) }
	switch view {
	case ExportDevices:
		_ = w.Write([]string{"Rank", "Name", "Type", "IP address", "MAC address", "Place", "Download (bytes)", "Upload (bytes)", "Total (bytes)", "Total", "Share of device traffic (%)", "Days active"})
		for _, d := range r.TopDevices {
			_ = w.Write([]string{strconv.Itoa(d.Rank), safeCell(d.Name), d.Kind, d.IP, d.MAC, safeCell(d.Place), n(d.Down), n(d.Up), n(d.Total), HumanBytes(d.Total), pct(d.SharePct), strconv.Itoa(d.ActiveDays)})
		}
	case ExportDaily:
		_ = w.Write([]string{"Date", "Internet download (bytes)", "Internet upload (bytes)", "Internet total (bytes)", "Devices download (bytes)", "Devices upload (bytes)", "Active devices"})
		for _, d := range r.Daily {
			_ = w.Write([]string{d.Day, n(d.WANDown), n(d.WANUp), n(d.WANDown + d.WANUp), n(d.DeviceDown), n(d.DeviceUp), strconv.Itoa(d.ActiveDevices)})
		}
	case ExportHourly:
		_ = w.Write([]string{"Hour", "Internet download (bytes)", "Internet upload (bytes)", "Average speed (bits per second)"})
		for _, h := range r.Hourly {
			_ = w.Write([]string{fmt.Sprintf("%02d:00", h.Hour), n(h.Down), n(h.Up), n(h.AvgBps)})
		}
	case ExportKinds, ExportPlaces:
		label := "Type"
		rows := r.ByKind
		if view == ExportPlaces {
			label, rows = "Place", r.ByPlace
		}
		_ = w.Write([]string{label, "Devices", "Download (bytes)", "Upload (bytes)", "Total (bytes)", "Total", "Share of device traffic (%)"})
		for _, g := range rows {
			_ = w.Write([]string{safeCell(g.Key), strconv.Itoa(g.Devices), n(g.Down), n(g.Up), n(g.Total), HumanBytes(g.Total), pct(g.SharePct)})
		}
	}
	w.Flush()
	return buf.Bytes()
}

// safeCell stops a spreadsheet from running a device name as a formula: names come
// from the devices themselves.
func safeCell(v string) string {
	v = strings.TrimSpace(v)
	if v != "" && strings.ContainsRune("=+-@\t\r", rune(v[0])) {
		return "'" + v
	}
	return v
}
