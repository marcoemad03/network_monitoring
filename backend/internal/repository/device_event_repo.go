package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type DeviceEventRepository struct {
	db *database.DB
}

func NewDeviceEventRepository(db *database.DB) *DeviceEventRepository {
	return &DeviceEventRepository{db: db}
}

func (r *DeviceEventRepository) CreateEvent(ctx context.Context, event *models.DeviceEvent) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_events (id, organization_id, device_id, event_type, event_data, previous_value, new_value, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())`,
		event.ID, event.OrganizationID, event.DeviceID, event.EventType, event.EventData, event.PreviousValue, event.NewValue)
	return err
}

func (r *DeviceEventRepository) ListEvents(ctx context.Context, orgID, deviceID uuid.UUID, eventType string, from, to time.Time, limit, offset int) ([]models.DeviceEvent, int, error) {
	var whereClause string
	var args []interface{}
	argIdx := 1

	whereClause = "WHERE organization_id = $" + itoa(argIdx)
	args = append(args, orgID)
	argIdx++

	if deviceID != uuid.Nil {
		whereClause += " AND device_id = $" + itoa(argIdx)
		args = append(args, deviceID)
		argIdx++
	}

	if eventType != "" {
		whereClause += " AND event_type = $" + itoa(argIdx)
		args = append(args, eventType)
		argIdx++
	}

	if !from.IsZero() {
		whereClause += " AND created_at >= $" + itoa(argIdx)
		args = append(args, from)
		argIdx++
	}
	if !to.IsZero() {
		whereClause += " AND created_at <= $" + itoa(argIdx)
		args = append(args, to)
		argIdx++
	}

	var total int
	countQuery := "SELECT COUNT(*) FROM device_events " + whereClause
	if err := r.db.QueryRow(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, err
	}

	query := "SELECT id, organization_id, device_id, event_type, event_data, previous_value, new_value, created_at FROM device_events " +
		whereClause + " ORDER BY created_at DESC LIMIT $" + itoa(argIdx) + " OFFSET $" + itoa(argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	var events []models.DeviceEvent
	for rows.Next() {
		var e models.DeviceEvent
		if err := rows.Scan(&e.ID, &e.OrganizationID, &e.DeviceID, &e.EventType, &e.EventData, &e.PreviousValue, &e.NewValue, &e.CreatedAt); err != nil {
			return nil, 0, err
		}
		events = append(events, e)
	}
	return events, total, nil
}

func (r *DeviceEventRepository) GetEventSummary(ctx context.Context, orgID, deviceID uuid.UUID) (*models.DeviceEventSummary, error) {
	var args []interface{}
	whereClause := "WHERE organization_id = $1"
	args = append(args, orgID)

	if deviceID != uuid.Nil {
		whereClause += " AND device_id = $2"
		args = append(args, deviceID)
	}

	summary := &models.DeviceEventSummary{}

	row := r.db.QueryRow(ctx, "SELECT COUNT(*) FROM device_events "+whereClause, args...)
	row.Scan(&summary.TotalEvents)

	rows, err := r.db.Query(ctx,
		"SELECT event_type, COUNT(*) as cnt FROM device_events "+whereClause+" GROUP BY event_type ORDER BY cnt DESC", args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	summary.ByType = make(map[string]int)
	for rows.Next() {
		var eType string
		var count int
		rows.Scan(&eType, &count)
		summary.ByType[eType] = count
	}

	if deviceID != uuid.Nil {
		r.db.QueryRow(ctx,
			"SELECT MIN(created_at) FROM device_events "+whereClause, args...).Scan(&summary.FirstEvent)
		r.db.QueryRow(ctx,
			"SELECT MAX(created_at) FROM device_events "+whereClause, args...).Scan(&summary.LastEvent)
	}

	return summary, nil
}

func (r *DeviceEventRepository) DeleteOldEvents(ctx context.Context, before time.Time) (int64, error) {
	result, err := r.db.Exec(ctx, "DELETE FROM device_events WHERE created_at < $1", before)
	if err != nil {
		return 0, err
	}
	return result.RowsAffected(), nil
}

func itoa(i int) string {
	return fmt.Sprintf("%d", i)
}
