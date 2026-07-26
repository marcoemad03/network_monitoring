package repository

import (
	"context"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type DeviceControlRepository struct {
	db *database.DB
}

func NewDeviceControlRepository(db *database.DB) *DeviceControlRepository {
	return &DeviceControlRepository{db: db}
}

func (r *DeviceControlRepository) CreateControlLog(ctx context.Context, log *models.DeviceControlLog) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_control_logs (id, organization_id, device_id, action, action_detail, performed_by, result, error_message, created_at)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())`,
		log.ID, log.OrganizationID, log.DeviceID, log.Action, log.ActionDetail, log.PerformedBy, log.Result, log.ErrorMessage)
	return err
}

func (r *DeviceControlRepository) GetDeviceLogs(ctx context.Context, deviceID uuid.UUID, limit int) ([]models.DeviceControlLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, device_id, action, action_detail, performed_by, result, error_message, created_at
		 FROM device_control_logs WHERE device_id = $1
		 ORDER BY created_at DESC LIMIT $2`, deviceID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []models.DeviceControlLog
	for rows.Next() {
		var l models.DeviceControlLog
		if err := rows.Scan(&l.ID, &l.OrganizationID, &l.DeviceID, &l.Action, &l.ActionDetail, &l.PerformedBy, &l.Result, &l.ErrorMessage, &l.CreatedAt); err != nil {
			return nil, err
		}
		logs = append(logs, l)
	}
	return logs, nil
}

func (r *DeviceControlRepository) SetDeviceSpeedLimit(ctx context.Context, deviceID uuid.UUID, downloadLimit, uploadLimit int64) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_inventory (device_id, current_download_speed, current_upload_speed, updated_at)
		 VALUES ($1, $2, $3, NOW())
		 ON CONFLICT (device_id) DO UPDATE SET current_download_speed = $2, current_upload_speed = $3, updated_at = NOW()`,
		deviceID, downloadLimit, uploadLimit)
	return err
}

func (r *DeviceControlRepository) RemoveDeviceSpeedLimit(ctx context.Context, deviceID uuid.UUID) error {
	_, err := r.db.Exec(ctx,
		`UPDATE device_inventory SET current_download_speed = 0, current_upload_speed = 0, updated_at = NOW()
		 WHERE device_id = $1`, deviceID)
	return err
}

func (r *DeviceControlRepository) GetInventory(ctx context.Context, deviceID uuid.UUID) (*models.DeviceInventory, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, device_id, building, floor, room, connection_type, connected_interface,
		        connected_ap, connected_switch, switch_port, dhcp_status, lease_time_seconds,
		        signal_strength_dbm, current_download_speed, current_upload_speed,
		        total_download_bytes, total_upload_bytes, is_pinned, is_critical,
		        created_at, updated_at
		 FROM device_inventory WHERE device_id = $1`, deviceID)

	var inv models.DeviceInventory
	err := row.Scan(&inv.ID, &inv.DeviceID, &inv.Building, &inv.Floor, &inv.Room,
		&inv.ConnectionType, &inv.ConnectedInterface, &inv.ConnectedAP, &inv.ConnectedSwitch,
		&inv.SwitchPort, &inv.DHCPStatus, &inv.LeaseTimeSeconds, &inv.SignalStrengthDbm,
		&inv.CurrentDownloadSpeed, &inv.CurrentUploadSpeed, &inv.TotalDownloadBytes,
		&inv.TotalUploadBytes, &inv.IsPinned, &inv.IsCritical, &inv.CreatedAt, &inv.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &inv, nil
}

func (r *DeviceControlRepository) UpsertInventory(ctx context.Context, inv *models.DeviceInventory) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_inventory (id, device_id, building, floor, room, connection_type,
		        connected_interface, connected_ap, connected_switch, switch_port,
		        dhcp_status, lease_time_seconds, signal_strength_dbm,
		        current_download_speed, current_upload_speed,
		        total_download_bytes, total_upload_bytes, is_pinned, is_critical,
		        created_at, updated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,NOW(),NOW())
		 ON CONFLICT (device_id) DO UPDATE SET
		   building=EXCLUDED.building, floor=EXCLUDED.floor, room=EXCLUDED.room,
		   connection_type=EXCLUDED.connection_type, connected_interface=EXCLUDED.connected_interface,
		   connected_ap=EXCLUDED.connected_ap, connected_switch=EXCLUDED.connected_switch,
		   switch_port=EXCLUDED.switch_port, dhcp_status=EXCLUDED.dhcp_status,
		   lease_time_seconds=EXCLUDED.lease_time_seconds, signal_strength_dbm=EXCLUDED.signal_strength_dbm,
		   current_download_speed=EXCLUDED.current_download_speed, current_upload_speed=EXCLUDED.current_upload_speed,
		   total_download_bytes=EXCLUDED.total_download_bytes, total_upload_bytes=EXCLUDED.total_upload_bytes,
		   is_pinned=EXCLUDED.is_pinned, is_critical=EXCLUDED.is_critical,
		   updated_at=NOW()`,
		inv.ID, inv.DeviceID, inv.Building, inv.Floor, inv.Room,
		inv.ConnectionType, inv.ConnectedInterface, inv.ConnectedAP, inv.ConnectedSwitch,
		inv.SwitchPort, inv.DHCPStatus, inv.LeaseTimeSeconds, inv.SignalStrengthDbm,
		inv.CurrentDownloadSpeed, inv.CurrentUploadSpeed, inv.TotalDownloadBytes,
		inv.TotalUploadBytes, inv.IsPinned, inv.IsCritical)
	return err
}

func (r *DeviceControlRepository) SyncMikroTikState(ctx context.Context, state *models.MikroTikSyncState) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO mikrotik_sync_state (id, organization_id, vendor_integration_id,
		        last_dhcp_sync, last_arp_sync, last_wireless_sync, last_bridge_sync,
		        last_interface_sync, last_queue_sync, last_firewall_sync, last_dns_sync,
		        routeros_version, total_devices_synced, status, error_message, created_at, updated_at)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,NOW(),NOW())
		 ON CONFLICT (vendor_integration_id) DO UPDATE SET
		   last_dhcp_sync=EXCLUDED.last_dhcp_sync, last_arp_sync=EXCLUDED.last_arp_sync,
		   last_wireless_sync=EXCLUDED.last_wireless_sync, last_bridge_sync=EXCLUDED.last_bridge_sync,
		   last_interface_sync=EXCLUDED.last_interface_sync, last_queue_sync=EXCLUDED.last_queue_sync,
		   last_firewall_sync=EXCLUDED.last_firewall_sync, last_dns_sync=EXCLUDED.last_dns_sync,
		   routeros_version=EXCLUDED.routeros_version, total_devices_synced=EXCLUDED.total_devices_synced,
		   status=EXCLUDED.status, error_message=EXCLUDED.error_message, updated_at=NOW()`,
		state.ID, state.OrganizationID, state.VendorIntegrationID,
		state.LastDHCPSync, state.LastARPSync, state.LastWirelessSync, state.LastBridgeSync,
		state.LastInterfaceSync, state.LastQueueSync, state.LastFirewallSync, state.LastDNSSync,
		state.RouterOSVersion, state.TotalDevicesSynced, state.Status, state.ErrorMessage)
	return err
}

func (r *DeviceControlRepository) GetMikroTikSyncState(ctx context.Context, vendorID uuid.UUID) (*models.MikroTikSyncState, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, organization_id, vendor_integration_id, last_dhcp_sync, last_arp_sync,
		        last_wireless_sync, last_bridge_sync, last_interface_sync, last_queue_sync,
		        last_firewall_sync, last_dns_sync, routeros_version, total_devices_synced,
		        status, error_message, created_at, updated_at
		 FROM mikrotik_sync_state WHERE vendor_integration_id = $1`, vendorID)

	var s models.MikroTikSyncState
	err := row.Scan(&s.ID, &s.OrganizationID, &s.VendorIntegrationID,
		&s.LastDHCPSync, &s.LastARPSync, &s.LastWirelessSync, &s.LastBridgeSync,
		&s.LastInterfaceSync, &s.LastQueueSync, &s.LastFirewallSync, &s.LastDNSSync,
		&s.RouterOSVersion, &s.TotalDevicesSynced, &s.Status, &s.ErrorMessage,
		&s.CreatedAt, &s.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &s, nil
}

func (r *DeviceControlRepository) ListMikroTikSyncStates(ctx context.Context, orgID uuid.UUID) ([]models.MikroTikSyncState, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, vendor_integration_id, last_dhcp_sync, last_arp_sync,
		        last_wireless_sync, last_bridge_sync, last_interface_sync, last_queue_sync,
		        last_firewall_sync, last_dns_sync, routeros_version, total_devices_synced,
		        status, error_message, created_at, updated_at
		 FROM mikrotik_sync_state WHERE organization_id = $1 ORDER BY updated_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var states []models.MikroTikSyncState
	for rows.Next() {
		var s models.MikroTikSyncState
		if err := rows.Scan(&s.ID, &s.OrganizationID, &s.VendorIntegrationID,
			&s.LastDHCPSync, &s.LastARPSync, &s.LastWirelessSync, &s.LastBridgeSync,
			&s.LastInterfaceSync, &s.LastQueueSync, &s.LastFirewallSync, &s.LastDNSSync,
			&s.RouterOSVersion, &s.TotalDevicesSynced, &s.Status, &s.ErrorMessage,
			&s.CreatedAt, &s.UpdatedAt); err != nil {
			return nil, err
		}
		states = append(states, s)
	}
	return states, nil
}
