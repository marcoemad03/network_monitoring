package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type MonitoringRepository struct {
	db *database.DB
}

func NewMonitoringRepository(db *database.DB) *MonitoringRepository {
	return &MonitoringRepository{db: db}
}

func (r *MonitoringRepository) InsertMetrics(ctx context.Context, m *models.DeviceMetrics) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_metrics (device_id, cpu_usage_percent, memory_usage_percent, disk_usage_percent, temperature_celsius, uptime_seconds, total_traffic_in_bps, total_traffic_out_bps, average_latency_ms, max_latency_ms, packet_loss_percent, upload_speed_bps, download_speed_bps, signal_strength_dbm, signal_quality_percent, connected_ap_id, connected_switch_id, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)`,
		m.DeviceID, m.CPUUsagePercent, m.MemoryUsagePercent, m.DiskUsagePercent, m.TemperatureCelsius, m.UptimeSeconds, m.TotalTrafficInBps, m.TotalTrafficOutBps, m.AverageLatencyMs, m.MaxLatencyMs, m.PacketLossPercent, m.UploadSpeedBps, m.DownloadSpeedBps, m.SignalStrengthDbm, m.SignalQualityPercent, m.ConnectedAPID, m.ConnectedSwitchID, m.Timestamp)
	return err
}

func (r *MonitoringRepository) InsertPing(ctx context.Context, p *models.DevicePing) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_ping (device_id, min_rtt_ms, max_rtt_ms, avg_rtt_ms, median_rtt_ms, stddev_rtt_ms, jitter_ms, packet_loss_percent, packets_sent, packets_received, packets_lost, is_reachable, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
		p.DeviceID, p.MinRttMs, p.MaxRttMs, p.AvgRttMs, p.MedianRttMs, p.StddevRttMs, p.JitterMs, p.PacketLossPercent, p.PacketsSent, p.PacketsReceived, p.PacketsLost, p.IsReachable, p.Timestamp)
	return err
}

func (r *MonitoringRepository) InsertTraffic(ctx context.Context, t *models.DeviceTraffic) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_traffic (device_id, interface_id, upload_bps, download_bps, total_upload_bytes, total_download_bytes, upload_packets, download_packets, upload_errors, download_errors, upload_drops, download_drops, utilization_percent, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
		t.DeviceID, t.InterfaceID, t.UploadBps, t.DownloadBps, t.TotalUploadBytes, t.TotalDownloadBytes, t.UploadPackets, t.DownloadPackets, t.UploadErrors, t.DownloadErrors, t.UploadDrops, t.DownloadDrops, t.UtilizationPercent, t.Timestamp)
	return err
}

func (r *MonitoringRepository) UpsertClient(ctx context.Context, c *models.DeviceClient) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_clients (id, organization_id, device_id, mac_address, ip_address, hostname, vendor, os_type, connection_type, ssid, bssid, signal_strength_dbm, signal_quality_percent, channel, frequency_mhz, noise_dbm, snr_dbm, tx_rate_mbps, rx_rate_mbps, tx_bytes, rx_bytes, tx_packets, rx_packets, tx_errors, rx_errors, connected_ap_id, connected_switch_id, switch_port, vlan_id, lease_expires_at, is_active, first_seen, last_seen) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21,$22,$23,$24,$25,$26,$27,$28,$29,$30,$31,$32,$33) ON CONFLICT (mac_address, device_id) DO UPDATE SET ip_address=$5, hostname=$7, signal_strength_dbm=$12, signal_quality_percent=$13, tx_rate_mbps=$18, rx_rate_mbps=$19, tx_bytes=$20, rx_bytes=$21, connected_ap_id=$26, connected_switch_id=$27, is_active=$31, last_seen=NOW()`,
		c.ID, c.OrganizationID, c.DeviceID, c.MACAddress, c.IPAddress, c.Hostname, c.Vendor, c.OSType, c.ConnectionType, c.SSID, c.BSSID, c.SignalStrengthDbm, c.SignalQualityPercent, c.Channel, c.FrequencyMHz, c.NoiseDbm, c.SnrDbm, c.TxRateMbps, c.RxRateMbps, c.TxBytes, c.RxBytes, c.TxPackets, c.RxPackets, c.TxErrors, c.RxErrors, c.ConnectedApID, c.ConnectedSwitchID, c.SwitchPort, c.VlanID, c.LeaseExpiresAt, c.IsActive, c.FirstSeen, c.LastSeen)
	return err
}

func (r *MonitoringRepository) InsertConnection(ctx context.Context, c *models.DeviceConnection) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_connections (id, organization_id, parent_device_id, child_device_id, parent_interface_id, child_interface_id, connection_type, medium, speed_mbps, vlan_id, is_active, discovered_method, discovered_at, last_seen) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14) ON CONFLICT DO NOTHING`,
		c.ID, c.OrganizationID, c.ParentDeviceID, c.ChildDeviceID, c.ParentInterfaceID, c.ChildInterfaceID, c.ConnectionType, c.Medium, c.SpeedMbps, c.VlanID, c.IsActive, c.DiscoveredMethod, c.DiscoveredAt, c.LastSeen)
	return err
}

func (r *MonitoringRepository) InsertSpeedTest(ctx context.Context, s *models.DeviceSpeedTest) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_speed_tests (device_id, upload_speed_mbps, download_speed_mbps, latency_ms, jitter_ms, packet_loss_percent, test_server, test_duration_seconds, timestamp) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
		s.DeviceID, s.UploadSpeedMbps, s.DownloadSpeedMbps, s.LatencyMs, s.JitterMs, s.PacketLossPercent, s.TestServer, s.TestDurationSeconds, s.Timestamp)
	return err
}

func (r *MonitoringRepository) GetLatestMetrics(ctx context.Context, deviceID uuid.UUID) (*models.DeviceMetrics, error) {
	row := r.db.QueryRow(ctx,
		`SELECT device_id, cpu_usage_percent, memory_usage_percent, disk_usage_percent, temperature_celsius, uptime_seconds, total_traffic_in_bps, total_traffic_out_bps, average_latency_ms, max_latency_ms, packet_loss_percent, upload_speed_bps, download_speed_bps, signal_strength_dbm, signal_quality_percent, connected_ap_id, connected_switch_id, timestamp FROM device_metrics WHERE device_id = $1 ORDER BY timestamp DESC LIMIT 1`, deviceID)
	var m models.DeviceMetrics
	err := row.Scan(&m.DeviceID, &m.CPUUsagePercent, &m.MemoryUsagePercent, &m.DiskUsagePercent, &m.TemperatureCelsius, &m.UptimeSeconds, &m.TotalTrafficInBps, &m.TotalTrafficOutBps, &m.AverageLatencyMs, &m.MaxLatencyMs, &m.PacketLossPercent, &m.UploadSpeedBps, &m.DownloadSpeedBps, &m.SignalStrengthDbm, &m.SignalQualityPercent, &m.ConnectedAPID, &m.ConnectedSwitchID, &m.Timestamp)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *MonitoringRepository) GetLatestPing(ctx context.Context, deviceID uuid.UUID) (*models.DevicePing, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, device_id, min_rtt_ms, max_rtt_ms, avg_rtt_ms, median_rtt_ms, stddev_rtt_ms, jitter_ms, packet_loss_percent, packets_sent, packets_received, packets_lost, is_reachable, timestamp FROM device_ping WHERE device_id = $1 ORDER BY timestamp DESC LIMIT 1`, deviceID)
	var p models.DevicePing
	err := row.Scan(&p.ID, &p.DeviceID, &p.MinRttMs, &p.MaxRttMs, &p.AvgRttMs, &p.MedianRttMs, &p.StddevRttMs, &p.JitterMs, &p.PacketLossPercent, &p.PacketsSent, &p.PacketsReceived, &p.PacketsLost, &p.IsReachable, &p.Timestamp)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *MonitoringRepository) GetLatestTraffic(ctx context.Context, deviceID uuid.UUID) (*models.DeviceTraffic, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, device_id, interface_id, upload_bps, download_bps, total_upload_bytes, total_download_bytes, upload_packets, download_packets, upload_errors, download_errors, upload_drops, download_drops, utilization_percent, timestamp FROM device_traffic WHERE device_id = $1 ORDER BY timestamp DESC LIMIT 1`, deviceID)
	var t models.DeviceTraffic
	err := row.Scan(&t.ID, &t.DeviceID, &t.InterfaceID, &t.UploadBps, &t.DownloadBps, &t.TotalUploadBytes, &t.TotalDownloadBytes, &t.UploadPackets, &t.DownloadPackets, &t.UploadErrors, &t.DownloadErrors, &t.UploadDrops, &t.DownloadDrops, &t.UtilizationPercent, &t.Timestamp)
	if err != nil {
		return nil, err
	}
	return &t, nil
}

func (r *MonitoringRepository) GetClientsByDevice(ctx context.Context, deviceID uuid.UUID) ([]models.DeviceClient, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, device_id, mac_address, ip_address, hostname, vendor, os_type, connection_type, ssid, bssid, signal_strength_dbm, signal_quality_percent, channel, frequency_mhz, noise_dbm, snr_dbm, tx_rate_mbps, rx_rate_mbps, tx_bytes, rx_bytes, tx_packets, rx_packets, tx_errors, rx_errors, connected_ap_id, connected_switch_id, switch_port, vlan_id, lease_expires_at, is_active, first_seen, last_seen, created_at, updated_at FROM device_clients WHERE device_id = $1 AND is_active = true ORDER BY last_seen DESC`, deviceID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var clients []models.DeviceClient
	for rows.Next() {
		var c models.DeviceClient
		if err := rows.Scan(&c.ID, &c.OrganizationID, &c.DeviceID, &c.MACAddress, &c.IPAddress, &c.Hostname, &c.Vendor, &c.OSType, &c.ConnectionType, &c.SSID, &c.BSSID, &c.SignalStrengthDbm, &c.SignalQualityPercent, &c.Channel, &c.FrequencyMHz, &c.NoiseDbm, &c.SnrDbm, &c.TxRateMbps, &c.RxRateMbps, &c.TxBytes, &c.RxBytes, &c.TxPackets, &c.RxPackets, &c.TxErrors, &c.RxErrors, &c.ConnectedApID, &c.ConnectedSwitchID, &c.SwitchPort, &c.VlanID, &c.LeaseExpiresAt, &c.IsActive, &c.FirstSeen, &c.LastSeen, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		clients = append(clients, c)
	}
	return clients, nil
}

func (r *MonitoringRepository) GetAllActiveClients(ctx context.Context, orgID uuid.UUID) ([]models.DeviceClient, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, device_id, mac_address, ip_address, hostname, vendor, os_type, connection_type, ssid, bssid, signal_strength_dbm, signal_quality_percent, channel, frequency_mhz, noise_dbm, snr_dbm, tx_rate_mbps, rx_rate_mbps, tx_bytes, rx_bytes, tx_packets, rx_packets, tx_errors, rx_errors, connected_ap_id, connected_switch_id, switch_port, vlan_id, lease_expires_at, is_active, first_seen, last_seen, created_at, updated_at FROM device_clients WHERE organization_id = $1 AND is_active = true ORDER BY last_seen DESC LIMIT 500`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var clients []models.DeviceClient
	for rows.Next() {
		var c models.DeviceClient
		if err := rows.Scan(&c.ID, &c.OrganizationID, &c.DeviceID, &c.MACAddress, &c.IPAddress, &c.Hostname, &c.Vendor, &c.OSType, &c.ConnectionType, &c.SSID, &c.BSSID, &c.SignalStrengthDbm, &c.SignalQualityPercent, &c.Channel, &c.FrequencyMHz, &c.NoiseDbm, &c.SnrDbm, &c.TxRateMbps, &c.RxRateMbps, &c.TxBytes, &c.RxBytes, &c.TxPackets, &c.RxPackets, &c.TxErrors, &c.RxErrors, &c.ConnectedApID, &c.ConnectedSwitchID, &c.SwitchPort, &c.VlanID, &c.LeaseExpiresAt, &c.IsActive, &c.FirstSeen, &c.LastSeen, &c.CreatedAt, &c.UpdatedAt); err != nil {
			return nil, err
		}
		clients = append(clients, c)
	}
	return clients, nil
}

func (r *MonitoringRepository) GetConnections(ctx context.Context, orgID uuid.UUID) ([]models.DeviceConnection, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, organization_id, parent_device_id, child_device_id, parent_interface_id, child_interface_id, connection_type, medium, speed_mbps, vlan_id, is_active, discovered_method, discovered_at, last_seen, created_at FROM device_connections WHERE organization_id = $1 AND is_active = true ORDER BY parent_device_id`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conns []models.DeviceConnection
	for rows.Next() {
		var c models.DeviceConnection
		if err := rows.Scan(&c.ID, &c.OrganizationID, &c.ParentDeviceID, &c.ChildDeviceID, &c.ParentInterfaceID, &c.ChildInterfaceID, &c.ConnectionType, &c.Medium, &c.SpeedMbps, &c.VlanID, &c.IsActive, &c.DiscoveredMethod, &c.DiscoveredAt, &c.LastSeen, &c.CreatedAt); err != nil {
			return nil, err
		}
		conns = append(conns, c)
	}
	return conns, nil
}

func (r *MonitoringRepository) GetMetricsHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DeviceMetrics, error) {
	rows, err := r.db.Query(ctx,
		`SELECT device_id, cpu_usage_percent, memory_usage_percent, disk_usage_percent, temperature_celsius, uptime_seconds, total_traffic_in_bps, total_traffic_out_bps, average_latency_ms, max_latency_ms, packet_loss_percent, upload_speed_bps, download_speed_bps, signal_strength_dbm, signal_quality_percent, connected_ap_id, connected_switch_id, timestamp FROM device_metrics WHERE device_id = $1 AND timestamp >= $2 AND timestamp <= $3 ORDER BY timestamp ASC`, deviceID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var metrics []models.DeviceMetrics
	for rows.Next() {
		var m models.DeviceMetrics
		if err := rows.Scan(&m.DeviceID, &m.CPUUsagePercent, &m.MemoryUsagePercent, &m.DiskUsagePercent, &m.TemperatureCelsius, &m.UptimeSeconds, &m.TotalTrafficInBps, &m.TotalTrafficOutBps, &m.AverageLatencyMs, &m.MaxLatencyMs, &m.PacketLossPercent, &m.UploadSpeedBps, &m.DownloadSpeedBps, &m.SignalStrengthDbm, &m.SignalQualityPercent, &m.ConnectedAPID, &m.ConnectedSwitchID, &m.Timestamp); err != nil {
			return nil, err
		}
		metrics = append(metrics, m)
	}
	return metrics, nil
}

func (r *MonitoringRepository) GetPingHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DevicePing, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, device_id, min_rtt_ms, max_rtt_ms, avg_rtt_ms, median_rtt_ms, stddev_rtt_ms, jitter_ms, packet_loss_percent, packets_sent, packets_received, packets_lost, is_reachable, timestamp FROM device_ping WHERE device_id = $1 AND timestamp >= $2 AND timestamp <= $3 ORDER BY timestamp ASC`, deviceID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var pings []models.DevicePing
	for rows.Next() {
		var p models.DevicePing
		if err := rows.Scan(&p.ID, &p.DeviceID, &p.MinRttMs, &p.MaxRttMs, &p.AvgRttMs, &p.MedianRttMs, &p.StddevRttMs, &p.JitterMs, &p.PacketLossPercent, &p.PacketsSent, &p.PacketsReceived, &p.PacketsLost, &p.IsReachable, &p.Timestamp); err != nil {
			return nil, err
		}
		pings = append(pings, p)
	}
	return pings, nil
}

func (r *MonitoringRepository) GetTrafficHistory(ctx context.Context, deviceID uuid.UUID, from, to time.Time) ([]models.DeviceTraffic, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, device_id, interface_id, upload_bps, download_bps, total_upload_bytes, total_download_bytes, upload_packets, download_packets, upload_errors, download_errors, upload_drops, download_drops, utilization_percent, timestamp FROM device_traffic WHERE device_id = $1 AND timestamp >= $2 AND timestamp <= $3 ORDER BY timestamp ASC`, deviceID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var traffic []models.DeviceTraffic
	for rows.Next() {
		var t models.DeviceTraffic
		if err := rows.Scan(&t.ID, &t.DeviceID, &t.InterfaceID, &t.UploadBps, &t.DownloadBps, &t.TotalUploadBytes, &t.TotalDownloadBytes, &t.UploadPackets, &t.DownloadPackets, &t.UploadErrors, &t.DownloadErrors, &t.UploadDrops, &t.DownloadDrops, &t.UtilizationPercent, &t.Timestamp); err != nil {
			return nil, err
		}
		traffic = append(traffic, t)
	}
	return traffic, nil
}

func (r *MonitoringRepository) GetDashboardLiveSummary(ctx context.Context, orgID uuid.UUID) (*models.DashboardLiveSummary, error) {
	s := &models.DashboardLiveSummary{
		DevicesByType:   make(map[string]int),
		DevicesByStatus: make(map[string]int),
	}

	row := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM devices WHERE organization_id = $1`, orgID)
	row.Scan(&s.TotalDevices)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM devices WHERE organization_id = $1 AND status = 'online'`, orgID)
	row.Scan(&s.OnlineDevices)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM devices WHERE organization_id = $1 AND status = 'offline'`, orgID)
	row.Scan(&s.OfflineDevices)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM devices WHERE organization_id = $1 AND status = 'degraded'`, orgID)
	row.Scan(&s.DegradedDevices)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM device_clients WHERE organization_id = $1`, orgID)
	row.Scan(&s.TotalClients)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM device_clients WHERE organization_id = $1 AND is_active = true`, orgID)
	row.Scan(&s.ActiveClients)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM alerts WHERE organization_id = $1 AND severity = 'critical' AND status = 'open'`, orgID)
	row.Scan(&s.CriticalAlerts)

	row = r.db.QueryRow(ctx, `SELECT COUNT(*) FROM alerts WHERE organization_id = $1 AND status = 'open'`, orgID)
	row.Scan(&s.OpenAlerts)

	row = r.db.QueryRow(ctx, `SELECT AVG(cpu_usage_percent) FROM device_metrics dm JOIN devices d ON d.id = dm.device_id WHERE d.organization_id = $1 AND dm.timestamp > NOW() - INTERVAL '5 minutes'`, orgID)
	row.Scan(&s.AverageCPU)

	row = r.db.QueryRow(ctx, `SELECT AVG(memory_usage_percent) FROM device_metrics dm JOIN devices d ON d.id = dm.device_id WHERE d.organization_id = $1 AND dm.timestamp > NOW() - INTERVAL '5 minutes'`, orgID)
	row.Scan(&s.AverageMemory)

	row = r.db.QueryRow(ctx, `SELECT AVG(avg_rtt_ms) FROM device_ping dp JOIN devices d ON d.id = dp.device_id WHERE d.organization_id = $1 AND dp.timestamp > NOW() - INTERVAL '5 minutes'`, orgID)
	row.Scan(&s.AverageLatency)

	row = r.db.QueryRow(ctx, `SELECT AVG(packet_loss_percent) FROM device_ping dp JOIN devices d ON d.id = dp.device_id WHERE d.organization_id = $1 AND dp.timestamp > NOW() - INTERVAL '5 minutes'`, orgID)
	row.Scan(&s.AveragePacketLoss)

	row = r.db.QueryRow(ctx, `SELECT COALESCE(SUM(upload_bps), 0) FROM device_traffic dt JOIN devices d ON d.id = dt.device_id WHERE d.organization_id = $1 AND dt.timestamp > NOW() - INTERVAL '1 minute'`, orgID)
	row.Scan(&s.TotalUploadBps)

	row = r.db.QueryRow(ctx, `SELECT COALESCE(SUM(download_bps), 0) FROM device_traffic dt JOIN devices d ON d.id = dt.device_id WHERE d.organization_id = $1 AND dt.timestamp > NOW() - INTERVAL '1 minute'`, orgID)
	row.Scan(&s.TotalDownloadBps)

	rows, err := r.db.Query(ctx, `SELECT device_type, COUNT(*) FROM devices WHERE organization_id = $1 GROUP BY device_type`, orgID)
	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var dt string
			var count int
			rows.Scan(&dt, &count)
			s.DevicesByType[dt] = count
		}
	}

	rows2, err := r.db.Query(ctx, `SELECT status, COUNT(*) FROM devices WHERE organization_id = $1 GROUP BY status`, orgID)
	if err == nil {
		defer rows2.Close()
		for rows2.Next() {
			var st string
			var count int
			rows2.Scan(&st, &count)
			s.DevicesByStatus[st] = count
		}
	}

	s.UpdatedAt = time.Now()
	return s, nil
}

func (r *MonitoringRepository) UpdateDeviceStatus(ctx context.Context, deviceID uuid.UUID, status string) error {
	_, err := r.db.Exec(ctx, `UPDATE devices SET status = $1, last_seen = NOW() WHERE id = $2`, status, deviceID)
	return err
}

func (r *MonitoringRepository) GetMonitoredDevices(ctx context.Context) ([]uuid.UUID, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id FROM devices WHERE is_monitored = true AND status != 'maintenance'`)
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

func (r *MonitoringRepository) GetDeviceByID(ctx context.Context, id uuid.UUID) (*models.Device, error) {
	query := `SELECT id, organization_id, name, ip_address FROM devices WHERE id = $1`
	row := r.db.QueryRow(ctx, query, id)
	var d models.Device
	if err := row.Scan(&d.ID, &d.OrganizationID, &d.Name, &d.IPAddress); err != nil {
		return nil, fmt.Errorf("get device by id: %w", err)
	}
	return &d, nil
}

// EquipmentRow is a registered device with the outcome of its latest ping.
type EquipmentRow struct {
	ID          uuid.UUID  `json:"id"`
	Name        string     `json:"name"`
	IPAddress   string     `json:"ip_address"`
	DeviceType  string     `json:"device_type"`
	Status      string     `json:"status"`
	Vendor      string     `json:"vendor"`
	Model       string     `json:"model"`
	Location    string     `json:"location"`
	IsCritical  bool       `json:"is_critical"`
	IsPinned    bool       `json:"is_pinned"`
	IsMonitored bool       `json:"is_monitored"`
	LastSeen    time.Time  `json:"last_seen"`
	PingAvgMs   *float64   `json:"ping_avg_ms"`
	PingLossPct *float64   `json:"ping_loss_percent"`
	PingAt      *time.Time `json:"ping_at"`
}

// ListEquipment returns the registered devices of the given kinds with their
// latest ping, in one query.
func (r *MonitoringRepository) ListEquipment(ctx context.Context, orgID uuid.UUID, kinds []string) ([]EquipmentRow, error) {
	rows, err := r.db.Query(ctx,
		`SELECT d.id, d.name, regexp_replace(host(d.ip_address), '^::ffff:', ''), d.device_type::text, d.status::text,
		        COALESCE(d.vendor, ''), COALESCE(d.model, ''),
		        TRIM(BOTH ' ,' FROM CONCAT_WS(', ', NULLIF(d.building, ''), NULLIF(d.floor_name, ''), NULLIF(d.room, ''), NULLIF(d.location, ''))),
		        d.is_critical, d.is_pinned, d.is_monitored, d.last_seen,
		        p.avg_rtt_ms::float8, p.packet_loss_percent::float8, p.timestamp
		   FROM devices d
		   LEFT JOIN LATERAL (
		        SELECT avg_rtt_ms, packet_loss_percent, timestamp FROM device_ping
		         WHERE device_id = d.id ORDER BY timestamp DESC LIMIT 1) p ON true
		  WHERE d.organization_id = $1 AND d.device_type::text = ANY($2)
		  ORDER BY d.name`, orgID, kinds)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []EquipmentRow{}
	for rows.Next() {
		var e EquipmentRow
		if err := rows.Scan(&e.ID, &e.Name, &e.IPAddress, &e.DeviceType, &e.Status, &e.Vendor, &e.Model, &e.Location,
			&e.IsCritical, &e.IsPinned, &e.IsMonitored, &e.LastSeen, &e.PingAvgMs, &e.PingLossPct, &e.PingAt); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}

// MapDeviceRow is a registered device with what the network map needs to place it.
type MapDeviceRow struct {
	ID          uuid.UUID
	Name        string
	IPAddress   string
	MAC         string
	DeviceType  string
	Status      string
	Vendor      string
	Model       string
	Place       string // building, floor, room and location joined
	Port        string // router port the device says it is on
	IsCritical  bool
	IsMonitored bool
	LastSeen    time.Time
	PingAvgMs   *float64
}

// ListMapDevices returns every registered device for the network map.
func (r *MonitoringRepository) ListMapDevices(ctx context.Context, orgID uuid.UUID) ([]MapDeviceRow, error) {
	rows, err := r.db.Query(ctx,
		`SELECT d.id, d.name, regexp_replace(COALESCE(host(d.ip_address), ''), '^::ffff:', ''),
		        upper(COALESCE(d.mac_address::text, '')), d.device_type::text, d.status::text,
		        COALESCE(d.vendor, ''), COALESCE(d.model, ''),
		        TRIM(BOTH ' ,' FROM CONCAT_WS(', ', NULLIF(d.building, ''), NULLIF(d.floor_name, ''), NULLIF(d.room, ''), NULLIF(d.location, ''))),
		        COALESCE(d.connected_interface, ''), d.is_critical, d.is_monitored, d.last_seen, p.avg_rtt_ms::float8
		   FROM devices d
		   LEFT JOIN LATERAL (
		        SELECT avg_rtt_ms FROM device_ping WHERE device_id = d.id ORDER BY timestamp DESC LIMIT 1) p ON true
		  WHERE d.organization_id = $1
		  ORDER BY d.name`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []MapDeviceRow{}
	for rows.Next() {
		var d MapDeviceRow
		if err := rows.Scan(&d.ID, &d.Name, &d.IPAddress, &d.MAC, &d.DeviceType, &d.Status, &d.Vendor, &d.Model,
			&d.Place, &d.Port, &d.IsCritical, &d.IsMonitored, &d.LastSeen, &d.PingAvgMs); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}
