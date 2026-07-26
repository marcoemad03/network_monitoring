package repository

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/jackc/pgx/v5"
)

type InternetRepository struct {
	db *database.DB
}

func NewInternetRepository(db *database.DB) *InternetRepository {
	return &InternetRepository{db: db}
}

// InternetPolicy CRUD

func (r *InternetRepository) CreatePolicy(ctx context.Context, p *models.InternetPolicy) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO internet_policies (org_id, name, description, department, is_active, upload_limit_bps, download_limit_bps, policy_type, priority, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		p.OrganizationID, p.Name, p.Description, p.Department, p.IsActive, p.UploadLimitBps, p.DownloadLimitBps, p.PolicyType, p.Priority, p.CreatedBy)
	return err
}

func (r *InternetRepository) GetPolicyByID(ctx context.Context, id uuid.UUID) (*models.InternetPolicy, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, name, description, department, is_active, upload_limit_bps, download_limit_bps, policy_type, priority, created_by, created_at, updated_at FROM internet_policies WHERE id = $1`, id)
	var p models.InternetPolicy
	err := row.Scan(&p.ID, &p.OrganizationID, &p.Name, &p.Description, &p.Department, &p.IsActive, &p.UploadLimitBps, &p.DownloadLimitBps, &p.PolicyType, &p.Priority, &p.CreatedBy, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *InternetRepository) ListPolicies(ctx context.Context, orgID uuid.UUID) ([]models.InternetPolicy, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, name, description, department, is_active, upload_limit_bps, download_limit_bps, policy_type, priority, created_by, created_at, updated_at FROM internet_policies WHERE org_id = $1 ORDER BY priority ASC, name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var policies []models.InternetPolicy
	for rows.Next() {
		var p models.InternetPolicy
		if err := rows.Scan(&p.ID, &p.OrganizationID, &p.Name, &p.Description, &p.Department, &p.IsActive, &p.UploadLimitBps, &p.DownloadLimitBps, &p.PolicyType, &p.Priority, &p.CreatedBy, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		policies = append(policies, p)
	}
	return policies, nil
}

func (r *InternetRepository) UpdatePolicy(ctx context.Context, p *models.InternetPolicy) error {
	_, err := r.db.Exec(ctx,
		`UPDATE internet_policies SET name=$1, description=$2, department=$3, is_active=$4, upload_limit_bps=$5, download_limit_bps=$6, policy_type=$7, priority=$8, updated_at=NOW() WHERE id=$9`,
		p.Name, p.Description, p.Department, p.IsActive, p.UploadLimitBps, p.DownloadLimitBps, p.PolicyType, p.Priority, p.ID)
	return err
}

func (r *InternetRepository) DeletePolicy(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM internet_policies WHERE id = $1`, id)
	return err
}

// BandwidthRule CRUD

func (r *InternetRepository) CreateBandwidthRule(ctx context.Context, b *models.BandwidthRule) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO bandwidth_rules (policy_id, device_id, user_id, priority, upload_limit_bps, download_limit_bps, rule_type, is_temporary, temp_expires_at, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)`,
		b.PolicyID, b.DeviceID, b.UserID, b.Priority, b.UploadLimitBps, b.DownloadLimitBps, b.RuleType, b.IsTemporary, b.TempExpiresAt, b.IsActive)
	return err
}

func (r *InternetRepository) ListBandwidthRulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.BandwidthRule, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, policy_id, device_id, user_id, priority, upload_limit_bps, download_limit_bps, rule_type, is_temporary, temp_expires_at, is_active, created_at, updated_at FROM bandwidth_rules WHERE policy_id = $1 ORDER BY priority ASC`, policyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []models.BandwidthRule
	for rows.Next() {
		var b models.BandwidthRule
		if err := rows.Scan(&b.ID, &b.PolicyID, &b.DeviceID, &b.UserID, &b.Priority, &b.UploadLimitBps, &b.DownloadLimitBps, &b.RuleType, &b.IsTemporary, &b.TempExpiresAt, &b.IsActive, &b.CreatedAt, &b.UpdatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, b)
	}
	return rules, nil
}

func (r *InternetRepository) UpdateBandwidthRule(ctx context.Context, b *models.BandwidthRule) error {
	_, err := r.db.Exec(ctx,
		`UPDATE bandwidth_rules SET device_id=$1, user_id=$2, priority=$3, upload_limit_bps=$4, download_limit_bps=$5, rule_type=$6, is_temporary=$7, temp_expires_at=$8, is_active=$9, updated_at=NOW() WHERE id=$10`,
		b.DeviceID, b.UserID, b.Priority, b.UploadLimitBps, b.DownloadLimitBps, b.RuleType, b.IsTemporary, b.TempExpiresAt, b.IsActive, b.ID)
	return err
}

func (r *InternetRepository) DeleteBandwidthRule(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM bandwidth_rules WHERE id = $1`, id)
	return err
}

func (r *InternetRepository) SetTemporaryBandwidth(ctx context.Context, id uuid.UUID, uploadLimit, downloadLimit *int64, expiresAt time.Time) error {
	_, err := r.db.Exec(ctx,
		`UPDATE bandwidth_rules SET is_temporary=true, upload_limit_bps=$1, download_limit_bps=$2, temp_expires_at=$3, updated_at=NOW() WHERE id=$4`,
		uploadLimit, downloadLimit, expiresAt, id)
	return err
}

func (r *InternetRepository) ClearTemporaryBandwidth(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE bandwidth_rules SET is_temporary=false, temp_expires_at=NULL, updated_at=NOW() WHERE id=$1`, id)
	return err
}

// FilteringRule CRUD

func (r *InternetRepository) CreateFilteringRule(ctx context.Context, f *models.FilteringRule) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO filtering_rules (policy_id, rule_type, filter_type, value, description, is_active) VALUES ($1,$2,$3,$4,$5,$6)`,
		f.PolicyID, f.RuleType, f.FilterType, f.Value, f.Description, f.IsActive)
	return err
}

func (r *InternetRepository) ListFilteringRulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.FilteringRule, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, policy_id, rule_type, filter_type, value, description, is_active, created_at, updated_at FROM filtering_rules WHERE policy_id = $1 ORDER BY created_at ASC`, policyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []models.FilteringRule
	for rows.Next() {
		var f models.FilteringRule
		if err := rows.Scan(&f.ID, &f.PolicyID, &f.RuleType, &f.FilterType, &f.Value, &f.Description, &f.IsActive, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, f)
	}
	return rules, nil
}

func (r *InternetRepository) UpdateFilteringRule(ctx context.Context, f *models.FilteringRule) error {
	_, err := r.db.Exec(ctx,
		`UPDATE filtering_rules SET rule_type=$1, filter_type=$2, value=$3, description=$4, is_active=$5, updated_at=NOW() WHERE id=$6`,
		f.RuleType, f.FilterType, f.Value, f.Description, f.IsActive, f.ID)
	return err
}

func (r *InternetRepository) DeleteFilteringRule(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM filtering_rules WHERE id = $1`, id)
	return err
}

// TimeSchedule CRUD

func (r *InternetRepository) CreateSchedule(ctx context.Context, s *models.TimeSchedule) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO time_schedules (policy_id, day_of_week, start_time, end_time, is_active) VALUES ($1,$2,$3,$4,$5)`,
		s.PolicyID, s.DayOfWeek, s.StartTime, s.EndTime, s.IsActive)
	return err
}

func (r *InternetRepository) ListSchedulesByPolicy(ctx context.Context, policyID uuid.UUID) ([]models.TimeSchedule, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, policy_id, day_of_week, start_time, end_time, is_active, created_at, updated_at FROM time_schedules WHERE policy_id = $1 ORDER BY day_of_week, start_time`, policyID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var schedules []models.TimeSchedule
	for rows.Next() {
		var s models.TimeSchedule
		if err := rows.Scan(&s.ID, &s.PolicyID, &s.DayOfWeek, &s.StartTime, &s.EndTime, &s.IsActive, &s.CreatedAt, &s.UpdatedAt); err != nil {
			return nil, err
		}
		schedules = append(schedules, s)
	}
	return schedules, nil
}

func (r *InternetRepository) UpdateSchedule(ctx context.Context, s *models.TimeSchedule) error {
	_, err := r.db.Exec(ctx,
		`UPDATE time_schedules SET day_of_week=$1, start_time=$2, end_time=$3, is_active=$4, updated_at=NOW() WHERE id=$5`,
		s.DayOfWeek, s.StartTime, s.EndTime, s.IsActive, s.ID)
	return err
}

func (r *InternetRepository) DeleteSchedule(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM time_schedules WHERE id = $1`, id)
	return err
}

// DeviceBlock CRUD

func (r *InternetRepository) CreateDeviceBlock(ctx context.Context, b *models.DeviceBlock) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_blocks (org_id, device_id, mac_address, ip_address, reason, blocked_by, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		b.OrgID, b.DeviceID, b.MACAddress, b.IPAddress, b.Reason, b.BlockedBy, b.IsActive)
	return err
}

func (r *InternetRepository) ListDeviceBlocks(ctx context.Context, orgID uuid.UUID) ([]models.DeviceBlock, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, device_id, mac_address, ip_address, reason, blocked_by, blocked_at, unblocked_at, is_active, created_at FROM device_blocks WHERE org_id = $1 ORDER BY created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []models.DeviceBlock
	for rows.Next() {
		var b models.DeviceBlock
		if err := rows.Scan(&b.ID, &b.OrgID, &b.DeviceID, &b.MACAddress, &b.IPAddress, &b.Reason, &b.BlockedBy, &b.BlockedAt, &b.UnblockedAt, &b.IsActive, &b.CreatedAt); err != nil {
			return nil, err
		}
		blocks = append(blocks, b)
	}
	return blocks, nil
}

func (r *InternetRepository) GetDeviceBlockByDevice(ctx context.Context, deviceID uuid.UUID) (*models.DeviceBlock, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, device_id, mac_address, ip_address, reason, blocked_by, blocked_at, unblocked_at, is_active, created_at FROM device_blocks WHERE device_id = $1 AND is_active = true ORDER BY created_at DESC LIMIT 1`, deviceID)
	var b models.DeviceBlock
	err := row.Scan(&b.ID, &b.OrgID, &b.DeviceID, &b.MACAddress, &b.IPAddress, &b.Reason, &b.BlockedBy, &b.BlockedAt, &b.UnblockedAt, &b.IsActive, &b.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *InternetRepository) GetDeviceBlockByMAC(ctx context.Context, mac string) (*models.DeviceBlock, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, device_id, mac_address, ip_address, reason, blocked_by, blocked_at, unblocked_at, is_active, created_at FROM device_blocks WHERE mac_address = $1 AND is_active = true ORDER BY created_at DESC LIMIT 1`, mac)
	var b models.DeviceBlock
	err := row.Scan(&b.ID, &b.OrgID, &b.DeviceID, &b.MACAddress, &b.IPAddress, &b.Reason, &b.BlockedBy, &b.BlockedAt, &b.UnblockedAt, &b.IsActive, &b.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *InternetRepository) GetDeviceBlockByIP(ctx context.Context, ip string) (*models.DeviceBlock, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, device_id, mac_address, ip_address, reason, blocked_by, blocked_at, unblocked_at, is_active, created_at FROM device_blocks WHERE ip_address = $1 AND is_active = true ORDER BY created_at DESC LIMIT 1`, ip)
	var b models.DeviceBlock
	err := row.Scan(&b.ID, &b.OrgID, &b.DeviceID, &b.MACAddress, &b.IPAddress, &b.Reason, &b.BlockedBy, &b.BlockedAt, &b.UnblockedAt, &b.IsActive, &b.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *InternetRepository) UnblockDevice(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE device_blocks SET is_active=false, unblocked_at=NOW() WHERE id=$1`, id)
	return err
}

// VendorIntegration CRUD

func (r *InternetRepository) CreateVendorIntegration(ctx context.Context, v *models.VendorIntegration) error {
	return r.db.QueryRow(ctx,
		`INSERT INTO vendor_integrations (org_id, vendor_type, name, base_url, username, encrypted_password, api_key, api_version, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9) RETURNING id, created_at, updated_at`,
		v.OrgID, v.VendorType, v.Name, v.BaseURL, v.Username, v.EncryptedPassword, v.APIKey, v.APIVersion, v.IsActive).
		Scan(&v.ID, &v.CreatedAt, &v.UpdatedAt)
}

func (r *InternetRepository) SaveDevelopmentMikroTikIntegration(ctx context.Context, v *models.VendorIntegration) error {
	err := r.db.QueryRow(ctx,
		`UPDATE vendor_integrations
		 SET name=$1, base_url=$2, username=$3, encrypted_password=$4, is_active=true,
		     last_sync_at=NOW(), last_sync_status='connected', error_message=NULL, updated_at=NOW()
		 WHERE id = (
		     SELECT id FROM vendor_integrations
		     WHERE org_id=$5 AND vendor_type='mikrotik'
		     ORDER BY is_active DESC, created_at ASC LIMIT 1
		 )
		 RETURNING id, created_at, updated_at`,
		v.Name, v.BaseURL, v.Username, v.EncryptedPassword, v.OrgID).
		Scan(&v.ID, &v.CreatedAt, &v.UpdatedAt)
	if err == nil {
		return nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return err
	}

	v.VendorType = "mikrotik"
	v.IsActive = true
	return r.CreateVendorIntegration(ctx, v)
}

func (r *InternetRepository) GetVendorIntegrationByID(ctx context.Context, id uuid.UUID) (*models.VendorIntegration, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, vendor_type, name, base_url, username, encrypted_password, api_key, api_version, is_active, last_sync_at, last_sync_status, error_message, created_at, updated_at FROM vendor_integrations WHERE id = $1`, id)
	var v models.VendorIntegration
	err := row.Scan(&v.ID, &v.OrgID, &v.VendorType, &v.Name, &v.BaseURL, &v.Username, &v.EncryptedPassword, &v.APIKey, &v.APIVersion, &v.IsActive, &v.LastSyncAt, &v.LastSyncStatus, &v.ErrorMessage, &v.CreatedAt, &v.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &v, nil
}

func (r *InternetRepository) GetVendorIntegrationForOrganization(ctx context.Context, id, orgID uuid.UUID) (*models.VendorIntegration, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, vendor_type, name, base_url, username, encrypted_password, api_key, api_version, is_active, last_sync_at, last_sync_status, error_message, created_at, updated_at FROM vendor_integrations WHERE id = $1 AND org_id = $2`, id, orgID)
	var v models.VendorIntegration
	if err := row.Scan(&v.ID, &v.OrgID, &v.VendorType, &v.Name, &v.BaseURL, &v.Username, &v.EncryptedPassword, &v.APIKey, &v.APIVersion, &v.IsActive, &v.LastSyncAt, &v.LastSyncStatus, &v.ErrorMessage, &v.CreatedAt, &v.UpdatedAt); err != nil {
		return nil, err
	}
	return &v, nil
}

func (r *InternetRepository) GetActiveMikroTikIntegration(ctx context.Context, orgID uuid.UUID) (*models.VendorIntegration, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, vendor_type, name, base_url, username, encrypted_password, api_key, api_version, is_active, last_sync_at, last_sync_status, error_message, created_at, updated_at FROM vendor_integrations WHERE org_id = $1 AND vendor_type = 'mikrotik' AND is_active = true ORDER BY last_sync_at DESC NULLS LAST, created_at ASC LIMIT 1`, orgID)
	var v models.VendorIntegration
	if err := row.Scan(&v.ID, &v.OrgID, &v.VendorType, &v.Name, &v.BaseURL, &v.Username, &v.EncryptedPassword, &v.APIKey, &v.APIVersion, &v.IsActive, &v.LastSyncAt, &v.LastSyncStatus, &v.ErrorMessage, &v.CreatedAt, &v.UpdatedAt); err != nil {
		return nil, err
	}
	return &v, nil
}

func (r *InternetRepository) ListVendorIntegrations(ctx context.Context, orgID uuid.UUID) ([]models.VendorIntegration, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, vendor_type, name, base_url, username, encrypted_password, api_key, api_version, is_active, last_sync_at, last_sync_status, error_message, created_at, updated_at FROM vendor_integrations WHERE org_id = $1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var integrations []models.VendorIntegration
	for rows.Next() {
		var v models.VendorIntegration
		if err := rows.Scan(&v.ID, &v.OrgID, &v.VendorType, &v.Name, &v.BaseURL, &v.Username, &v.EncryptedPassword, &v.APIKey, &v.APIVersion, &v.IsActive, &v.LastSyncAt, &v.LastSyncStatus, &v.ErrorMessage, &v.CreatedAt, &v.UpdatedAt); err != nil {
			return nil, err
		}
		integrations = append(integrations, v)
	}
	return integrations, nil
}

func (r *InternetRepository) UpdateVendorIntegration(ctx context.Context, v *models.VendorIntegration) error {
	_, err := r.db.Exec(ctx,
		`UPDATE vendor_integrations SET vendor_type=$1, name=$2, base_url=$3, username=$4, encrypted_password=$5, api_key=$6, api_version=$7, is_active=$8, updated_at=NOW() WHERE id=$9`,
		v.VendorType, v.Name, v.BaseURL, v.Username, v.EncryptedPassword, v.APIKey, v.APIVersion, v.IsActive, v.ID)
	return err
}

func (r *InternetRepository) DeleteVendorIntegration(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM vendor_integrations WHERE id = $1`, id)
	return err
}

func (r *InternetRepository) UpdateVendorSyncStatus(ctx context.Context, id uuid.UUID, status string, lastSyncAt time.Time, errMsg *string) error {
	_, err := r.db.Exec(ctx,
		`UPDATE vendor_integrations SET last_sync_status=$1, last_sync_at=$2, error_message=$3, updated_at=NOW() WHERE id=$4`,
		status, lastSyncAt, errMsg, id)
	return err
}
