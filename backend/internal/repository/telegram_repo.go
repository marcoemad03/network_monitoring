package repository

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

type TelegramRepository struct {
	db *database.DB
}

func NewTelegramRepository(db *database.DB) *TelegramRepository {
	return &TelegramRepository{db: db}
}

func (r *TelegramRepository) GetConfig(ctx context.Context, orgID uuid.UUID) (*models.TelegramConfig, error) {
	var cfg models.TelegramConfig
	err := r.db.QueryRow(ctx, `
		SELECT organization_id, bot_token, chat_id, grace_period_minutes,
		       once_per_day, notify_connect, notify_disconnect, notify_new_device,
		       notify_policy_violation, enabled, created_at, updated_at
		FROM telegram_configs WHERE organization_id=$1`, orgID).Scan(
		&cfg.OrganizationID, &cfg.BotToken, &cfg.ChatID, &cfg.GracePeriodMinutes,
		&cfg.OncePerDay, &cfg.NotifyConnect, &cfg.NotifyDisconnect, &cfg.NotifyNewDevice,
		&cfg.NotifyPolicyViolation, &cfg.Enabled, &cfg.CreatedAt, &cfg.UpdatedAt,
	)
	if err == pgx.ErrNoRows {
		return nil, nil
	}
	return &cfg, err
}

func (r *TelegramRepository) UpsertConfig(ctx context.Context, cfg *models.TelegramConfig) error {
	return r.db.QueryRow(ctx, `
		INSERT INTO telegram_configs (organization_id, bot_token, chat_id, grace_period_minutes,
		       once_per_day, notify_connect, notify_disconnect, notify_new_device,
		       notify_policy_violation, enabled)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		ON CONFLICT (organization_id) DO UPDATE SET
		       bot_token=EXCLUDED.bot_token, chat_id=EXCLUDED.chat_id,
		       grace_period_minutes=EXCLUDED.grace_period_minutes,
		       once_per_day=EXCLUDED.once_per_day,
		       notify_connect=EXCLUDED.notify_connect,
		       notify_disconnect=EXCLUDED.notify_disconnect,
		       notify_new_device=EXCLUDED.notify_new_device,
		       notify_policy_violation=EXCLUDED.notify_policy_violation,
		       enabled=EXCLUDED.enabled, updated_at=NOW()
		RETURNING created_at, updated_at`,
		cfg.OrganizationID, cfg.BotToken, cfg.ChatID, cfg.GracePeriodMinutes,
		cfg.OncePerDay, cfg.NotifyConnect, cfg.NotifyDisconnect, cfg.NotifyNewDevice,
		cfg.NotifyPolicyViolation, cfg.Enabled,
	).Scan(&cfg.CreatedAt, &cfg.UpdatedAt)
}

func (r *TelegramRepository) HasSentToday(ctx context.Context, orgID uuid.UUID, eventType, deviceMAC string, dayDate time.Time) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM telegram_notification_history
		WHERE organization_id=$1 AND event_type=$2 AND device_mac=$3 AND day_date=$4`,
		orgID, eventType, deviceMAC, dayDate).Scan(&count)
	return count > 0, err
}

func (r *TelegramRepository) HasRecentEvent(ctx context.Context, orgID uuid.UUID, eventType, deviceMAC string, within time.Duration) (bool, error) {
	var count int
	err := r.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM telegram_notification_history
		WHERE organization_id=$1 AND event_type=$2 AND device_mac=$3
		AND sent_at > NOW() - $4::interval`,
		orgID, eventType, deviceMAC, within.String()).Scan(&count)
	return count > 0, err
}

func (r *TelegramRepository) InsertHistory(ctx context.Context, h *models.TelegramNotificationHistory) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO telegram_notification_history (id, organization_id, device_mac, device_name,
		       ip_address, access_point, event_type, sent_at, day_date)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		h.ID, h.OrganizationID, h.DeviceMAC, h.DeviceName,
		h.IPAddress, h.AccessPoint, h.EventType, h.SentAt, h.DayDate)
	return err
}

func (r *TelegramRepository) CleanupOldHistory(ctx context.Context, orgID uuid.UUID, before time.Time) error {
	_, err := r.db.Exec(ctx, `
		DELETE FROM telegram_notification_history
		WHERE organization_id=$1 AND sent_at < $2`, orgID, before)
	return err
}
