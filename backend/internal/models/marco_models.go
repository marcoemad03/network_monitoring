package models

import (
	"encoding/json"
	"net"
	"time"

	"github.com/google/uuid"
)

// MarcoGroupPolicy is the typed policy attached to a Marco group.
// All limits are expressed in Mbps (matching the UI); the sync engine
// converts them to bps for RouterOS.
type MarcoGroupPolicy struct {
	InternetEnabled            *bool     `json:"internet_enabled,omitempty"`
	UnlimitedSpeed             *bool     `json:"unlimited_speed,omitempty"`
	DownloadLimitMbps          *float64  `json:"download_limit_mbps,omitempty"`
	UploadLimitMbps            *float64  `json:"upload_limit_mbps,omitempty"`
	BurstDownloadMbps          *float64  `json:"burst_download_mbps,omitempty"`
	BurstUploadMbps            *float64  `json:"burst_upload_mbps,omitempty"`
	BurstThresholdDownloadMbps *float64  `json:"burst_threshold_download_mbps,omitempty"`
	BurstThresholdUploadMbps   *float64  `json:"burst_threshold_upload_mbps,omitempty"`
	BurstTimeSeconds           *int      `json:"burst_time_seconds,omitempty"`
	QosPriority                *int      `json:"qos_priority,omitempty"`
	DailyQuotaGb               *float64  `json:"daily_quota_gb,omitempty"`
	MonthlyQuotaGb             *float64  `json:"monthly_quota_gb,omitempty"`
	ScheduleStartTime          *string   `json:"schedule_start_time,omitempty"`
	ScheduleEndTime            *string   `json:"schedule_end_time,omitempty"`
	ScheduleDays               []string  `json:"schedule_days,omitempty"`
	BlockedWebsites            []string  `json:"blocked_websites,omitempty"`
	// BlockedPacks are ready-made sets of sites (games, social, ...) and
	// BlockedDomains are sites typed in by hand.
	BlockedPacks   []string `json:"blocked_packs,omitempty"`
	BlockedDomains []string `json:"blocked_domains,omitempty"`
}

type MarcoGroup struct {
	ID             uuid.UUID         `json:"id" db:"id"`
	OrganizationID uuid.UUID         `json:"organization_id" db:"organization_id"`
	Name           string            `json:"name" db:"name"`
	Description    *string           `json:"description,omitempty" db:"description"`
	Color          string            `json:"color" db:"color"`
	Icon           string            `json:"icon" db:"icon"`
	Policy         MarcoGroupPolicy  `json:"policy" db:"policy"`
	CreatedAt      time.Time         `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time         `json:"updated_at" db:"updated_at"`
}

type MarcoGroupMember struct {
	ID        uuid.UUID `json:"id" db:"id"`
	GroupID   uuid.UUID `json:"group_id" db:"group_id"`
	DeviceID  uuid.UUID `json:"device_id" db:"device_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`

	// Joined device info (populated by list queries).
	DeviceName string  `json:"device_name,omitempty" db:"device_name"`
	Hostname   *string `json:"hostname,omitempty" db:"hostname"`
	MACAddress *string `json:"mac_address,omitempty" db:"mac_address"`
	IPAddress  net.IP  `json:"ip_address,omitempty" db:"ip_address"`
	IsOnline   bool    `json:"is_online,omitempty" db:"is_online"`
}

type MarcoGroupView struct {
	MarcoGroup
	Members      []MarcoGroupMember `json:"members"`
	MemberCount  int                `json:"member_count"`
	SyncStatus   string             `json:"sync_status,omitempty"`
	SyncMessage  string             `json:"sync_message,omitempty"`
	QuotaUsedGB  float64            `json:"quota_used_gb,omitempty"`
	QuotaPeriod  string             `json:"quota_period,omitempty"`
}

type MarcoPolicyLog struct {
	ID             uuid.UUID `json:"id" db:"id"`
	OrganizationID uuid.UUID `json:"organization_id" db:"organization_id"`
	GroupID        *uuid.UUID `json:"group_id,omitempty" db:"group_id"`
	DeviceID       *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	Action         string    `json:"action" db:"action"`
	Message        string    `json:"message" db:"message"`
	Status         string    `json:"status" db:"status"`
	RouterError    *string   `json:"router_error,omitempty" db:"router_error"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
}

type MarcoQuotaUsage struct {
	ID             uuid.UUID `json:"id" db:"id"`
	OrganizationID uuid.UUID `json:"organization_id" db:"organization_id"`
	DeviceID       uuid.UUID `json:"device_id" db:"device_id"`
	GroupID        uuid.UUID `json:"group_id" db:"group_id"`
	PeriodType     string    `json:"period_type" db:"period_type"`
	PeriodKey      string    `json:"period_key" db:"period_key"`
	BytesUsed      int64     `json:"bytes_used" db:"bytes_used"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

// MarcoDeviceStatus is the per-device policy status used by the UI badges.
// status: "allowed" | "blocked" | "limited"
type MarcoDeviceStatus struct {
	DeviceID       string    `json:"device_id"`
	MACAddress     string    `json:"mac_address"`
	DeviceName     string    `json:"device_name"`
	IPAddress      string    `json:"ip_address"`
	IsOnline       bool      `json:"is_online"`
	GroupID        *uuid.UUID `json:"group_id,omitempty"`
	GroupName      string    `json:"group_name,omitempty"`
	GroupColor     string    `json:"group_color,omitempty"`
	Status         string    `json:"status"`
	InternetEnabled bool     `json:"internet_enabled"`
	DownloadLimitMbps *float64 `json:"download_limit_mbps,omitempty"`
	UploadLimitMbps   *float64 `json:"upload_limit_mbps,omitempty"`
	BlockedWebsites   []string `json:"blocked_websites,omitempty"`
	QuotaUsedGB       float64  `json:"quota_used_gb,omitempty"`
	DailyQuotaGB      *float64 `json:"daily_quota_gb,omitempty"`
	MonthlyQuotaGB    *float64 `json:"monthly_quota_gb,omitempty"`
	ScheduleStart     string   `json:"schedule_start,omitempty"`
	ScheduleEnd       string   `json:"schedule_end,omitempty"`
}

// MarcoDeviceOverride is a block or speed limit set on one device, whatever group it is in.
type MarcoDeviceOverride struct {
	MAC               string    `json:"mac"`
	Blocked           bool      `json:"blocked"`
	DownloadLimitMbps *float64  `json:"download_limit_mbps,omitempty"`
	UploadLimitMbps   *float64  `json:"upload_limit_mbps,omitempty"`
	Reason            string    `json:"reason"`
	UpdatedAt         time.Time `json:"updated_at"`
}

// PlatformDefinition describes a blockable website platform.
type PlatformDefinition struct {
	Key      string   `json:"key"`
	Label    string   `json:"label"`
	Domains  []string `json:"domains"`
	IPRanges []string `json:"ip_ranges,omitempty"`
}

func (p *MarcoGroupPolicy) MarshalJSON() ([]byte, error) {
	type alias MarcoGroupPolicy
	return json.Marshal((*alias)(p))
}

func (p *MarcoGroupPolicy) UnmarshalJSON(data []byte) error {
	type alias MarcoGroupPolicy
	var a alias
	if err := json.Unmarshal(data, &a); err != nil {
		return err
	}
	*p = MarcoGroupPolicy(a)
	return nil
}
