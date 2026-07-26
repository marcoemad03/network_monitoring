package repository

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type AssetRepository struct {
	db *database.DB
}

func NewAssetRepository(db *database.DB) *AssetRepository {
	return &AssetRepository{db: db}
}

func (r *AssetRepository) CreateGroup(ctx context.Context, g *models.DeviceGroup) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_groups (id, organization_id, name, description, parent_group_id) VALUES ($1,$2,$3,$4,$5)`,
		g.ID, g.OrganizationID, g.Name, g.Description, g.ParentGroupID)
	return err
}

func (r *AssetRepository) UpdateGroup(ctx context.Context, g *models.DeviceGroup) error {
	_, err := r.db.Exec(ctx,
		`UPDATE device_groups SET name=$1, description=$2, parent_group_id=$3, updated_at=NOW() WHERE id=$4 AND organization_id=$5`,
		g.Name, g.Description, g.ParentGroupID, g.ID, g.OrganizationID)
	return err
}

func (r *AssetRepository) DeleteGroup(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM device_groups WHERE id=$1`, id)
	return err
}

func (r *AssetRepository) GetGroupByID(ctx context.Context, id uuid.UUID) (*models.DeviceGroup, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, organization_id, name, description, parent_group_id, created_at, updated_at FROM device_groups WHERE id=$1`, id)
	var g models.DeviceGroup
	err := row.Scan(&g.ID, &g.OrganizationID, &g.Name, &g.Description, &g.ParentGroupID, &g.CreatedAt, &g.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &g, nil
}

func (r *AssetRepository) ListGroups(ctx context.Context, orgID uuid.UUID) ([]models.DeviceGroup, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, name, description, parent_group_id, created_at, updated_at FROM device_groups WHERE organization_id=$1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var groups []models.DeviceGroup
	for rows.Next() {
		var g models.DeviceGroup
		if err := rows.Scan(&g.ID, &g.OrganizationID, &g.Name, &g.Description, &g.ParentGroupID, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	return groups, nil
}

func (r *AssetRepository) AssignDevicesToGroup(ctx context.Context, groupID uuid.UUID, deviceIDs []uuid.UUID) error {
	for _, did := range deviceIDs {
		_, err := r.db.Exec(ctx,
			`INSERT INTO device_group_members (device_id, group_id) VALUES ($1,$2) ON CONFLICT (device_id, group_id) DO NOTHING`,
			did, groupID)
		if err != nil {
			return fmt.Errorf("assign device %s: %w", did, err)
		}
	}
	return nil
}

func (r *AssetRepository) RemoveDeviceFromGroup(ctx context.Context, groupID, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM device_group_members WHERE group_id=$1 AND device_id=$2`, groupID, deviceID)
	return err
}

func (r *AssetRepository) GetGroupDevices(ctx context.Context, groupID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx,
		`SELECT device_id FROM device_group_members WHERE group_id=$1`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, nil
}

func (r *AssetRepository) ListGroupsForDevice(ctx context.Context, deviceID uuid.UUID) ([]models.DeviceGroup, error) {
	rows, err := r.db.Query(ctx,
		`SELECT dg.id, dg.organization_id, dg.name, dg.description, dg.parent_group_id, dg.created_at, dg.updated_at
		 FROM device_groups dg
		 JOIN device_group_members dgm ON dgm.group_id = dg.id
		 WHERE dgm.device_id = $1
		 ORDER BY dg.name`, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var groups []models.DeviceGroup
	for rows.Next() {
		var g models.DeviceGroup
		if err := rows.Scan(&g.ID, &g.OrganizationID, &g.Name, &g.Description, &g.ParentGroupID, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		groups = append(groups, g)
	}
	return groups, nil
}

func (r *AssetRepository) CreateFloorMap(ctx context.Context, f *models.FloorMap) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO floor_maps (id, organization_id, name, image_path, width, height) VALUES ($1,$2,$3,$4,$5,$6)`,
		f.ID, f.OrganizationID, f.Name, f.ImagePath, f.Width, f.Height)
	return err
}

func (r *AssetRepository) UpdateFloorMap(ctx context.Context, f *models.FloorMap) error {
	_, err := r.db.Exec(ctx,
		`UPDATE floor_maps SET name=$1, image_path=$2, width=$3, height=$4, updated_at=NOW() WHERE id=$5 AND organization_id=$6`,
		f.Name, f.ImagePath, f.Width, f.Height, f.ID, f.OrganizationID)
	return err
}

func (r *AssetRepository) DeleteFloorMap(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM floor_maps WHERE id=$1`, id)
	return err
}

func (r *AssetRepository) GetFloorMapByID(ctx context.Context, id uuid.UUID) (*models.FloorMap, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, organization_id, name, image_path, width, height, created_at, updated_at FROM floor_maps WHERE id=$1`, id)
	var f models.FloorMap
	err := row.Scan(&f.ID, &f.OrganizationID, &f.Name, &f.ImagePath, &f.Width, &f.Height, &f.CreatedAt, &f.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &f, nil
}

func (r *AssetRepository) ListFloorMaps(ctx context.Context, orgID uuid.UUID) ([]models.FloorMap, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, name, image_path, width, height, created_at, updated_at FROM floor_maps WHERE organization_id=$1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var maps []models.FloorMap
	for rows.Next() {
		var f models.FloorMap
		if err := rows.Scan(&f.ID, &f.OrganizationID, &f.Name, &f.ImagePath, &f.Width, &f.Height, &f.CreatedAt, &f.UpdatedAt); err != nil {
			return nil, err
		}
		maps = append(maps, f)
	}
	return maps, nil
}

func (r *AssetRepository) PlaceDeviceOnMap(ctx context.Context, fmd *models.FloorMapDevice) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO floor_map_devices (id, floor_map_id, device_id, x_coord, y_coord) VALUES ($1,$2,$3,$4,$5)
		 ON CONFLICT (floor_map_id, device_id) DO UPDATE SET x_coord=$4, y_coord=$5, updated_at=NOW()`,
		fmd.ID, fmd.FloorMapID, fmd.DeviceID, fmd.XCoord, fmd.YCoord)
	return err
}

func (r *AssetRepository) RemoveDeviceFromMap(ctx context.Context, floorMapID, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM floor_map_devices WHERE floor_map_id=$1 AND device_id=$2`, floorMapID, deviceID)
	return err
}

func (r *AssetRepository) GetFloorMapDevices(ctx context.Context, floorMapID uuid.UUID) ([]models.FloorMapDeviceView, error) {
	rows, err := r.db.Query(ctx,
		`SELECT fmd.id, fmd.floor_map_id, fmd.device_id, fmd.x_coord, fmd.y_coord,
		        fmd.created_at, fmd.updated_at, d.name, d.mac_address::text,
		        d.ip_address, d.status
		 FROM floor_map_devices fmd
		 JOIN devices d ON d.id = fmd.device_id
		 WHERE fmd.floor_map_id=$1
		 ORDER BY d.name`, floorMapID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var devices []models.FloorMapDeviceView
	for rows.Next() {
		var d models.FloorMapDeviceView
		if err := rows.Scan(
			&d.ID, &d.FloorMapID, &d.DeviceID, &d.XCoord, &d.YCoord,
			&d.CreatedAt, &d.UpdatedAt, &d.DeviceName, &d.MACAddress,
			&d.IPAddress, &d.Status,
		); err != nil {
			return nil, err
		}
		devices = append(devices, d)
	}
	return devices, nil
}

func (r *AssetRepository) UpsertAssetDetail(ctx context.Context, a *models.AssetDetail) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO asset_details (id, device_id, department, floor_name, room, switch_port, access_point_id, notes)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8)
		 ON CONFLICT (device_id) DO UPDATE SET department=$3, floor_name=$4, room=$5, switch_port=$6, access_point_id=$7, notes=$8, updated_at=NOW()`,
		a.ID, a.DeviceID, a.Department, a.FloorName, a.Room, a.SwitchPort, a.AccessPointID, a.Notes)
	return err
}

func (r *AssetRepository) GetAssetDetail(ctx context.Context, deviceID uuid.UUID) (*models.AssetDetail, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, device_id, department, floor_name, room, switch_port, access_point_id, notes, created_at, updated_at FROM asset_details WHERE device_id=$1`, deviceID)
	var a models.AssetDetail
	err := row.Scan(&a.ID, &a.DeviceID, &a.Department, &a.FloorName, &a.Room, &a.SwitchPort, &a.AccessPointID, &a.Notes, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *AssetRepository) ListAssetDetails(ctx context.Context, orgID uuid.UUID) ([]models.AssetDetail, error) {
	rows, err := r.db.Query(ctx,
		`SELECT ad.id, ad.device_id, ad.department, ad.floor_name, ad.room, ad.switch_port, ad.access_point_id, ad.notes, ad.created_at, ad.updated_at
		 FROM asset_details ad
		 JOIN devices d ON d.id = ad.device_id
		 WHERE d.organization_id = $1
		 ORDER BY ad.department, ad.floor_name`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var details []models.AssetDetail
	for rows.Next() {
		var a models.AssetDetail
		if err := rows.Scan(&a.ID, &a.DeviceID, &a.Department, &a.FloorName, &a.Room, &a.SwitchPort, &a.AccessPointID, &a.Notes, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		details = append(details, a)
	}
	return details, nil
}

func (r *AssetRepository) CreatePolicy(ctx context.Context, p *models.Policy) error {
	configJSON, err := json.Marshal(p.Config)
	if err != nil {
		return fmt.Errorf("marshal config: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`INSERT INTO policies (id, organization_id, name, description, policy_type, config, is_active) VALUES ($1,$2,$3,$4,$5,$6,$7)`,
		p.ID, p.OrganizationID, p.Name, p.Description, p.PolicyType, configJSON, p.IsActive)
	return err
}

func (r *AssetRepository) UpdatePolicy(ctx context.Context, p *models.Policy) error {
	configJSON, err := json.Marshal(p.Config)
	if err != nil {
		return fmt.Errorf("marshal config: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`UPDATE policies SET name=$1, description=$2, policy_type=$3, config=$4, is_active=$5, updated_at=NOW() WHERE id=$6 AND organization_id=$7`,
		p.Name, p.Description, p.PolicyType, configJSON, p.IsActive, p.ID, p.OrganizationID)
	return err
}

func (r *AssetRepository) DeletePolicy(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM policies WHERE id=$1`, id)
	return err
}

func (r *AssetRepository) GetPolicyByID(ctx context.Context, id uuid.UUID) (*models.Policy, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, organization_id, name, description, policy_type, config, is_active, created_at, updated_at FROM policies WHERE id=$1`, id)
	var p models.Policy
	var configJSON []byte
	err := row.Scan(&p.ID, &p.OrganizationID, &p.Name, &p.Description, &p.PolicyType, &configJSON, &p.IsActive, &p.CreatedAt, &p.UpdatedAt)
	if err != nil {
		return nil, err
	}
	if err := json.Unmarshal(configJSON, &p.Config); err != nil {
		p.Config = make(map[string]interface{})
	}
	return &p, nil
}

func (r *AssetRepository) ListPolicies(ctx context.Context, orgID uuid.UUID) ([]models.Policy, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, name, description, policy_type, config, is_active, created_at, updated_at FROM policies WHERE organization_id=$1 ORDER BY name ASC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var policies []models.Policy
	for rows.Next() {
		var p models.Policy
		var configJSON []byte
		if err := rows.Scan(&p.ID, &p.OrganizationID, &p.Name, &p.Description, &p.PolicyType, &configJSON, &p.IsActive, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(configJSON, &p.Config); err != nil {
			p.Config = make(map[string]interface{})
		}
		policies = append(policies, p)
	}
	return policies, nil
}

func (r *AssetRepository) AssignPolicyToGroup(ctx context.Context, policyID, groupID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO policy_assignments (policy_id, group_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`,
		policyID, groupID)
	return err
}

func (r *AssetRepository) RemovePolicyFromGroup(ctx context.Context, policyID, groupID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`DELETE FROM policy_assignments WHERE policy_id=$1 AND group_id=$2`, policyID, groupID)
	return err
}

func (r *AssetRepository) GetPoliciesForGroup(ctx context.Context, groupID uuid.UUID) ([]models.Policy, error) {
	rows, err := r.db.Query(ctx,
		`SELECT p.id, p.organization_id, p.name, p.description, p.policy_type, p.config, p.is_active, p.created_at, p.updated_at
		 FROM policies p
		 JOIN policy_assignments pa ON pa.policy_id = p.id
		 WHERE pa.group_id = $1
		 ORDER BY p.name`, groupID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var policies []models.Policy
	for rows.Next() {
		var p models.Policy
		var configJSON []byte
		if err := rows.Scan(&p.ID, &p.OrganizationID, &p.Name, &p.Description, &p.PolicyType, &configJSON, &p.IsActive, &p.CreatedAt, &p.UpdatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(configJSON, &p.Config); err != nil {
			p.Config = make(map[string]interface{})
		}
		policies = append(policies, p)
	}
	return policies, nil
}

func (r *AssetRepository) ListAssignedPolicyDevices(ctx context.Context, orgID uuid.UUID) ([]models.AssignedPolicyDevice, error) {
	rows, err := r.db.Query(ctx, `
		SELECT DISTINCT p.id, p.organization_id, p.name, p.description, p.policy_type, p.config, p.is_active, p.created_at, p.updated_at,
		       d.id, d.organization_id, d.name, d.hostname, d.ip_address, d.mac_address::text, d.device_type, d.status, d.vendor,
		       d.model, d.serial_number, d.os_version, d.firmware_version, d.location, d.department, d.notes, d.custom_fields,
		       d.first_seen, d.last_boot, d.last_seen, d.is_critical, d.is_monitored, d.created_at, d.updated_at
		FROM policies p
		JOIN policy_assignments pa ON pa.policy_id = p.id
		JOIN device_group_members dgm ON dgm.group_id = pa.group_id
		JOIN devices d ON d.id = dgm.device_id AND d.organization_id = p.organization_id
		WHERE p.organization_id = $1 AND p.is_active = true
		ORDER BY p.id, d.id`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var targets []models.AssignedPolicyDevice
	for rows.Next() {
		var target models.AssignedPolicyDevice
		var configJSON []byte
		if err := rows.Scan(
			&target.Policy.ID, &target.Policy.OrganizationID, &target.Policy.Name, &target.Policy.Description,
			&target.Policy.PolicyType, &configJSON, &target.Policy.IsActive, &target.Policy.CreatedAt, &target.Policy.UpdatedAt,
			&target.Device.ID, &target.Device.OrganizationID, &target.Device.Name, &target.Device.Hostname,
			&target.Device.IPAddress, &target.Device.MACAddress, &target.Device.DeviceType, &target.Device.Status,
			&target.Device.Vendor, &target.Device.Model, &target.Device.SerialNumber, &target.Device.OSVersion,
			&target.Device.FirmwareVersion, &target.Device.Location, &target.Device.Department, &target.Device.Notes,
			&target.Device.CustomFields, &target.Device.FirstSeen, &target.Device.LastBoot, &target.Device.LastSeen,
			&target.Device.IsCritical, &target.Device.IsMonitored, &target.Device.CreatedAt, &target.Device.UpdatedAt,
		); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(configJSON, &target.Policy.Config); err != nil {
			return nil, fmt.Errorf("decode policy %s config: %w", target.Policy.ID, err)
		}
		targets = append(targets, target)
	}
	return targets, rows.Err()
}

func (r *AssetRepository) CreateSyncLog(ctx context.Context, l *models.SyncLog) error {
	detailsJSON, err := json.Marshal(l.Details)
	if err != nil {
		return fmt.Errorf("marshal details: %w", err)
	}
	_, err = r.db.Exec(ctx,
		`INSERT INTO sync_logs (id, organization_id, vendor_integration_id, status, details) VALUES ($1,$2,$3,$4,$5)`,
		l.ID, l.OrganizationID, l.VendorIntegrationID, l.Status, detailsJSON)
	return err
}

func (r *AssetRepository) ListSyncLogs(ctx context.Context, orgID uuid.UUID, limit int) ([]models.SyncLog, error) {
	if limit <= 0 {
		limit = 50
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, vendor_integration_id, status, details, created_at FROM sync_logs WHERE organization_id=$1 ORDER BY created_at DESC LIMIT $2`, orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var logs []models.SyncLog
	for rows.Next() {
		var l models.SyncLog
		var detailsJSON []byte
		if err := rows.Scan(&l.ID, &l.OrganizationID, &l.VendorIntegrationID, &l.Status, &detailsJSON, &l.CreatedAt); err != nil {
			return nil, err
		}
		if err := json.Unmarshal(detailsJSON, &l.Details); err != nil {
			l.Details = make(map[string]interface{})
		}
		logs = append(logs, l)
	}
	return logs, nil
}
