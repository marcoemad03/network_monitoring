package models

import (
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/pkg/mikrotik"
)

type DeviceControlLog struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	OrganizationID uuid.UUID  `json:"organization_id" db:"organization_id"`
	DeviceID       uuid.UUID  `json:"device_id" db:"device_id"`
	Action         string     `json:"action" db:"action"`
	ActionDetail   string     `json:"action_detail" db:"action_detail"`
	PerformedBy    *uuid.UUID `json:"performed_by,omitempty" db:"performed_by"`
	Result         string     `json:"result" db:"result"`
	ErrorMessage   *string    `json:"error_message,omitempty" db:"error_message"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
}

type DeviceEvent struct {
	ID             uuid.UUID              `json:"id" db:"id"`
	OrganizationID uuid.UUID              `json:"organization_id" db:"organization_id"`
	DeviceID       uuid.UUID              `json:"device_id" db:"device_id"`
	EventType      string                 `json:"event_type" db:"event_type"`
	EventData      map[string]interface{} `json:"event_data,omitempty" db:"event_data"`
	PreviousValue  string                 `json:"previous_value,omitempty" db:"previous_value"`
	NewValue       string                 `json:"new_value,omitempty" db:"new_value"`
	CreatedAt      time.Time              `json:"created_at" db:"created_at"`
}

type DeviceEventSummary struct {
	TotalEvents int                    `json:"total_events"`
	ByType      map[string]int         `json:"by_type"`
	FirstEvent  *time.Time             `json:"first_event,omitempty"`
	LastEvent   *time.Time             `json:"last_event,omitempty"`
}

type DeviceInventory struct {
	ID                   uuid.UUID  `json:"id" db:"id"`
	DeviceID             uuid.UUID  `json:"device_id" db:"device_id"`
	Building             string     `json:"building" db:"building"`
	Floor                string     `json:"floor" db:"floor"`
	Room                 string     `json:"room" db:"room"`
	ConnectionType       string     `json:"connection_type" db:"connection_type"`
	ConnectedInterface   string     `json:"connected_interface" db:"connected_interface"`
	ConnectedAP          string     `json:"connected_ap" db:"connected_ap"`
	ConnectedSwitch      string     `json:"connected_switch" db:"connected_switch"`
	SwitchPort           string     `json:"switch_port" db:"switch_port"`
	DHCPStatus           string     `json:"dhcp_status" db:"dhcp_status"`
	LeaseTimeSeconds     int        `json:"lease_time_seconds" db:"lease_time_seconds"`
	SignalStrengthDbm    int        `json:"signal_strength_dbm" db:"signal_strength_dbm"`
	CurrentDownloadSpeed int64      `json:"current_download_speed" db:"current_download_speed"`
	CurrentUploadSpeed   int64      `json:"current_upload_speed" db:"current_upload_speed"`
	TotalDownloadBytes   int64      `json:"total_download_bytes" db:"total_download_bytes"`
	TotalUploadBytes     int64      `json:"total_upload_bytes" db:"total_upload_bytes"`
	IsPinned             bool       `json:"is_pinned" db:"is_pinned"`
	IsCritical           bool       `json:"is_critical" db:"is_critical"`
	CreatedAt            time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt            time.Time  `json:"updated_at" db:"updated_at"`
}

type MikroTikSyncState struct {
	ID                 uuid.UUID  `json:"id" db:"id"`
	OrganizationID     uuid.UUID  `json:"organization_id" db:"organization_id"`
	VendorIntegrationID uuid.UUID `json:"vendor_integration_id" db:"vendor_integration_id"`
	LastDHCPSync       *time.Time `json:"last_dhcp_sync,omitempty" db:"last_dhcp_sync"`
	LastARPSync        *time.Time `json:"last_arp_sync,omitempty" db:"last_arp_sync"`
	LastWirelessSync   *time.Time `json:"last_wireless_sync,omitempty" db:"last_wireless_sync"`
	LastBridgeSync     *time.Time `json:"last_bridge_sync,omitempty" db:"last_bridge_sync"`
	LastInterfaceSync  *time.Time `json:"last_interface_sync,omitempty" db:"last_interface_sync"`
	LastQueueSync      *time.Time `json:"last_queue_sync,omitempty" db:"last_queue_sync"`
	LastFirewallSync   *time.Time `json:"last_firewall_sync,omitempty" db:"last_firewall_sync"`
	LastDNSSync        *time.Time `json:"last_dns_sync,omitempty" db:"last_dns_sync"`
	RouterOSVersion    string     `json:"routeros_version" db:"routeros_version"`
	TotalDevicesSynced int        `json:"total_devices_synced" db:"total_devices_synced"`
	Status             string     `json:"status" db:"status"`
	ErrorMessage       *string    `json:"error_message,omitempty" db:"error_message"`
	CreatedAt          time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt          time.Time  `json:"updated_at" db:"updated_at"`
}

type DeviceListView struct {
	Device
	Building           string   `json:"building"`
	Floor              string   `json:"floor"`
	Room               string   `json:"room"`
	ConnectionType     string   `json:"connection_type"`
	ConnectedInterface string   `json:"connected_interface"`
	ConnectedAP        string   `json:"connected_ap"`
	ConnectedSwitch    string   `json:"connected_switch"`
	SwitchPort         string   `json:"switch_port"`
	DHCPStatus         string   `json:"dhcp_status"`
	LeaseTimeSeconds   int      `json:"lease_time_seconds"`
	SignalStrengthDbm  int      `json:"signal_strength_dbm"`
	CurrentDownloadSpeed int64  `json:"current_download_speed"`
	CurrentUploadSpeed   int64  `json:"current_upload_speed"`
	TotalDownloadBytes int64    `json:"total_download_bytes"`
	TotalUploadBytes   int64    `json:"total_upload_bytes"`
	IsPinned           bool     `json:"is_pinned"`
	IsCritical         bool     `json:"is_critical"`
	GroupNames         []string `json:"group_names,omitempty"`
}

type EnhancedDashboardSummary struct {
	DashboardLiveSummary
	Subnet172Count     int              `json:"subnet_172_count"`
	WiFiCount          int              `json:"wifi_count"`
	LANCount           int              `json:"lan_count"`
	TopDownload        []TopBandwidth   `json:"top_download"`
	TopUpload          []TopBandwidth   `json:"top_upload"`
	TopActive          []TopActiveDevice `json:"top_active"`
	BlockedRequests    int64            `json:"blocked_requests"`
	PolicyViolations   int              `json:"policy_violations"`
	RouterCPU          *float64         `json:"router_cpu,omitempty"`
	RouterRAM          *float64         `json:"router_ram,omitempty"`
	Interfaces         []InterfaceBrief `json:"interfaces,omitempty"`
	MostVisitedDomains []DomainStat     `json:"most_visited_domains,omitempty"`
}

type TopBandwidth struct {
	DeviceID   uuid.UUID `json:"device_id"`
	DeviceName string    `json:"device_name"`
	MACAddress string    `json:"mac_address"`
	Bandwidth  int64     `json:"bandwidth"`
}

type TopActiveDevice struct {
	DeviceID   uuid.UUID `json:"device_id"`
	DeviceName string    `json:"device_name"`
	MACAddress string    `json:"mac_address"`
	SessionCount int     `json:"session_count"`
}

type InterfaceBrief struct {
	Name      string  `json:"name"`
	Type      string  `json:"type"`
	MAC       string  `json:"mac"`
	Speed     string  `json:"speed"`
	Running   bool    `json:"running"`
	RxBytes   int64   `json:"rx_bytes"`
	TxBytes   int64   `json:"tx_bytes"`
	RxErrors  int64   `json:"rx_errors"`
	TxErrors  int64   `json:"tx_errors"`
}

type DomainStat struct {
	Domain  string `json:"domain"`
	Visits  int    `json:"visits"`
	Bytes   int64  `json:"bytes"`
	Blocked bool   `json:"blocked"`
}

type MikroTikClientWrapper struct {
	*mikrotik.Client
}

func NewMikroTikClientWrapper(host, username, password string) *MikroTikClientWrapper {
	return &MikroTikClientWrapper{
		Client: mikrotik.NewClient(host, username, password, 30*time.Second),
	}
}
