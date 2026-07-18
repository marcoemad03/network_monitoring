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
	query := `SELECT * FROM network_scans WHERE id = $1`
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
		`SELECT * FROM network_scans WHERE organization_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
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
