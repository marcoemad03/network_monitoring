package repository

import (
	"context"
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type DeviceRepository struct {
	db *database.DB
}

func NewDeviceRepository(db *database.DB) *DeviceRepository {
	return &DeviceRepository{db: db}
}

func (r *DeviceRepository) List(ctx context.Context, orgID uuid.UUID, page, limit int, search, status, deviceType, department, sortBy string, ascending bool) ([]models.Device, int, error) {
	offset := (page - 1) * limit
	query := `SELECT id, organization_id, name, hostname, ip_address, mac_address::text, device_type, status, vendor, model, serial_number, os_version, firmware_version, location, department, notes, custom_fields, first_seen, last_boot, last_seen, is_critical, is_monitored, created_at, updated_at FROM devices WHERE organization_id = $1`
	countQuery := `SELECT COUNT(*) FROM devices WHERE organization_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if search != "" {
		query += fmt.Sprintf(` AND (name ILIKE $%d OR hostname ILIKE $%d OR ip_address::text ILIKE $%d OR mac_address::text ILIKE $%d)`, argIdx, argIdx+1, argIdx+2, argIdx+3)
		countQuery += fmt.Sprintf(` AND (name ILIKE $%d OR hostname ILIKE $%d OR ip_address::text ILIKE $%d OR mac_address::text ILIKE $%d)`, argIdx, argIdx+1, argIdx+2, argIdx+3)
		searchPattern := "%" + search + "%"
		args = append(args, searchPattern, searchPattern, searchPattern, searchPattern)
		argIdx += 4
	}
	if status != "" {
		query += fmt.Sprintf(` AND status = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND status = $%d`, argIdx)
		args = append(args, status)
		argIdx++
	}
	if deviceType != "" {
		query += fmt.Sprintf(` AND device_type = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND device_type = $%d`, argIdx)
		args = append(args, deviceType)
		argIdx++
	}
	if department != "" {
		query += fmt.Sprintf(` AND department = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND department = $%d`, argIdx)
		args = append(args, department)
		argIdx++
	}

	orderDir := "DESC"
	if ascending {
		orderDir = "ASC"
	}
	validSorts := map[string]bool{"name": true, "ip_address": true, "status": true, "device_type": true, "last_seen": true, "created_at": true}
	if !validSorts[sortBy] {
		sortBy = "created_at"
	}
	query += fmt.Sprintf(` ORDER BY %s %s LIMIT $%d OFFSET $%d`, sortBy, orderDir, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("query devices: %w", err)
	}
	defer rows.Close()

	var devices []models.Device
	for rows.Next() {
		var d models.Device
		if err := rows.Scan(
			&d.ID, &d.OrganizationID, &d.Name, &d.Hostname, &d.IPAddress,
			&d.MACAddress, &d.DeviceType, &d.Status, &d.Vendor, &d.Model,
			&d.SerialNumber, &d.OSVersion, &d.FirmwareVersion, &d.Location,
			&d.Department, &d.Notes, &d.CustomFields, &d.FirstSeen, &d.LastBoot,
			&d.LastSeen, &d.IsCritical, &d.IsMonitored, &d.CreatedAt, &d.UpdatedAt,
		); err != nil {
			return nil, 0, fmt.Errorf("scan device: %w", err)
		}
		devices = append(devices, d)
	}

	var total int
	countArgs := args[:len(args)-2]
	if err := r.db.QueryRow(ctx, countQuery, countArgs...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("count devices: %w", err)
	}

	return devices, total, nil
}

func (r *DeviceRepository) GetByID(ctx context.Context, id uuid.UUID) (*models.Device, error) {
	query := `SELECT id, organization_id, name, hostname, ip_address, mac_address::text, device_type, status, vendor, model, serial_number, os_version, firmware_version, location, department, notes, custom_fields, first_seen, last_boot, last_seen, is_critical, is_monitored, created_at, updated_at FROM devices WHERE id = $1`
	row := r.db.QueryRow(ctx, query, id)

	var d models.Device
	if err := row.Scan(
		&d.ID, &d.OrganizationID, &d.Name, &d.Hostname, &d.IPAddress,
		&d.MACAddress, &d.DeviceType, &d.Status, &d.Vendor, &d.Model,
		&d.SerialNumber, &d.OSVersion, &d.FirmwareVersion, &d.Location,
		&d.Department, &d.Notes, &d.CustomFields, &d.FirstSeen, &d.LastBoot,
		&d.LastSeen, &d.IsCritical, &d.IsMonitored, &d.CreatedAt, &d.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("get device by id: %w", err)
	}
	return &d, nil
}

func (r *DeviceRepository) GetByIDForOrganization(ctx context.Context, orgID, id uuid.UUID) (*models.Device, error) {
	query := `SELECT id, organization_id, name, hostname, ip_address, mac_address::text, device_type, status, vendor, model, serial_number, os_version, firmware_version, location, department, notes, custom_fields, first_seen, last_boot, last_seen, is_critical, is_monitored, created_at, updated_at FROM devices WHERE id = $1 AND organization_id = $2`
	var d models.Device
	if err := r.db.QueryRow(ctx, query, id, orgID).Scan(
		&d.ID, &d.OrganizationID, &d.Name, &d.Hostname, &d.IPAddress, &d.MACAddress,
		&d.DeviceType, &d.Status, &d.Vendor, &d.Model, &d.SerialNumber, &d.OSVersion,
		&d.FirmwareVersion, &d.Location, &d.Department, &d.Notes, &d.CustomFields,
		&d.FirstSeen, &d.LastBoot, &d.LastSeen, &d.IsCritical, &d.IsMonitored,
		&d.CreatedAt, &d.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("get organization device: %w", err)
	}
	return &d, nil
}

func (r *DeviceRepository) GetByMACForOrganization(ctx context.Context, orgID uuid.UUID, mac string) (*models.Device, error) {
	query := `SELECT id, organization_id, name, hostname, ip_address, mac_address::text, device_type, status, vendor, model, serial_number, os_version, firmware_version, location, department, notes, custom_fields, first_seen, last_boot, last_seen, is_critical, is_monitored, created_at, updated_at FROM devices WHERE organization_id = $1 AND mac_address = $2::macaddr`
	var d models.Device
	if err := r.db.QueryRow(ctx, query, orgID, strings.TrimSpace(mac)).Scan(
		&d.ID, &d.OrganizationID, &d.Name, &d.Hostname, &d.IPAddress, &d.MACAddress,
		&d.DeviceType, &d.Status, &d.Vendor, &d.Model, &d.SerialNumber, &d.OSVersion,
		&d.FirmwareVersion, &d.Location, &d.Department, &d.Notes, &d.CustomFields,
		&d.FirstSeen, &d.LastBoot, &d.LastSeen, &d.IsCritical, &d.IsMonitored,
		&d.CreatedAt, &d.UpdatedAt,
	); err != nil {
		return nil, fmt.Errorf("get organization device by MAC: %w", err)
	}
	return &d, nil
}

// UpsertDiscovered uses the stable MAC identity and updates a device's current IP.
// Devices without a MAC are matched by IP only within the same organization.
func (r *DeviceRepository) UpsertDiscovered(ctx context.Context, d *models.Device) (uuid.UUID, bool, error) {
	if d.MACAddress != nil && strings.TrimSpace(*d.MACAddress) != "" {
		mac := strings.ToUpper(strings.TrimSpace(*d.MACAddress))
		var id uuid.UUID
		var inserted bool
		err := r.db.QueryRow(ctx, `
			INSERT INTO devices (id, organization_id, name, hostname, ip_address, mac_address, device_type, status, vendor, first_seen, last_seen, is_monitored, created_at, updated_at)
			VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,NOW(),NOW())
			ON CONFLICT (organization_id, mac_address) WHERE mac_address IS NOT NULL
			DO UPDATE SET ip_address=EXCLUDED.ip_address, hostname=COALESCE(EXCLUDED.hostname, devices.hostname),
				name=CASE WHEN EXCLUDED.hostname IS NOT NULL THEN EXCLUDED.name ELSE devices.name END,
				vendor=COALESCE(EXCLUDED.vendor, devices.vendor), status=EXCLUDED.status,
				last_seen=EXCLUDED.last_seen, updated_at=NOW()
			RETURNING id, (xmax = 0)`, d.ID, d.OrganizationID, d.Name, d.Hostname, d.IPAddress,
			mac, d.DeviceType, d.Status, d.Vendor, d.FirstSeen, d.LastSeen, d.IsMonitored).Scan(&id, &inserted)
		return id, inserted, err
	}

	var existingID uuid.UUID
	err := r.db.QueryRow(ctx, `SELECT id FROM devices WHERE organization_id=$1 AND ip_address=$2 ORDER BY created_at LIMIT 1`, d.OrganizationID, d.IPAddress).Scan(&existingID)
	if err == nil {
		_, err = r.db.Exec(ctx, `UPDATE devices SET hostname=COALESCE($1, hostname), name=CASE WHEN $1::text IS NOT NULL THEN $2 ELSE name END, vendor=COALESCE($3, vendor), status=$4, last_seen=$5, updated_at=NOW() WHERE id=$6 AND organization_id=$7`, d.Hostname, d.Name, d.Vendor, d.Status, d.LastSeen, existingID, d.OrganizationID)
		return existingID, false, err
	}
	if !d.IPAddress.Equal(net.IP{}) {
		if err := r.Create(ctx, d); err != nil {
			return uuid.Nil, false, err
		}
		return d.ID, true, nil
	}
	return uuid.Nil, false, fmt.Errorf("discovered device has neither MAC nor IP")
}

func (r *DeviceRepository) Create(ctx context.Context, d *models.Device) error {
	query := `INSERT INTO devices (id, organization_id, name, hostname, ip_address, mac_address, device_type, status, vendor, model, serial_number, os_version, firmware_version, location, department, notes, custom_fields, first_seen, last_boot, last_seen, is_critical, is_monitored, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24)`
	_, err := r.db.Exec(ctx, query,
		d.ID, d.OrganizationID, d.Name, d.Hostname, d.IPAddress,
		d.MACAddress, d.DeviceType, d.Status, d.Vendor, d.Model,
		d.SerialNumber, d.OSVersion, d.FirmwareVersion, d.Location,
		d.Department, d.Notes, d.CustomFields, d.FirstSeen, d.LastBoot,
		d.LastSeen, d.IsCritical, d.IsMonitored, time.Now(), time.Now(),
	)
	return err
}

func (r *DeviceRepository) Update(ctx context.Context, d *models.Device) error {
	query := `UPDATE devices SET name=$1, hostname=$2, ip_address=$3, mac_address=$4, device_type=$5, status=$6, vendor=$7, model=$8, serial_number=$9, os_version=$10, firmware_version=$11, location=$12, department=$13, notes=$14, custom_fields=$15, last_boot=$16, is_critical=$17, is_monitored=$18, updated_at=NOW() WHERE id=$19`
	_, err := r.db.Exec(ctx, query,
		d.Name, d.Hostname, d.IPAddress, d.MACAddress, d.DeviceType,
		d.Status, d.Vendor, d.Model, d.SerialNumber, d.OSVersion,
		d.FirmwareVersion, d.Location, d.Department, d.Notes, d.CustomFields,
		d.LastBoot, d.IsCritical, d.IsMonitored, d.ID,
	)
	return err
}

func (r *DeviceRepository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.db.Exec(ctx, `DELETE FROM devices WHERE id = $1`, id)
	return err
}

func (r *DeviceRepository) GetInterfaces(ctx context.Context, deviceID uuid.UUID) ([]models.Interface, error) {
	rows, err := r.db.Query(ctx, `SELECT id, device_id, name, description, mac_address, ip_address, subnet_mask, gateway, connection_type, is_up, is_management, mtu, speed_mbps, duplex, index, vlan_id, bytes_in, bytes_out, errors_in, errors_out, utilization_percent, last_status_change, created_at, updated_at FROM interfaces WHERE device_id = $1 ORDER BY index ASC`, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ifaces []models.Interface
	for rows.Next() {
		var iface models.Interface
		if err := rows.Scan(
			&iface.ID, &iface.DeviceID, &iface.Name, &iface.Description,
			&iface.MACAddress, &iface.IPAddress, &iface.SubnetMask, &iface.Gateway,
			&iface.ConnectionType, &iface.IsUp, &iface.IsManagement, &iface.MTU,
			&iface.SpeedMbps, &iface.Duplex, &iface.Index, &iface.VlanID,
			&iface.BytesIn, &iface.BytesOut, &iface.ErrorsIn, &iface.ErrorsOut,
			&iface.UtilizationPercent, &iface.LastStatusChange, &iface.CreatedAt, &iface.UpdatedAt,
		); err != nil {
			return nil, err
		}
		ifaces = append(ifaces, iface)
	}
	return ifaces, nil
}

func (r *DeviceRepository) GetMetrics(ctx context.Context, deviceID uuid.UUID) (*models.DeviceMetrics, error) {
	query := `SELECT device_id, cpu_usage_percent, memory_usage_percent, disk_usage_percent, temperature_celsius, uptime_seconds, total_traffic_in_bps, total_traffic_out_bps, average_latency_ms, max_latency_ms, packet_loss_percent, upload_speed_bps, download_speed_bps, signal_strength_dbm, signal_quality_percent, connected_ap_id, connected_switch_id, timestamp FROM device_metrics WHERE device_id = $1 ORDER BY timestamp DESC LIMIT 1`
	row := r.db.QueryRow(ctx, query, deviceID)

	var m models.DeviceMetrics
	if err := row.Scan(
		&m.DeviceID, &m.CPUUsagePercent, &m.MemoryUsagePercent, &m.DiskUsagePercent,
		&m.TemperatureCelsius, &m.UptimeSeconds, &m.TotalTrafficInBps, &m.TotalTrafficOutBps,
		&m.AverageLatencyMs, &m.MaxLatencyMs, &m.PacketLossPercent,
		&m.UploadSpeedBps, &m.DownloadSpeedBps, &m.SignalStrengthDbm, &m.SignalQualityPercent,
		&m.ConnectedAPID, &m.ConnectedSwitchID, &m.Timestamp,
	); err != nil {
		return nil, fmt.Errorf("get device metrics: %w", err)
	}
	return &m, nil
}

func (r *DeviceRepository) CountByStatus(ctx context.Context, orgID uuid.UUID) (map[string]int, error) {
	rows, err := r.db.Query(ctx, `SELECT status, COUNT(*) as count FROM devices WHERE organization_id = $1 GROUP BY status`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	result := make(map[string]int)
	for rows.Next() {
		var status string
		var count int
		if err := rows.Scan(&status, &count); err != nil {
			return nil, err
		}
		result[status] = count
	}
	return result, nil
}
