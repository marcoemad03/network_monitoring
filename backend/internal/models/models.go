package models

import (
	"net"
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID                 uuid.UUID  `json:"id" db:"id"`
	OrganizationID     uuid.UUID  `json:"organization_id" db:"organization_id"`
	Username           string     `json:"username" db:"username"`
	Email              string     `json:"email" db:"email"`
	PasswordHash       string     `json:"-" db:"password_hash"`
	DisplayName        *string    `json:"display_name,omitempty" db:"display_name"`
	FirstName          *string    `json:"first_name,omitempty" db:"first_name"`
	LastName           *string    `json:"last_name,omitempty" db:"last_name"`
	Role               string     `json:"role" db:"role"`
	Department         *string    `json:"department,omitempty" db:"department"`
	Title              *string    `json:"title,omitempty" db:"title"`
	Phone              *string    `json:"phone,omitempty" db:"phone"`
	AvatarURL          *string    `json:"avatar_url,omitempty" db:"avatar_url"`
	IsActive           bool       `json:"is_active" db:"is_active"`
	IsLocked           bool       `json:"is_locked" db:"is_locked"`
	IsMfaEnabled       bool       `json:"is_mfa_enabled" db:"is_mfa_enabled"`
	MFASecret          *string    `json:"-" db:"mfa_secret"`
	FailedLoginAttempts int       `json:"failed_login_attempts" db:"failed_login_attempts"`
	LockedUntil        *time.Time `json:"locked_until,omitempty" db:"locked_until"`
	LastLoginAt        *time.Time `json:"last_login_at,omitempty" db:"last_login_at"`
	LastLoginIP        net.IP     `json:"last_login_ip,omitempty" db:"last_login_ip"`
	PasswordChangedAt  *time.Time `json:"password_changed_at,omitempty" db:"password_changed_at"`
	PasswordResetToken *string    `json:"-" db:"password_reset_token"`
	PasswordResetExpiresAt *time.Time `json:"-" db:"password_reset_expires_at"`
	PasswordHistory     []string  `json:"-" db:"password_history"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
}

func (u *User) Sanitize() *User {
	u.PasswordHash = ""
	u.MFASecret = nil
	u.PasswordResetToken = nil
	u.PasswordResetExpiresAt = nil
	u.PasswordHistory = nil
	return u
}

type Role struct {
	ID              uuid.UUID `json:"id" db:"id"`
	Name            string    `json:"name" db:"name"`
	Slug            string    `json:"slug" db:"slug"`
	Description     *string   `json:"description,omitempty" db:"description"`
	PermissionLevel int       `json:"permission_level" db:"permission_level"`
	IsSystemRole    bool      `json:"is_system_role" db:"is_system_role"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

type Permission struct {
	ID          uuid.UUID `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Slug        string    `json:"slug" db:"slug"`
	Description *string   `json:"description,omitempty" db:"description"`
	Module      string    `json:"module" db:"module"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
}

type RolePermission struct {
	RoleID       uuid.UUID `json:"role_id" db:"role_id"`
	PermissionID uuid.UUID `json:"permission_id" db:"permission_id"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

type UserSession struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	UserID           uuid.UUID  `json:"user_id" db:"user_id"`
	TokenHash        string     `json:"token_hash" db:"token_hash"`
	RefreshTokenHash string     `json:"refresh_token_hash" db:"refresh_token_hash"`
	IPAddress        *net.IP    `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent        *string    `json:"user_agent,omitempty" db:"user_agent"`
	LastActivity     time.Time  `json:"last_activity" db:"last_activity"`
	ExpiresAt        time.Time  `json:"expires_at" db:"expires_at"`
	IsRevoked        bool       `json:"is_revoked" db:"is_revoked"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
}

type Device struct {
	ID                  uuid.UUID         `json:"id" db:"id"`
	OrganizationID      uuid.UUID         `json:"organization_id" db:"organization_id"`
	Name                string            `json:"name" db:"name"`
	Hostname            *string           `json:"hostname,omitempty" db:"hostname"`
	IPAddress           net.IP            `json:"ip_address" db:"ip_address"`
	MACAddress          *string           `json:"mac_address,omitempty" db:"mac_address"`
	DeviceType          string            `json:"device_type" db:"device_type"`
	Status              string            `json:"status" db:"status"`
	Vendor              *string           `json:"vendor,omitempty" db:"vendor"`
	Model               *string           `json:"model,omitempty" db:"model"`
	SerialNumber        *string           `json:"serial_number,omitempty" db:"serial_number"`
	OSVersion           *string           `json:"os_version,omitempty" db:"os_version"`
	FirmwareVersion     *string           `json:"firmware_version,omitempty" db:"firmware_version"`
	Location            *string           `json:"location,omitempty" db:"location"`
	Department          *string           `json:"department,omitempty" db:"department"`
	Notes               *string           `json:"notes,omitempty" db:"notes"`
	CustomFields        map[string]string `json:"custom_fields,omitempty" db:"custom_fields"`
	Building            string            `json:"building" db:"building"`
	FloorName           string            `json:"floor_name" db:"floor_name"`
	Room                string            `json:"room" db:"room"`
	ConnectionType      string            `json:"connection_type" db:"connection_type"`
	ConnectedInterface  string            `json:"connected_interface" db:"connected_interface"`
	ConnectedAP         string            `json:"connected_ap" db:"connected_ap"`
	ConnectedSwitch     string            `json:"connected_switch" db:"connected_switch"`
	SwitchPort          string            `json:"switch_port" db:"switch_port"`
	DHCPStatus          string            `json:"dhcp_status" db:"dhcp_status"`
	LeaseTimeSeconds    int               `json:"lease_time_seconds" db:"lease_time_seconds"`
	SignalStrengthDbm   int               `json:"signal_strength_dbm" db:"signal_strength_dbm"`
	CurrentDownloadSpeed int64            `json:"current_download_speed" db:"current_download_speed"`
	CurrentUploadSpeed   int64            `json:"current_upload_speed" db:"current_upload_speed"`
	TotalDownloadBytes  int64             `json:"total_download_bytes" db:"total_download_bytes"`
	TotalUploadBytes    int64             `json:"total_upload_bytes" db:"total_upload_bytes"`
	IsPinned            bool              `json:"is_pinned" db:"is_pinned"`
	IsCritical          bool              `json:"is_critical" db:"is_critical"`
	IsMonitored         bool              `json:"is_monitored" db:"is_monitored"`
	FirstSeen           time.Time         `json:"first_seen" db:"first_seen"`
	LastBoot            *time.Time        `json:"last_boot,omitempty" db:"last_boot"`
	LastSeen            time.Time         `json:"last_seen" db:"last_seen"`
	CreatedAt           time.Time         `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time         `json:"updated_at" db:"updated_at"`
}

type Interface struct {
	ID                    uuid.UUID  `json:"id" db:"id"`
	DeviceID              uuid.UUID  `json:"device_id" db:"device_id"`
	Name                  string     `json:"name" db:"name"`
	Description           *string    `json:"description,omitempty" db:"description"`
	MACAddress            *string    `json:"mac_address,omitempty" db:"mac_address"`
	IPAddress             *net.IP    `json:"ip_address,omitempty" db:"ip_address"`
	SubnetMask            *net.IP    `json:"subnet_mask,omitempty" db:"subnet_mask"`
	Gateway               *net.IP    `json:"gateway,omitempty" db:"gateway"`
	ConnectionType        string     `json:"connection_type" db:"connection_type"`
	IsUp                  bool       `json:"is_up" db:"is_up"`
	IsManagement          bool       `json:"is_management" db:"is_management"`
	MTU                   int        `json:"mtu" db:"mtu"`
	SpeedMbps             *float64   `json:"speed_mbps,omitempty" db:"speed_mbps"`
	Duplex                *string    `json:"duplex,omitempty" db:"duplex"`
	Index                 int        `json:"index" db:"index"`
	VlanID                *int       `json:"vlan_id,omitempty" db:"vlan_id"`
	BytesIn               int64      `json:"bytes_in" db:"bytes_in"`
	BytesOut              int64      `json:"bytes_out" db:"bytes_out"`
	ErrorsIn              int64      `json:"errors_in" db:"errors_in"`
	ErrorsOut             int64      `json:"errors_out" db:"errors_out"`
	UtilizationPercent    *float64   `json:"utilization_percent,omitempty" db:"utilization_percent"`
	LastStatusChange      *time.Time `json:"last_status_change,omitempty" db:"last_status_change"`
	CreatedAt             time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt             time.Time  `json:"updated_at" db:"updated_at"`
}

type Alert struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"organization_id"`
	Title           string     `json:"title" db:"title"`
	Description     *string    `json:"description,omitempty" db:"description"`
	Severity        string     `json:"severity" db:"severity"`
	Status          string     `json:"status" db:"status"`
	Category        string     `json:"category" db:"category"`
	DeviceID        *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	InterfaceID     *uuid.UUID `json:"interface_id,omitempty" db:"interface_id"`
	MetricName      *string    `json:"metric_name,omitempty" db:"metric_name"`
	MetricValue     *float64   `json:"metric_value,omitempty" db:"metric_value"`
	ThresholdValue  *float64   `json:"threshold_value,omitempty" db:"threshold_value"`
	AcknowledgedBy  *uuid.UUID `json:"acknowledged_by,omitempty" db:"acknowledged_by"`
	AcknowledgedAt  *time.Time `json:"acknowledged_at,omitempty" db:"acknowledged_at"`
	ResolvedBy      *uuid.UUID `json:"resolved_by,omitempty" db:"resolved_by"`
	ResolvedAt      *time.Time `json:"resolved_at,omitempty" db:"resolved_at"`
	ResolutionNotes *string    `json:"resolution_notes,omitempty" db:"resolution_notes"`
	OccurrenceCount int        `json:"occurrence_count" db:"occurrence_count"`
	DetectedAt      time.Time  `json:"detected_at" db:"detected_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

type NetworkScan struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"organization_id"`
	Type            string     `json:"type" db:"type"`
	Status          string     `json:"status" db:"status"`
	Name            *string    `json:"name,omitempty" db:"name"`
	TargetSubnet    string     `json:"target_subnet" db:"target_subnet"`
	InitiatedBy     *uuid.UUID `json:"initiated_by,omitempty" db:"initiated_by"`
	TotalHosts      int        `json:"total_hosts" db:"total_hosts"`
	DiscoveredHosts int        `json:"discovered_hosts" db:"discovered_hosts"`
	ActiveHosts     int        `json:"active_hosts" db:"active_hosts"`
	DurationSeconds *int       `json:"duration_seconds,omitempty" db:"duration_seconds"`
	Progress        *float64   `json:"progress,omitempty" db:"progress"`
	ErrorMessage    *string    `json:"error_message,omitempty" db:"error_message"`
	StartedAt       time.Time  `json:"started_at" db:"started_at"`
	CompletedAt     *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
}

type AuditLog struct {
	ID             uuid.UUID              `json:"id" db:"id"`
	OrganizationID uuid.UUID              `json:"organization_id" db:"organization_id"`
	Action         string                 `json:"action" db:"action"`
	EntityType     string                 `json:"entity_type" db:"entity_type"`
	EntityID       *uuid.UUID             `json:"entity_id,omitempty" db:"entity_id"`
	EntityName     *string                `json:"entity_name,omitempty" db:"entity_name"`
	PerformedBy    *uuid.UUID             `json:"performed_by,omitempty" db:"performed_by"`
	IPAddress      *net.IP                `json:"ip_address,omitempty" db:"ip_address"`
	UserAgent      *string                `json:"user_agent,omitempty" db:"user_agent"`
	PreviousValues map[string]interface{} `json:"previous_values,omitempty" db:"previous_values"`
	NewValues      map[string]interface{} `json:"new_values,omitempty" db:"new_values"`
	Description    *string                `json:"description,omitempty" db:"description"`
	IsSuccess      bool                   `json:"is_success" db:"is_success"`
	FailureReason  *string                `json:"failure_reason,omitempty" db:"failure_reason"`
	Timestamp      time.Time              `json:"timestamp" db:"timestamp"`
}

type DeviceMetrics struct {
	DeviceID            uuid.UUID  `json:"device_id" db:"device_id"`
	CPUUsagePercent     *float64   `json:"cpu_usage_percent,omitempty" db:"cpu_usage_percent"`
	MemoryUsagePercent  *float64   `json:"memory_usage_percent,omitempty" db:"memory_usage_percent"`
	DiskUsagePercent    *float64   `json:"disk_usage_percent,omitempty" db:"disk_usage_percent"`
	TemperatureCelsius  *float64   `json:"temperature_celsius,omitempty" db:"temperature_celsius"`
	UptimeSeconds       *int64     `json:"uptime_seconds,omitempty" db:"uptime_seconds"`
	TotalTrafficInBps   *int64     `json:"total_traffic_in_bps,omitempty" db:"total_traffic_in_bps"`
	TotalTrafficOutBps  *int64     `json:"total_traffic_out_bps,omitempty" db:"total_traffic_out_bps"`
	AverageLatencyMs    *float64   `json:"average_latency_ms,omitempty" db:"average_latency_ms"`
	MaxLatencyMs        *float64   `json:"max_latency_ms,omitempty" db:"max_latency_ms"`
	PacketLossPercent   *float64   `json:"packet_loss_percent,omitempty" db:"packet_loss_percent"`
	UploadSpeedBps      *int64     `json:"upload_speed_bps,omitempty" db:"upload_speed_bps"`
	DownloadSpeedBps    *int64     `json:"download_speed_bps,omitempty" db:"download_speed_bps"`
	SignalStrengthDbm   *int       `json:"signal_strength_dbm,omitempty" db:"signal_strength_dbm"`
	SignalQualityPercent *float64  `json:"signal_quality_percent,omitempty" db:"signal_quality_percent"`
	ConnectedAPID       *uuid.UUID `json:"connected_ap_id,omitempty" db:"connected_ap_id"`
	ConnectedSwitchID   *uuid.UUID `json:"connected_switch_id,omitempty" db:"connected_switch_id"`
	Timestamp           time.Time  `json:"timestamp" db:"timestamp"`
}

type DeviceClient struct {
	ID                  uuid.UUID  `json:"id" db:"id"`
	OrganizationID      uuid.UUID  `json:"organization_id" db:"organization_id"`
	DeviceID            uuid.UUID  `json:"device_id" db:"device_id"`
	MACAddress          string     `json:"mac_address" db:"mac_address"`
	IPAddress           *net.IP    `json:"ip_address,omitempty" db:"ip_address"`
	Hostname            *string    `json:"hostname,omitempty" db:"hostname"`
	Vendor              *string    `json:"vendor,omitempty" db:"vendor"`
	OSType              *string    `json:"os_type,omitempty" db:"os_type"`
	ConnectionType      string     `json:"connection_type" db:"connection_type"`
	SSID                *string    `json:"ssid,omitempty" db:"ssid"`
	BSSID               *string    `json:"bssid,omitempty" db:"bssid"`
	SignalStrengthDbm   *int       `json:"signal_strength_dbm,omitempty" db:"signal_strength_dbm"`
	SignalQualityPercent *float64  `json:"signal_quality_percent,omitempty" db:"signal_quality_percent"`
	Channel             *int       `json:"channel,omitempty" db:"channel"`
	FrequencyMHz        *int       `json:"frequency_mhz,omitempty" db:"frequency_mhz"`
	NoiseDbm            *int       `json:"noise_dbm,omitempty" db:"noise_dbm"`
	SnrDbm              *int       `json:"snr_dbm,omitempty" db:"snr_dbm"`
	TxRateMbps          *float64   `json:"tx_rate_mbps,omitempty" db:"tx_rate_mbps"`
	RxRateMbps          *float64   `json:"rx_rate_mbps,omitempty" db:"rx_rate_mbps"`
	TxBytes             int64      `json:"tx_bytes" db:"tx_bytes"`
	RxBytes             int64      `json:"rx_bytes" db:"rx_bytes"`
	TxPackets           int64      `json:"tx_packets" db:"tx_packets"`
	RxPackets           int64      `json:"rx_packets" db:"rx_packets"`
	TxErrors            int64      `json:"tx_errors" db:"tx_errors"`
	RxErrors            int64      `json:"rx_errors" db:"rx_errors"`
	ConnectedApID       *uuid.UUID `json:"connected_ap_id,omitempty" db:"connected_ap_id"`
	ConnectedSwitchID   *uuid.UUID `json:"connected_switch_id,omitempty" db:"connected_switch_id"`
	SwitchPort          *string    `json:"switch_port,omitempty" db:"switch_port"`
	VlanID              *int       `json:"vlan_id,omitempty" db:"vlan_id"`
	LeaseExpiresAt      *time.Time `json:"lease_expires_at,omitempty" db:"lease_expires_at"`
	IsActive            bool       `json:"is_active" db:"is_active"`
	FirstSeen           time.Time  `json:"first_seen" db:"first_seen"`
	LastSeen            time.Time  `json:"last_seen" db:"last_seen"`
	CreatedAt           time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time  `json:"updated_at" db:"updated_at"`
}

type DeviceTraffic struct {
	ID                uuid.UUID  `json:"id" db:"id"`
	DeviceID          uuid.UUID  `json:"device_id" db:"device_id"`
	InterfaceID       *uuid.UUID `json:"interface_id,omitempty" db:"interface_id"`
	UploadBps         int64      `json:"upload_bps" db:"upload_bps"`
	DownloadBps       int64      `json:"download_bps" db:"download_bps"`
	TotalUploadBytes  int64      `json:"total_upload_bytes" db:"total_upload_bytes"`
	TotalDownloadBytes int64     `json:"total_download_bytes" db:"total_download_bytes"`
	UploadPackets     int64      `json:"upload_packets" db:"upload_packets"`
	DownloadPackets   int64      `json:"download_packets" db:"download_packets"`
	UploadErrors      int64      `json:"upload_errors" db:"upload_errors"`
	DownloadErrors    int64      `json:"download_errors" db:"download_errors"`
	UploadDrops       int64      `json:"upload_drops" db:"upload_drops"`
	DownloadDrops     int64      `json:"download_drops" db:"download_drops"`
	UtilizationPercent *float64  `json:"utilization_percent,omitempty" db:"utilization_percent"`
	Timestamp         time.Time  `json:"timestamp" db:"timestamp"`
}

type DevicePing struct {
	ID               uuid.UUID `json:"id" db:"id"`
	DeviceID         uuid.UUID `json:"device_id" db:"device_id"`
	MinRttMs         *float64  `json:"min_rtt_ms,omitempty" db:"min_rtt_ms"`
	MaxRttMs         *float64  `json:"max_rtt_ms,omitempty" db:"max_rtt_ms"`
	AvgRttMs         *float64  `json:"avg_rtt_ms,omitempty" db:"avg_rtt_ms"`
	MedianRttMs      *float64  `json:"median_rtt_ms,omitempty" db:"median_rtt_ms"`
	StddevRttMs      *float64  `json:"stddev_rtt_ms,omitempty" db:"stddev_rtt_ms"`
	JitterMs         *float64  `json:"jitter_ms,omitempty" db:"jitter_ms"`
	PacketLossPercent float64  `json:"packet_loss_percent" db:"packet_loss_percent"`
	PacketsSent      int       `json:"packets_sent" db:"packets_sent"`
	PacketsReceived  int       `json:"packets_received" db:"packets_received"`
	PacketsLost      int       `json:"packets_lost" db:"packets_lost"`
	IsReachable      bool      `json:"is_reachable" db:"is_reachable"`
	Timestamp        time.Time `json:"timestamp" db:"timestamp"`
}

type DeviceConnection struct {
	ID                uuid.UUID  `json:"id" db:"id"`
	OrganizationID    uuid.UUID  `json:"organization_id" db:"organization_id"`
	ParentDeviceID    uuid.UUID  `json:"parent_device_id" db:"parent_device_id"`
	ChildDeviceID     uuid.UUID  `json:"child_device_id" db:"child_device_id"`
	ParentInterfaceID *uuid.UUID `json:"parent_interface_id,omitempty" db:"parent_interface_id"`
	ChildInterfaceID  *uuid.UUID `json:"child_interface_id,omitempty" db:"child_interface_id"`
	ConnectionType    string     `json:"connection_type" db:"connection_type"`
	Medium            string     `json:"medium" db:"medium"`
	SpeedMbps         *float64   `json:"speed_mbps,omitempty" db:"speed_mbps"`
	VlanID            *int       `json:"vlan_id,omitempty" db:"vlan_id"`
	IsActive          bool       `json:"is_active" db:"is_active"`
	DiscoveredMethod  string     `json:"discovered_method" db:"discovered_method"`
	DiscoveredAt      time.Time  `json:"discovered_at" db:"discovered_at"`
	LastSeen          time.Time  `json:"last_seen" db:"last_seen"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
}

type DeviceSpeedTest struct {
	ID                  uuid.UUID `json:"id" db:"id"`
	DeviceID            uuid.UUID `json:"device_id" db:"device_id"`
	UploadSpeedMbps     *float64  `json:"upload_speed_mbps,omitempty" db:"upload_speed_mbps"`
	DownloadSpeedMbps   *float64  `json:"download_speed_mbps,omitempty" db:"download_speed_mbps"`
	LatencyMs           *float64  `json:"latency_ms,omitempty" db:"latency_ms"`
	JitterMs            *float64  `json:"jitter_ms,omitempty" db:"jitter_ms"`
	PacketLossPercent   *float64  `json:"packet_loss_percent,omitempty" db:"packet_loss_percent"`
	TestServer          *string   `json:"test_server,omitempty" db:"test_server"`
	TestDurationSeconds *int      `json:"test_duration_seconds,omitempty" db:"test_duration_seconds"`
	Timestamp           time.Time `json:"timestamp" db:"timestamp"`
}

type ScanResult struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	ScanID        uuid.UUID  `json:"scan_id" db:"scan_id"`
	IPAddress     net.IP     `json:"ip_address" db:"ip_address"`
	Hostname      *string    `json:"hostname,omitempty" db:"hostname"`
	MACAddress    *string    `json:"mac_address,omitempty" db:"mac_address"`
	Vendor        *string    `json:"vendor,omitempty" db:"vendor"`
	OpenPorts     []int      `json:"open_ports,omitempty" db:"open_ports"`
	OSGuess       *string    `json:"os_guess,omitempty" db:"os_guess"`
	ResponseTimeMs *float64  `json:"response_time_ms,omitempty" db:"response_time_ms"`
	IsAlive       bool       `json:"is_alive" db:"is_alive"`
	IsNewDevice   bool       `json:"is_new_device" db:"is_new_device"`
	DiscoveredAt  time.Time  `json:"discovered_at" db:"discovered_at"`
}

type ScanResultDevice struct {
	ScanResult
	DeviceID      *uuid.UUID `json:"device_id,omitempty"`
	DeviceName    *string    `json:"device_name,omitempty"`
	OnlineStatus  *string    `json:"online_status,omitempty"`
}

type DashboardLiveSummary struct {
	TotalDevices       int     `json:"total_devices"`
	OnlineDevices      int     `json:"online_devices"`
	OfflineDevices     int     `json:"offline_devices"`
	DegradedDevices    int     `json:"degraded_devices"`
	TotalClients       int     `json:"total_clients"`
	ActiveClients      int     `json:"active_clients"`
	CriticalAlerts     int     `json:"critical_alerts"`
	OpenAlerts         int     `json:"open_alerts"`
	AverageCPU         *float64 `json:"average_cpu,omitempty"`
	AverageMemory      *float64 `json:"average_memory,omitempty"`
	AverageLatency     *float64 `json:"average_latency,omitempty"`
	AveragePacketLoss  *float64 `json:"average_packet_loss,omitempty"`
	TotalUploadBps     int64    `json:"total_upload_bps"`
	TotalDownloadBps   int64    `json:"total_download_bps"`
	DevicesByType      map[string]int `json:"devices_by_type"`
	DevicesByStatus    map[string]int `json:"devices_by_status"`
	UpdatedAt          time.Time `json:"updated_at"`
}
