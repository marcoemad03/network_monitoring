package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/jackc/pgx/v5"
)

// WANRepository stores and aggregates the router's WAN interface samples.
type WANRepository struct {
	db *database.DB
}

func NewWANRepository(db *database.DB) *WANRepository {
	return &WANRepository{db: db}
}

// WANSample is one measurement of the WAN interface.
type WANSample struct {
	Interface    string
	SampledAt    time.Time
	RxCounter    int64
	TxCounter    int64
	RxBytesDelta int64
	TxBytesDelta int64
	RxBps        int64
	TxBps        int64
}

// WANUsage is a total over a time range. Rx is traffic received from the
// internet (download), Tx is traffic sent to it (upload).
type WANUsage struct {
	RxBytes int64 `json:"download_bytes"`
	TxBytes int64 `json:"upload_bytes"`
	PeakRx  int64 `json:"peak_download_bps"`
	PeakTx  int64 `json:"peak_upload_bps"`
}

// WANPoint is a time bucket of the history chart.
type WANPoint struct {
	At    time.Time `json:"at"`
	RxBps int64     `json:"download_bps"`
	TxBps int64     `json:"upload_bps"`
}

// WANDay is the traffic of one calendar day.
type WANDay struct {
	Day     time.Time `json:"day"`
	RxBytes int64     `json:"download_bytes"`
	TxBytes int64     `json:"upload_bytes"`
}

func (r *WANRepository) Insert(ctx context.Context, orgID uuid.UUID, s WANSample) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO wan_usage_samples
		   (organization_id, interface_name, sampled_at, rx_counter, tx_counter, rx_bytes_delta, tx_bytes_delta, rx_bps, tx_bps)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		orgID, s.Interface, s.SampledAt, s.RxCounter, s.TxCounter, s.RxBytesDelta, s.TxBytesDelta, s.RxBps, s.TxBps)
	return err
}

// Last returns the newest sample of the interface, or nil when there is none.
func (r *WANRepository) Last(ctx context.Context, orgID uuid.UUID, iface string) (*WANSample, error) {
	var s WANSample
	err := r.db.QueryRow(ctx,
		`SELECT interface_name, sampled_at, rx_counter, tx_counter, rx_bytes_delta, tx_bytes_delta, rx_bps, tx_bps
		   FROM wan_usage_samples
		  WHERE organization_id = $1 AND interface_name = $2
		  ORDER BY sampled_at DESC LIMIT 1`, orgID, iface).
		Scan(&s.Interface, &s.SampledAt, &s.RxCounter, &s.TxCounter, &s.RxBytesDelta, &s.TxBytesDelta, &s.RxBps, &s.TxBps)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &s, nil
}

// Usage totals the bytes moved since the given time.
func (r *WANRepository) Usage(ctx context.Context, orgID uuid.UUID, since time.Time) (WANUsage, error) {
	var u WANUsage
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(rx_bytes_delta),0), COALESCE(SUM(tx_bytes_delta),0),
		        COALESCE(MAX(rx_bps),0), COALESCE(MAX(tx_bps),0)
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2`, orgID, since).
		Scan(&u.RxBytes, &u.TxBytes, &u.PeakRx, &u.PeakTx)
	return u, err
}

// History returns the average speed per minute since the given time.
func (r *WANRepository) History(ctx context.Context, orgID uuid.UUID, since time.Time) ([]WANPoint, error) {
	rows, err := r.db.Query(ctx,
		`SELECT date_trunc('minute', sampled_at) AS t, AVG(rx_bps)::bigint, AVG(tx_bps)::bigint
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2
		  GROUP BY t ORDER BY t`, orgID, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	points := []WANPoint{}
	for rows.Next() {
		var p WANPoint
		if err := rows.Scan(&p.At, &p.RxBps, &p.TxBps); err != nil {
			return nil, err
		}
		points = append(points, p)
	}
	return points, rows.Err()
}

// Daily returns the traffic per calendar day since the given time.
func (r *WANRepository) Daily(ctx context.Context, orgID uuid.UUID, since time.Time) ([]WANDay, error) {
	rows, err := r.db.Query(ctx,
		`SELECT date_trunc('day', sampled_at) AS d, SUM(rx_bytes_delta), SUM(tx_bytes_delta)
		   FROM wan_usage_samples WHERE organization_id = $1 AND sampled_at >= $2
		  GROUP BY d ORDER BY d`, orgID, since)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	days := []WANDay{}
	for rows.Next() {
		var d WANDay
		if err := rows.Scan(&d.Day, &d.RxBytes, &d.TxBytes); err != nil {
			return nil, err
		}
		days = append(days, d)
	}
	return days, rows.Err()
}

// OrgsWithRouter lists organizations that have an active MikroTik integration.
func (r *WANRepository) OrgsWithRouter(ctx context.Context) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx,
		`SELECT DISTINCT org_id FROM vendor_integrations WHERE vendor_type = 'mikrotik' AND is_active = true`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// Prune deletes samples older than the retention window.
func (r *WANRepository) Prune(ctx context.Context, before time.Time) error {
	_, err := r.db.Exec(ctx, `DELETE FROM wan_usage_samples WHERE sampled_at < $1`, before)
	return err
}

// FirstSampleAt returns when measuring started, or the zero time when it has not.
func (r *WANRepository) FirstSampleAt(ctx context.Context, orgID uuid.UUID) (time.Time, error) {
	var t *time.Time
	if err := r.db.QueryRow(ctx, `SELECT MIN(sampled_at) FROM wan_usage_samples WHERE organization_id = $1`, orgID).Scan(&t); err != nil {
		return time.Time{}, err
	}
	if t == nil {
		return time.Time{}, nil
	}
	return *t, nil
}
