package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type MarcoRepository struct {
	db *database.DB
}

func NewMarcoRepository(db *database.DB) *MarcoRepository {
	return &MarcoRepository{db: db}
}

func (r *MarcoRepository) CreateGroup(ctx context.Context, g *models.MarcoGroup) error {
	policyJSON, err := json.Marshal(g.Policy)
	if err != nil {
		return fmt.Errorf("marshal policy: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`INSERT INTO marco_groups (id, organization_id, name, description, color, icon, policy) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		g.ID, g.OrganizationID, g.Name, g.Description, g.Color, g.Icon, policyJSON)
	return err
}

func (r *MarcoRepository) UpdateGroup(ctx context.Context, g *models.MarcoGroup) error {
	policyJSON, err := json.Marshal(g.Policy)
	if err != nil {
		return fmt.Errorf("marshal policy: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`UPDATE marco_groups SET name=$1, description=$2, color=$3, icon=$4, policy=$5, updated_at=NOW() WHERE id=$6 AND organization_id=$7`,
		g.Name, g.Description, g.Color, g.Icon, policyJSON, g.ID, g.OrganizationID)
	return err
}

func (r *MarcoRepository) UpdateGroupPolicy(ctx context.Context, orgID, id uuid.UUID, policy models.MarcoGroupPolicy) error {
	policyJSON, err := json.Marshal(policy)
	if err != nil {
		return fmt.Errorf("marshal policy: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`UPDATE marco_groups SET policy=$1, updated_at=NOW() WHERE id=$2 AND organization_id=$3`,
		policyJSON, id, orgID)
	return err
}

func (r *MarcoRepository) DeleteGroup(ctx context.Context, orgID, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM marco_groups WHERE id=$1 AND organization_id=$2`, id, orgID)
	return err
}

func (r *MarcoRepository) GetGroupByID(ctx context.Context, orgID, id uuid.UUID) (*models.MarcoGroup, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, organization_id, name, description, color, icon, policy, created_at, updated_at FROM marco_groups WHERE id=$1 AND organization_id=$2`, id, orgID)
	g, err := scanMarcoGroup(row)
	if err != nil {
		return nil, err
	}
	return g, nil
}

func (r *MarcoRepository) ListGroups(ctx context.Context, orgID uuid.UUID) ([]models.MarcoGroup, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, name, description, color, icon, policy, created_at, updated_at FROM marco_groups WHERE organization_id=$1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var groups []models.MarcoGroup
	for rows.Next() {
		var g models.MarcoGroup
		var policyJSON []byte
		if err := rows.Scan(&g.ID, &g.OrganizationID, &g.Name, &g.Description, &g.Color, &g.Icon, &policyJSON, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(policyJSON, &g.Policy); err != nil {
			return nil, fmt.Errorf("decode policy for group %s: %w", g.ID, err)
		}
		groups = append(groups, g)
	}
	return groups, rows.Err()
}

type scanRow interface {
	Scan(dest ...interface{}) error
}

// ListOrganizationIDs returns every organization that owns at least one Marco
// group (used by the quota background loop).
func (r *MarcoRepository) ListOrganizationIDs(ctx context.Context) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx, `SELECT DISTINCT organization_id FROM marco_groups`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var orgs []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		orgs = append(orgs, id)
	}
	return orgs, rows.Err()
}

func scanMarcoGroup(row scanRow) (*models.MarcoGroup, error) {
	var g models.MarcoGroup
	var policyJSON []byte
	if err := row.Scan(&g.ID, &g.OrganizationID, &g.Name, &g.Description, &g.Color, &g.Icon, &policyJSON, &g.CreatedAt, &g.UpdatedAt); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(policyJSON, &g.Policy); err != nil {
		return nil, fmt.Errorf("decode policy for group %s: %w", g.ID, err)
	}
	return &g, nil
}

const marcoMemberSelect = `
SELECT m.id, m.group_id, m.device_id, m.created_at,
       COALESCE(d.name,''), d.hostname, d.mac_address::text, d.ip_address,
       (d.status = 'online')
FROM marco_group_members m
JOIN devices d ON d.id = m.device_id
`

func (r *MarcoRepository) ListMembers(ctx context.Context, groupID uuid.UUID) ([]models.MarcoGroupMember, error) {
	rows, err := r.db.Query(ctx, marcoMemberSelect+` WHERE m.group_id=$1 ORDER BY d.name ASC`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanMembers(rows)
}

func (r *MarcoRepository) ListAllMembers(ctx context.Context, orgID uuid.UUID) ([]models.MarcoGroupMember, error) {
	rows, err := r.db.Query(ctx, marcoMemberSelect+` WHERE d.organization_id=$1`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanMembers(rows)
}

func scanMembers(rows interface {
	Next() bool
	Scan(dest ...interface{}) error
	Err() error
}) ([]models.MarcoGroupMember, error) {
	var members []models.MarcoGroupMember
	for rows.Next() {
		var m models.MarcoGroupMember
		if err := rows.Scan(&m.ID, &m.GroupID, &m.DeviceID, &m.CreatedAt, &m.DeviceName, &m.Hostname, &m.MACAddress, &m.IPAddress, &m.IsOnline); err != nil {
			return nil, err
		}
		members = append(members, m)
	}
	return members, rows.Err()
}

func (r *MarcoRepository) AddMember(ctx context.Context, groupID, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO marco_group_members (group_id, device_id) VALUES ($1,$2) ON CONFLICT (device_id) DO UPDATE SET group_id=EXCLUDED.group_id`,
		groupID, deviceID)
	return err
}

func (r *MarcoRepository) RemoveMember(ctx context.Context, groupID, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM marco_group_members WHERE group_id=$1 AND device_id=$2`, groupID, deviceID)
	return err
}

func (r *MarcoRepository) RemoveDeviceFromAllGroups(ctx context.Context, orgID, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM marco_group_members WHERE device_id=$1`, deviceID)
	return err
}

func (r *MarcoRepository) GroupForDevice(ctx context.Context, orgID, deviceID uuid.UUID) (*models.MarcoGroup, error) {
	row := r.db.QueryRow(ctx, `
		SELECT g.id, g.organization_id, g.name, g.description, g.color, g.icon, g.policy, g.created_at, g.updated_at
		FROM marco_group_members m
		JOIN marco_groups g ON g.id = m.group_id
		WHERE m.device_id=$1 AND g.organization_id=$2`, deviceID, orgID)
	return scanMarcoGroup(row)
}

// PolicyLogs
func (r *MarcoRepository) CreatePolicyLog(ctx context.Context, l *models.MarcoPolicyLog) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO marco_policy_logs (id, organization_id, group_id, device_id, action, message, status, router_error) VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
		l.ID, l.OrganizationID, l.GroupID, l.DeviceID, l.Action, l.Message, l.Status, l.RouterError)
	return err
}

func (r *MarcoRepository) ListPolicyLogs(ctx context.Context, orgID uuid.UUID, limit int) ([]models.MarcoPolicyLog, error) {
	if limit <= 0 || limit > 500 {
		limit = 100
	}
	rows, err := r.db.Query(ctx, `
		SELECT id, organization_id, group_id, device_id, action, message, status, router_error, created_at
		FROM marco_policy_logs WHERE organization_id=$1 ORDER BY created_at DESC LIMIT $2`, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var logs []models.MarcoPolicyLog
	for rows.Next() {
		var l models.MarcoPolicyLog
		if err := rows.Scan(&l.ID, &l.OrganizationID, &l.GroupID, &l.DeviceID, &l.Action, &l.Message, &l.Status, &l.RouterError, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	return logs, rows.Err()
}

// Quota usage
func (r *MarcoRepository) UpsertQuotaUsage(ctx context.Context, u *models.MarcoQuotaUsage) error {
	_, err := r.db.Exec(ctx, `
		INSERT INTO marco_quota_usage (id, organization_id, device_id, group_id, period_type, period_key, bytes_used)
		VALUES ($1,$2,$3,$4,$5,$6,$7)
		ON CONFLICT (device_id, period_type, period_key)
		DO UPDATE SET bytes_used=EXCLUDED.bytes_used, group_id=EXCLUDED.group_id, updated_at=NOW()`,
		u.ID, u.OrganizationID, u.DeviceID, u.GroupID, u.PeriodType, u.PeriodKey, u.BytesUsed)
	return err
}

func (r *MarcoRepository) GetQuotaUsage(ctx context.Context, deviceID uuid.UUID, periodType, periodKey string) (*models.MarcoQuotaUsage, error) {
	row := r.db.QueryRow(ctx, `
		SELECT id, organization_id, device_id, group_id, period_type, period_key, bytes_used, updated_at
		FROM marco_quota_usage WHERE device_id=$1 AND period_type=$2 AND period_key=$3`, deviceID, periodType, periodKey)
	var u models.MarcoQuotaUsage
	if err := row.Scan(&u.ID, &u.OrganizationID, &u.DeviceID, &u.GroupID, &u.PeriodType, &u.PeriodKey, &u.BytesUsed, &u.UpdatedAt); err != nil {
		return nil, err
	}
	return &u, nil
}

func (r *MarcoRepository) ListQuotaUsageForGroup(ctx context.Context, groupID uuid.UUID, periodType, periodKey string) ([]models.MarcoQuotaUsage, error) {
	rows, err := r.db.Query(ctx, `
		SELECT id, organization_id, device_id, group_id, period_type, period_key, bytes_used, updated_at
		FROM marco_quota_usage WHERE group_id=$1 AND period_type=$2 AND period_key=$3`, groupID, periodType, periodKey)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var usages []models.MarcoQuotaUsage
	for rows.Next() {
		var u models.MarcoQuotaUsage
		if err := rows.Scan(&u.ID, &u.OrganizationID, &u.DeviceID, &u.GroupID, &u.PeriodType, &u.PeriodKey, &u.BytesUsed, &u.UpdatedAt); err != nil {
			return nil, err
		}
		usages = append(usages, u)
	}
	return usages, rows.Err()
}

// ---------------------------------------------------------------------------
// Per-device overrides and the always-allowed websites

// ListOverrides returns every block and speed limit set on a device.
func (r *MarcoRepository) ListOverrides(ctx context.Context, orgID uuid.UUID) ([]models.MarcoDeviceOverride, error) {
	rows, err := r.db.Query(ctx,
		`SELECT mac, blocked, download_limit_mbps, upload_limit_mbps, reason, updated_at
		   FROM marco_device_overrides WHERE organization_id = $1 ORDER BY mac`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []models.MarcoDeviceOverride{}
	for rows.Next() {
		var o models.MarcoDeviceOverride
		if err := rows.Scan(&o.MAC, &o.Blocked, &o.DownloadLimitMbps, &o.UploadLimitMbps, &o.Reason, &o.UpdatedAt); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// SaveOverride stores the override of one device. An override that blocks nothing
// and limits nothing is removed.
func (r *MarcoRepository) SaveOverride(ctx context.Context, orgID uuid.UUID, o models.MarcoDeviceOverride) error {
	if !o.Blocked && o.DownloadLimitMbps == nil && o.UploadLimitMbps == nil {
		return r.DeleteOverride(ctx, orgID, o.MAC)
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO marco_device_overrides (organization_id, mac, blocked, download_limit_mbps, upload_limit_mbps, reason, updated_at)
		 VALUES ($1, $2, $3, $4, $5, $6, NOW())
		 ON CONFLICT (organization_id, mac) DO UPDATE SET blocked = EXCLUDED.blocked,
		   download_limit_mbps = EXCLUDED.download_limit_mbps, upload_limit_mbps = EXCLUDED.upload_limit_mbps,
		   reason = EXCLUDED.reason, updated_at = NOW()`,
		orgID, o.MAC, o.Blocked, o.DownloadLimitMbps, o.UploadLimitMbps, o.Reason)
	return err
}

func (r *MarcoRepository) DeleteOverride(ctx context.Context, orgID uuid.UUID, mac string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM marco_device_overrides WHERE organization_id = $1 AND mac = $2`, orgID, mac)
	return err
}

// ListAllowDomains returns the websites added by hand to the always-allowed list.
func (r *MarcoRepository) ListAllowDomains(ctx context.Context, orgID uuid.UUID) ([]string, error) {
	rows, err := r.db.Query(ctx, `SELECT domain FROM marco_allow_domains WHERE organization_id = $1 ORDER BY domain`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []string{}
	for rows.Next() {
		var d string
		if err := rows.Scan(&d); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

func (r *MarcoRepository) AddAllowDomain(ctx context.Context, orgID uuid.UUID, domain string) error {
	_, err := r.db.Exec(ctx, `INSERT INTO marco_allow_domains (organization_id, domain) VALUES ($1, $2) ON CONFLICT DO NOTHING`, orgID, domain)
	return err
}

func (r *MarcoRepository) RemoveAllowDomain(ctx context.Context, orgID uuid.UUID, domain string) error {
	_, err := r.db.Exec(ctx, `DELETE FROM marco_allow_domains WHERE organization_id = $1 AND domain = $2`, orgID, domain)
	return err
}

// SetDeviceIP records the address a device has now. A device added to a group by
// MAC starts with no address; this fills it in from what the router sees.
func (r *MarcoRepository) SetDeviceIP(ctx context.Context, orgID uuid.UUID, mac, ip string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE devices SET ip_address = $3::inet, updated_at = NOW()
		  WHERE organization_id = $1 AND mac_address = $2::macaddr AND ip_address IS DISTINCT FROM $3::inet`,
		orgID, mac, ip)
	return err
}
