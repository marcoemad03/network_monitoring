package repository

import (
	"context"
	"encoding/json"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

type HotspotWelcomeRepository struct {
	db *database.DB
}

func NewHotspotWelcomeRepository(db *database.DB) *HotspotWelcomeRepository {
	return &HotspotWelcomeRepository{db: db}
}

func (r *HotspotWelcomeRepository) Get(ctx context.Context, orgID uuid.UUID) (*models.HotspotWelcomeConfig, error) {
	var config models.HotspotWelcomeConfig
	var announcements []byte
	err := r.db.QueryRow(ctx, `SELECT organization_id, hospital_name, logo_url, primary_color, accent_color, welcome_message, announcements, enabled, created_at, updated_at FROM hotspot_welcome_configs WHERE organization_id=$1`, orgID).Scan(
		&config.OrganizationID, &config.HospitalName, &config.LogoURL, &config.PrimaryColor, &config.AccentColor, &config.WelcomeMessage, &announcements, &config.Enabled, &config.CreatedAt, &config.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(announcements, &config.Announcements); err != nil {
		return nil, err
	}
	return &config, nil
}

func (r *HotspotWelcomeRepository) Upsert(ctx context.Context, config *models.HotspotWelcomeConfig) error {
	announcements, err := json.Marshal(config.Announcements)
	if err != nil {
		return err
	}
	return r.db.QueryRow(ctx, `INSERT INTO hotspot_welcome_configs (organization_id, hospital_name, logo_url, primary_color, accent_color, welcome_message, announcements, enabled)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		ON CONFLICT (organization_id) DO UPDATE SET hospital_name=EXCLUDED.hospital_name, logo_url=EXCLUDED.logo_url, primary_color=EXCLUDED.primary_color, accent_color=EXCLUDED.accent_color, welcome_message=EXCLUDED.welcome_message, announcements=EXCLUDED.announcements, enabled=EXCLUDED.enabled, updated_at=NOW()
		RETURNING created_at, updated_at`, config.OrganizationID, config.HospitalName, config.LogoURL, config.PrimaryColor, config.AccentColor, config.WelcomeMessage, announcements, config.Enabled).Scan(&config.CreatedAt, &config.UpdatedAt)
}

func IsHotspotWelcomeNotFound(err error) bool {
	return err == pgx.ErrNoRows
}
