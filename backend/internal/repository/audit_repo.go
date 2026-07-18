package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type AuditRepository struct {
	db *database.DB
}

func NewAuditRepository(db *database.DB) *AuditRepository {
	return &AuditRepository{db: db}
}

func (r *AuditRepository) Create(ctx context.Context, log *models.AuditLog) error {
	query := `INSERT INTO audit_logs (id, organization_id, action, entity_type, entity_id, entity_name, performed_by, ip_address, user_agent, previous_values, new_values, description, is_success, failure_reason, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15)`
	_, err := r.db.Exec(ctx, query,
		log.ID, log.OrganizationID, log.Action, log.EntityType, log.EntityID,
		log.EntityName, log.PerformedBy, log.IPAddress, log.UserAgent,
		log.PreviousValues, log.NewValues, log.Description, log.IsSuccess,
		log.FailureReason, log.Timestamp,
	)
	return err
}

func (r *AuditRepository) List(ctx context.Context, orgID uuid.UUID, page, limit int, action, entityType, performedBy string, from, to time.Time) ([]models.AuditLog, int, error) {
	offset := (page - 1) * limit
	query := `SELECT * FROM audit_logs WHERE organization_id = $1`
	countQuery := `SELECT COUNT(*) FROM audit_logs WHERE organization_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if action != "" {
		query += fmt.Sprintf(` AND action = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND action = $%d`, argIdx)
		args = append(args, action)
		argIdx++
	}
	if entityType != "" {
		query += fmt.Sprintf(` AND entity_type = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND entity_type = $%d`, argIdx)
		args = append(args, entityType)
		argIdx++
	}
	if performedBy != "" {
		query += fmt.Sprintf(` AND performed_by = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND performed_by = $%d`, argIdx)
		args = append(args, performedBy)
		argIdx++
	}
	if !from.IsZero() {
		query += fmt.Sprintf(` AND timestamp >= $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND timestamp >= $%d`, argIdx)
		args = append(args, from)
		argIdx++
	}
	if !to.IsZero() {
		query += fmt.Sprintf(` AND timestamp <= $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND timestamp <= $%d`, argIdx)
		args = append(args, to)
		argIdx++
	}

	query += fmt.Sprintf(` ORDER BY timestamp DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var logs []models.AuditLog
	for rows.Next() {
		var l models.AuditLog
		if err := rows.Scan(
			&l.ID, &l.OrganizationID, &l.Action, &l.EntityType, &l.EntityID,
			&l.EntityName, &l.PerformedBy, &l.IPAddress, &l.UserAgent,
			&l.PreviousValues, &l.NewValues, &l.Description, &l.IsSuccess,
			&l.FailureReason, &l.Timestamp,
		); err != nil {
			return nil, 0, err
		}
		logs = append(logs, l)
	}

	var total int
	if err := r.db.QueryRow(ctx, countQuery, args[:len(args)-2]...).Scan(&total); err != nil {
		return nil, 0, err
	}

	return logs, total, nil
}
