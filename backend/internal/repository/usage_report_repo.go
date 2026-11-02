package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
)

// UsageReportRepository answers the questions the Reports page asks of the data
// the NMS already records: WAN counters, per-device daily usage, alerts, events.
// Ranges are [from, to): from is the first instant included, to the first excluded.
type UsageReportRepository struct {
	db *database.DB
}

func NewUsageReportRepository(db *database.DB) *UsageReportRepository {
	return &UsageReportRepository{db: db}
}

// DayTotals is one calendar day of traffic.
type DayTotals struct {
	Day         time.Time
	WANDown     int64
	WANUp       int64
	ClientDown  int64
	ClientUp    int64
	ActiveCount int
}

// WANTotals is the internet traffic of a range.
type WANTotals struct {
	Down, Up      int64
	PeakDownBps   int64
	PeakUpBps     int64
	Samples       int64
	FirstSampleAt *time.Time
	LastSampleAt  *time.Time
}

// WANRange totals the WAN counters in a range.
func (r *UsageReportRepository) WANRange(ctx context.Context, orgID uuid.UUID, from, to time.Time) (WANTotals, error) {
	var t WANTotals
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(rx_bytes_delta),0), COALESCE(SUM(tx_bytes_delta),0),
		        COALESCE(MAX(rx_bps),0), COALESCE(MAX(tx_bps),0), COUNT(*), MIN(sampled_at), MAX(sampled_at)
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2 AND sampled_at < $3`,
		orgID, from, to).Scan(&t.Down, &t.Up, &t.PeakDownBps, &t.PeakUpBps, &t.Samples, &t.FirstSampleAt, &t.LastSampleAt)
	return t, err
}

// WANDaily returns the WAN traffic per calendar day in a range.
func (r *UsageReportRepository) WANDaily(ctx context.Context, orgID uuid.UUID, from, to time.Time) (map[string][2]int64, error) {
	rows, err := r.db.Query(ctx,
		`SELECT to_char(sampled_at, 'YYYY-MM-DD'), SUM(rx_bytes_delta), SUM(tx_bytes_delta)
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2 AND sampled_at < $3
		  GROUP BY 1`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string][2]int64{}
	for rows.Next() {
		var day string
		var down, up int64
		if err := rows.Scan(&day, &down, &up); err != nil {
			return nil, err
		}
		out[day] = [2]int64{down, up}
	}
	return out, rows.Err()
}

// HourOfDay is the WAN traffic of one hour of the day, summed over the range.
type HourOfDay struct {
	Hour  int
	Down  int64
	Up    int64
	AvgBp int64 // average speed in bits per second while measured
}

// WANHourly sums the WAN traffic by hour of the day (0-23) over a range.
func (r *UsageReportRepository) WANHourly(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]HourOfDay, error) {
	rows, err := r.db.Query(ctx,
		`SELECT EXTRACT(HOUR FROM sampled_at)::int, SUM(rx_bytes_delta), SUM(tx_bytes_delta),
		        AVG(rx_bps + tx_bps)::bigint
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2 AND sampled_at < $3
		  GROUP BY 1 ORDER BY 1`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []HourOfDay
	for rows.Next() {
		var h HourOfDay
		if err := rows.Scan(&h.Hour, &h.Down, &h.Up, &h.AvgBp); err != nil {
			return nil, err
		}
		out = append(out, h)
	}
	return out, rows.Err()
}

// ClientDaily returns, per day, what the devices moved and how many were active.
func (r *UsageReportRepository) ClientDaily(ctx context.Context, orgID uuid.UUID, from, to time.Time) (map[string]DayTotals, error) {
	rows, err := r.db.Query(ctx,
		`SELECT to_char(day, 'YYYY-MM-DD'), COALESCE(SUM(download_bytes),0), COALESCE(SUM(upload_bytes),0),
		        COUNT(*) FILTER (WHERE download_bytes + upload_bytes > 0)
		   FROM client_usage_daily WHERE organization_id = $1 AND day >= $2::date AND day < $3::date
		  GROUP BY 1`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]DayTotals{}
	for rows.Next() {
		var day string
		var d DayTotals
		if err := rows.Scan(&day, &d.ClientDown, &d.ClientUp, &d.ActiveCount); err != nil {
			return nil, err
		}
		out[day] = d
	}
	return out, rows.Err()
}

// DeviceUsage is what one device moved in a range.
type DeviceUsage struct {
	MAC        string
	Down, Up   int64
	ActiveDays int
}

// ClientUsage returns every device's usage in a range, biggest first.
func (r *UsageReportRepository) ClientUsage(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]DeviceUsage, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, SUM(download_bytes), SUM(upload_bytes), COUNT(*) FILTER (WHERE download_bytes + upload_bytes > 0)
		   FROM client_usage_daily WHERE organization_id = $1 AND day >= $2::date AND day < $3::date
		  GROUP BY mac HAVING SUM(download_bytes) + SUM(upload_bytes) > 0
		  ORDER BY SUM(download_bytes) + SUM(upload_bytes) DESC`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []DeviceUsage
	for rows.Next() {
		var u DeviceUsage
		if err := rows.Scan(&u.MAC, &u.Down, &u.Up, &u.ActiveDays); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}

// FirstUsageDay returns the first day device usage was recorded (zero if never).
func (r *UsageReportRepository) FirstUsageDay(ctx context.Context, orgID uuid.UUID) (time.Time, error) {
	var t *time.Time
	if err := r.db.QueryRow(ctx, `SELECT MIN(day)::timestamptz FROM client_usage_daily WHERE organization_id = $1`, orgID).Scan(&t); err != nil {
		return time.Time{}, err
	}
	if t == nil {
		return time.Time{}, nil
	}
	return *t, nil
}

// DeviceCounts counts the devices first seen and seen at all in a range.
func (r *UsageReportRepository) DeviceCounts(ctx context.Context, orgID uuid.UUID, from, to time.Time) (newDevices, seen int, err error) {
	err = r.db.QueryRow(ctx,
		`SELECT COUNT(*) FILTER (WHERE first_seen >= $2 AND first_seen < $3),
		        COUNT(*) FILTER (WHERE last_seen >= $2)
		   FROM client_devices WHERE organization_id = $1 AND first_seen < $3`, orgID, from, to).Scan(&newDevices, &seen)
	return
}

// AlertCount is the number of alerts of one severity and status in a range.
type AlertCount struct {
	Severity string
	Status   string
	Count    int
}

// Alerts groups the alerts raised in a range by severity and status.
func (r *UsageReportRepository) Alerts(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]AlertCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT severity::text, status::text, COUNT(*) FROM alerts
		  WHERE organization_id = $1 AND detected_at >= $2 AND detected_at < $3
		  GROUP BY 1, 2 ORDER BY 1, 2`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []AlertCount
	for rows.Next() {
		var a AlertCount
		if err := rows.Scan(&a.Severity, &a.Status, &a.Count); err != nil {
			return nil, err
		}
		out = append(out, a)
	}
	return out, rows.Err()
}

// EventCount is the number of device events of one type in a range.
type EventCount struct {
	Type  string
	Count int
}

// Events groups the device events recorded in a range by type.
func (r *UsageReportRepository) Events(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]EventCount, error) {
	rows, err := r.db.Query(ctx,
		`SELECT event_type, COUNT(*) FROM device_events
		  WHERE organization_id = $1 AND created_at >= $2 AND created_at < $3
		  GROUP BY 1 ORDER BY 2 DESC LIMIT 12`, orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []EventCount
	for rows.Next() {
		var e EventCount
		if err := rows.Scan(&e.Type, &e.Count); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// FirstWAN returns when internet measuring started (zero if it has not).
func (r *UsageReportRepository) FirstWAN(ctx context.Context, orgID uuid.UUID) (time.Time, error) {
	var t *time.Time
	if err := r.db.QueryRow(ctx, `SELECT MIN(sampled_at) FROM wan_usage_samples WHERE organization_id = $1`, orgID).Scan(&t); err != nil {
		return time.Time{}, err
	}
	if t == nil {
		return time.Time{}, nil
	}
	return *t, nil
}
