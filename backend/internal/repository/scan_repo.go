package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type ScanRepository struct {
	db *database.DB
}

func NewScanRepository(db *database.DB) *ScanRepository {
	return &ScanRepository{db: db}
}

func (r *ScanRepository) Create(ctx context.Context, s *models.NetworkScan) error {
	query := `INSERT INTO network_scans (id, organization_id, type, status, name, target_subnet, initiated_by, total_hosts, discovered_hosts, active_hosts, progress, started_at, created_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`
	_, err := r.db.Exec(ctx, query,
		s.ID, s.OrganizationID, s.Type, s.Status, s.Name, s.TargetSubnet,
		s.InitiatedBy, s.TotalHosts, s.DiscoveredHosts, s.ActiveHosts,
		s.Progress, s.StartedAt, s.CreatedAt,
	)
	return err
}

func (r *ScanRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.NetworkScan, error) {
	query := `SELECT id, organization_id, type, status, name, target_subnet::text, initiated_by, total_hosts, discovered_hosts, active_hosts, duration_seconds, progress, error_message, started_at, completed_at, created_at FROM network_scans WHERE id = $1`
	row := r.db.QueryRow(ctx, query, id)

	var s models.NetworkScan
	if err := row.Scan(
		&s.ID, &s.OrganizationID, &s.Type, &s.Status, &s.Name,
		&s.TargetSubnet, &s.InitiatedBy, &s.TotalHosts, &s.DiscoveredHosts,
		&s.ActiveHosts, &s.DurationSeconds, &s.Progress, &s.ErrorMessage,
		&s.StartedAt, &s.CompletedAt, &s.CreatedAt,
	); err != nil {
		return nil, fmt.Errorf("get scan by id: %w", err)
	}
	return &s, nil
}

func (r *ScanRepository) List(ctx context.Context, orgID uuid.UUID, page, limit int) ([]models.NetworkScan, int, error) {
	offset := (page - 1) * limit
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, type, status, name, target_subnet::text, initiated_by, total_hosts, discovered_hosts, active_hosts, duration_seconds, progress, error_message, started_at, completed_at, created_at FROM network_scans WHERE organization_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
		orgID, limit, offset,
	)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var scans []models.NetworkScan
	for rows.Next() {
		var s models.NetworkScan
		if err := rows.Scan(
			&s.ID, &s.OrganizationID, &s.Type, &s.Status, &s.Name,
			&s.TargetSubnet, &s.InitiatedBy, &s.TotalHosts, &s.DiscoveredHosts,
			&s.ActiveHosts, &s.DurationSeconds, &s.Progress, &s.ErrorMessage,
			&s.StartedAt, &s.CompletedAt, &s.CreatedAt,
		); err != nil {
			return nil, 0, err
		}
		scans = append(scans, s)
	}

	var total int
	r.db.QueryRow(ctx, `SELECT COUNT(*) FROM network_scans WHERE organization_id = $1`, orgID).Scan(&total)
	return scans, total, nil
}

func (r *ScanRepository) UpdateProgress(ctx context.Context, id uuid.UUID, progress float64, discovered, active int) error {
	_, err := r.db.Exec(ctx,
		`UPDATE network_scans SET progress=$1, discovered_hosts=$2, active_hosts=$3 WHERE id=$4`,
		progress, discovered, active, id,
	)
	return err
}

func (r *ScanRepository) Complete(ctx context.Context, id uuid.UUID, discovered, active int, duration int, summary string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE network_scans SET status='completed', discovered_hosts=$1, active_hosts=$2, duration_seconds=$3, progress=100, result_summary=$4, completed_at=NOW() WHERE id=$5`,
		discovered, active, duration, summary, id,
	)
	return err
}

func (r *ScanRepository) Fail(ctx context.Context, id uuid.UUID, errMsg string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE network_scans SET status='failed', error_message=$1, completed_at=NOW() WHERE id=$2`,
		errMsg, id,
	)
	return err
}

func (r *ScanRepository) CreateScanResult(ctx context.Context, sr *models.ScanResult) error {
	query := `INSERT INTO scan_results (id, scan_id, ip_address, hostname, mac_address, vendor, open_ports, os_guess, response_time_ms, is_alive, is_new_device, discovered_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`
	_, err := r.db.Exec(ctx, query,
		sr.ID, sr.ScanID, sr.IPAddress, sr.Hostname, sr.MACAddress,
		sr.Vendor, sr.OpenPorts, sr.OSGuess, sr.ResponseTimeMs,
		sr.IsAlive, sr.IsNewDevice, sr.DiscoveredAt,
	)
	return err
}

func (r *ScanRepository) ListScanResultsByScanID(ctx context.Context, scanID uuid.UUID) ([]models.ScanResult, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, scan_id, ip_address, hostname, mac_address, vendor, open_ports, os_guess, response_time_ms, is_alive, is_new_device, discovered_at FROM scan_results WHERE scan_id = $1 ORDER BY ip_address ASC`,
		scanID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []models.ScanResult
	for rows.Next() {
		var sr models.ScanResult
		if err := rows.Scan(
			&sr.ID, &sr.ScanID, &sr.IPAddress, &sr.Hostname, &sr.MACAddress,
			&sr.Vendor, &sr.OpenPorts, &sr.OSGuess, &sr.ResponseTimeMs,
			&sr.IsAlive, &sr.IsNewDevice, &sr.DiscoveredAt,
		); err != nil {
			return nil, err
		}
		results = append(results, sr)
	}
	return results, nil
}

func (r *ScanRepository) DeleteScanResultsByScanID(ctx context.Context, scanID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM scan_results WHERE scan_id = $1`, scanID)
	return err
}
