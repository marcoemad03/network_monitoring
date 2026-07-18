package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type AlertRepository struct {
	db *database.DB
}

func NewAlertRepository(db *database.DB) *AlertRepository {
	return &AlertRepository{db: db}
}

func (r *AlertRepository) List(ctx context.Context, orgID uuid.UUID, page, limit int, status, severity, category, deviceID, sortBy string, ascending bool) ([]models.Alert, int, error) {
	offset := (page - 1) * limit
	query := `SELECT * FROM alerts WHERE organization_id = $1`
	countQuery := `SELECT COUNT(*) FROM alerts WHERE organization_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if status != "" {
		query += fmt.Sprintf(` AND status = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND status = $%d`, argIdx)
		args = append(args, status)
		argIdx++
	}
	if severity != "" {
		query += fmt.Sprintf(` AND severity = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND severity = $%d`, argIdx)
		args = append(args, severity)
		argIdx++
	}
	if category != "" {
		query += fmt.Sprintf(` AND category = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND category = $%d`, argIdx)
		args = append(args, category)
		argIdx++
	}
	if deviceID != "" {
		query += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		args = append(args, deviceID)
		argIdx++
	}

	orderDir := "DESC"
	if ascending {
		orderDir = "ASC"
	}
	validSorts := map[string]bool{"severity": true, "detected_at": true, "status": true, "created_at": true}
	if !validSorts[sortBy] {
		sortBy = "detected_at"
	}
	query += fmt.Sprintf(` ORDER BY %s %s LIMIT $%d OFFSET $%d`, sortBy, orderDir, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var alerts []models.Alert
	for rows.Next() {
		var a models.Alert
		if err := rows.Scan(
			&a.ID, &a.OrganizationID, &a.Title, &a.Description, &a.Severity,
			&a.Status, &a.Category, &a.DeviceID, &a.InterfaceID, &a.MetricName,
			&a.MetricValue, &a.ThresholdValue, &a.AcknowledgedBy, &a.AcknowledgedAt,
			&a.ResolvedBy, &a.ResolvedAt, &a.ResolutionNotes, &a.OccurrenceCount,
			&a.DetectedAt, &a.CreatedAt, &a.UpdatedAt,
		); err != nil {
			return nil, 0, err
		}
		alerts = append(alerts, a)
	}

	var total int
	if err := r.db.QueryRow(ctx, countQuery, args[:len(args)-2]...).Scan(&total); err != nil {
		return nil, 0, err
	}

	return alerts, total, nil
}

func (r *AlertRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Alert, error) {
	query := `SELECT * FROM alerts WHERE id = $1`
	row := r.db.QueryRow(ctx, query, id)

	var a models.Alert
	if err := row.Scan(
		&a.ID, &a.OrganizationID, &a.Title, &a.Description, &a.Severity,
		&a.Status, &a.Category, &a.DeviceID, &a.InterfaceID, &a.MetricName,
		&a.MetricValue, &a.ThresholdValue, &a.AcknowledgedBy, &a.AcknowledgedAt,
		&a.ResolvedBy, &a.ResolvedAt, &a.ResolutionNotes, &a.OccurrenceCount,
		&a.DetectedAt, &a.CreatedAt, &a.UpdatedAt,
	); err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *AlertRepository) Acknowledge(ctx context.Context, id, userID uuid.UUID, notes string) error {
	now := time.Now()
	_, err := r.db.Exec(ctx,
		`UPDATE alerts SET status='acknowledged', acknowledged_by=$1, acknowledged_at=$2, resolution_notes=$3, updated_at=NOW() WHERE id=$4`,
		userID, now, notes, id,
	)
	return err
}

func (r *AlertRepository) Resolve(ctx context.Context, id, userID uuid.UUID, resolutionNotes string) error {
	now := time.Now()
	_, err := r.db.Exec(ctx,
		`UPDATE alerts SET status='resolved', resolved_by=$1, resolved_at=$2, resolution_notes=$3, updated_at=NOW() WHERE id=$4`,
		userID, now, resolutionNotes, id,
	)
	return err
}

func (r *AlertRepository) Create(ctx context.Context, a *models.Alert) error {
	query := `INSERT INTO alerts (id, organization_id, title, description, severity, status, category, device_id, interface_id, metric_name, metric_value, threshold_value, occurrence_count, detected_at, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16)`
	_, err := r.db.Exec(ctx, query,
		a.ID, a.OrganizationID, a.Title, a.Description, a.Severity,
		a.Status, a.Category, a.DeviceID, a.InterfaceID, a.MetricName,
		a.MetricValue, a.ThresholdValue, a.OccurrenceCount, time.Now(), time.Now(), time.Now(),
	)
	return err
}
