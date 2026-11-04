package repository

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
)

// AssetFingerprint is what a scan found out about a device.
type AssetFingerprint struct {
	IP           string    `json:"ip"`
	Kind         string    `json:"kind,omitempty"`
	Confidence   string    `json:"confidence,omitempty"`
	Reason       string    `json:"reason,omitempty"`
	Ports        []int     `json:"ports,omitempty"`
	Model        string    `json:"model,omitempty"`
	Serial       string    `json:"serial,omitempty"`
	SysName      string    `json:"sys_name,omitempty"`
	SysDescr     string    `json:"sys_descr,omitempty"`
	PageCount    *int64    `json:"page_count,omitempty"`
	TonerPercent *int      `json:"toner_percent,omitempty"`
	ScannedAt    time.Time `json:"scanned_at"`
}

type AssetInventoryRepository struct {
	db *database.DB
}

func NewAssetInventoryRepository(db *database.DB) *AssetInventoryRepository {
	return &AssetInventoryRepository{db: db}
}

// Fingerprints returns the last scan result of every device, by device key.
func (r *AssetInventoryRepository) Fingerprints(ctx context.Context, orgID uuid.UUID) (map[string]AssetFingerprint, error) {
	rows, err := r.db.Query(ctx, `SELECT device_key, data FROM asset_fingerprints WHERE organization_id = $1`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := map[string]AssetFingerprint{}
	for rows.Next() {
		var key string
		var data []byte
		if err := rows.Scan(&key, &data); err != nil {
			return nil, err
		}
		var f AssetFingerprint
		if json.Unmarshal(data, &f) == nil {
			out[key] = f
		}
	}
	return out, rows.Err()
}

// SaveFingerprint stores a device's scan result.
func (r *AssetInventoryRepository) SaveFingerprint(ctx context.Context, orgID uuid.UUID, key string, f AssetFingerprint) error {
	data, err := json.Marshal(f)
	if err != nil {
		return err
	}
	_, err = r.db.Exec(ctx, `INSERT INTO asset_fingerprints (organization_id, device_key, data, scanned_at)
		VALUES ($1, $2, $3::jsonb, $4)
		ON CONFLICT (organization_id, device_key) DO UPDATE SET data = EXCLUDED.data, scanned_at = EXCLUDED.scanned_at`,
		orgID, key, string(data), f.ScannedAt)
	return err
}
