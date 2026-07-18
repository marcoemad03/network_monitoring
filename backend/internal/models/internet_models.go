package models

import (
	"time"

	"github.com/google/uuid"
)

type InternetPolicy struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	Name            string     `json:"name" db:"name"`
	Description     *string    `json:"description,omitempty" db:"description"`
	Department      *string    `json:"department,omitempty" db:"department"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	UploadLimitBps  *int64     `json:"upload_limit_bps,omitempty" db:"upload_limit_bps"`
	DownloadLimitBps *int64    `json:"download_limit_bps,omitempty" db:"download_limit_bps"`
	PolicyType      string     `json:"policy_type" db:"policy_type"`
	Priority        int        `json:"priority" db:"priority"`
	CreatedBy       *uuid.UUID `json:"created_by,omitempty" db:"created_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

type BandwidthRule struct {
	ID               uuid.UUID  `json:"id" db:"id"`
	PolicyID         uuid.UUID  `json:"policy_id" db:"policy_id"`
	DeviceID         *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	UserID           *uuid.UUID `json:"user_id,omitempty" db:"user_id"`
	Priority         int        `json:"priority" db:"priority"`
	UploadLimitBps   *int64     `json:"upload_limit_bps,omitempty" db:"upload_limit_bps"`
	DownloadLimitBps *int64     `json:"download_limit_bps,omitempty" db:"download_limit_bps"`
	RuleType         string     `json:"rule_type" db:"rule_type"`
	IsTemporary      bool       `json:"is_temporary" db:"is_temporary"`
	TempExpiresAt    *time.Time `json:"temp_expires_at,omitempty" db:"temp_expires_at"`
	IsActive         bool       `json:"is_active" db:"is_active"`
	CreatedAt        time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt        time.Time  `json:"updated_at" db:"updated_at"`
}

type FilteringRule struct {
	ID          uuid.UUID `json:"id" db:"id"`
	PolicyID    uuid.UUID `json:"policy_id" db:"policy_id"`
	RuleType    string    `json:"rule_type" db:"rule_type"`
	FilterType  string    `json:"filter_type" db:"filter_type"`
	Value       string    `json:"value" db:"value"`
	Description *string   `json:"description,omitempty" db:"description"`
	IsActive    bool      `json:"is_active" db:"is_active"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

type TimeSchedule struct {
	ID        uuid.UUID `json:"id" db:"id"`
	PolicyID  uuid.UUID `json:"policy_id" db:"policy_id"`
	DayOfWeek int       `json:"day_of_week" db:"day_of_week"`
	StartTime string    `json:"start_time" db:"start_time"`
	EndTime   string    `json:"end_time" db:"end_time"`
	IsActive  bool      `json:"is_active" db:"is_active"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
	UpdatedAt time.Time `json:"updated_at" db:"updated_at"`
}

type DeviceBlock struct {
	ID          uuid.UUID  `json:"id" db:"id"`
	OrgID       uuid.UUID  `json:"organization_id" db:"org_id"`
	DeviceID    *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	MACAddress  *string    `json:"mac_address,omitempty" db:"mac_address"`
	IPAddress   *string    `json:"ip_address,omitempty" db:"ip_address"`
	Reason      *string    `json:"reason,omitempty" db:"reason"`
	BlockedBy   *uuid.UUID `json:"blocked_by,omitempty" db:"blocked_by"`
	BlockedAt   time.Time  `json:"blocked_at" db:"blocked_at"`
	UnblockedAt *time.Time `json:"unblocked_at,omitempty" db:"unblocked_at"`
	IsActive    bool       `json:"is_active" db:"is_active"`
	CreatedAt   time.Time  `json:"created_at" db:"created_at"`
}

type VendorIntegration struct {
	ID                uuid.UUID  `json:"id" db:"id"`
	OrgID             uuid.UUID  `json:"organization_id" db:"org_id"`
	VendorType        string     `json:"vendor_type" db:"vendor_type"`
	Name              string     `json:"name" db:"name"`
	BaseURL           string     `json:"base_url" db:"base_url"`
	Username          *string    `json:"username,omitempty" db:"username"`
	EncryptedPassword *string    `json:"-" db:"encrypted_password"`
	APIKey            *string    `json:"-" db:"api_key"`
	APIVersion        *string    `json:"api_version,omitempty" db:"api_version"`
	IsActive          bool       `json:"is_active" db:"is_active"`
	LastSyncAt        *time.Time `json:"last_sync_at,omitempty" db:"last_sync_at"`
	LastSyncStatus    *string    `json:"last_sync_status,omitempty" db:"last_sync_status"`
	ErrorMessage      *string    `json:"error_message,omitempty" db:"error_message"`
	CreatedAt         time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time  `json:"updated_at" db:"updated_at"`
}
