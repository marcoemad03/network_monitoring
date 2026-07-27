package models

import "time"

type RouterConnectionStatus struct {
	Code          string    `json:"code"`
	Message       string    `json:"message"`
	Reachable     bool      `json:"reachable"`
	APIEndpoint   string    `json:"api_endpoint,omitempty"`
	RouterName    string    `json:"router_name,omitempty"`
	RouterVersion string    `json:"router_version,omitempty"`
	CheckedAt     time.Time `json:"checked_at"`
}

type ConnectedDeviceView struct {
	ID                   string    `json:"id"`
	DeviceID             string    `json:"device_id,omitempty"`
	DeviceName           string    `json:"device_name"`
	Hostname             string    `json:"hostname,omitempty"`
	IPAddress            string    `json:"ip_address"`
	MACAddress           string    `json:"mac_address"`
	Vendor               string    `json:"vendor,omitempty"`
	DeviceType           string    `json:"device_type"`
	IsOnline             bool      `json:"is_online"`
	ConnectionType       string    `json:"connection_type"`
	ConnectedAccessPoint string    `json:"connected_access_point,omitempty"`
	InterfaceName        string    `json:"interface_name,omitempty"`
	CurrentUploadMbps    *float64  `json:"current_upload_mbps,omitempty"`
	CurrentDownloadMbps  *float64  `json:"current_download_mbps,omitempty"`
	SignalStrengthDbm    *int      `json:"signal_strength_dbm,omitempty"`
	Department           string    `json:"department,omitempty"`
	Room                 string    `json:"room,omitempty"`
	Notes                string    `json:"notes,omitempty"`
	LastSeen             time.Time `json:"last_seen"`
}

type ConnectedDevicesResult struct {
	Connection RouterConnectionStatus `json:"connection"`
	Devices    []ConnectedDeviceView  `json:"devices"`
}
