package models

import (
	"time"

	"github.com/google/uuid"
)

type WebLog struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	DeviceID        *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	UserID          *uuid.UUID `json:"user_id,omitempty" db:"user_id"`
	URL             string     `json:"url" db:"url"`
	Domain          *string    `json:"domain,omitempty" db:"domain"`
	Category        *string    `json:"category,omitempty" db:"category"`
	Timestamp       time.Time  `json:"timestamp" db:"timestamp"`
	DurationSeconds int        `json:"duration_seconds" db:"duration_seconds"`
	BytesSent       int64      `json:"bytes_sent" db:"bytes_sent"`
	BytesReceived   int64      `json:"bytes_received" db:"bytes_received"`
	IsBlocked       bool       `json:"is_blocked" db:"is_blocked"`
	BlockedBy       *string    `json:"blocked_by,omitempty" db:"blocked_by"`
	IsEncrypted     bool       `json:"is_encrypted" db:"is_encrypted"`
	Protocol        string     `json:"protocol" db:"protocol"`
	Method          string     `json:"method" db:"method"`
	ContentType     *string    `json:"content_type,omitempty" db:"content_type"`
	StatusCode      int        `json:"status_code" db:"status_code"`
	UserAgent       *string    `json:"user_agent,omitempty" db:"user_agent"`
	DeviceName      *string    `json:"device_name,omitempty" db:"device_name"`
	Department      *string    `json:"department,omitempty" db:"department"`
}

type ConnectionLog struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	DeviceID        *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	UserID          *uuid.UUID `json:"user_id,omitempty" db:"user_id"`
	Protocol        *string    `json:"protocol,omitempty" db:"protocol"`
	SourceIP        string     `json:"source_ip" db:"source_ip"`
	DestIP          string     `json:"dest_ip" db:"dest_ip"`
	SourcePort      *int       `json:"source_port,omitempty" db:"source_port"`
	DestPort        *int       `json:"dest_port,omitempty" db:"dest_port"`
	BytesSent       int64      `json:"bytes_sent" db:"bytes_sent"`
	BytesReceived   int64      `json:"bytes_received" db:"bytes_received"`
	PacketsSent     int        `json:"packets_sent" db:"packets_sent"`
	PacketsReceived int        `json:"packets_received" db:"packets_received"`
	StartTime       time.Time  `json:"start_time" db:"start_time"`
	EndTime         *time.Time `json:"end_time,omitempty" db:"end_time"`
	DurationSeconds int        `json:"duration_seconds" db:"duration_seconds"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	Application     *string    `json:"application,omitempty" db:"application"`
	Department      *string    `json:"department,omitempty" db:"department"`
	DeviceName      *string    `json:"device_name,omitempty" db:"device_name"`
}

type DownloadLog struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	DeviceID        *uuid.UUID `json:"device_id,omitempty" db:"device_id"`
	UserID          *uuid.UUID `json:"user_id,omitempty" db:"user_id"`
	Filename        string     `json:"filename" db:"filename"`
	URL             *string    `json:"url,omitempty" db:"url"`
	SizeBytes       int64      `json:"size_bytes" db:"size_bytes"`
	Protocol        string     `json:"protocol" db:"protocol"`
	MimeType        *string    `json:"mime_type,omitempty" db:"mime_type"`
	StartTime       time.Time  `json:"start_time" db:"start_time"`
	EndTime         *time.Time `json:"end_time,omitempty" db:"end_time"`
	DurationSeconds int        `json:"duration_seconds" db:"duration_seconds"`
	Status          string     `json:"status" db:"status"`
	IsAllowed       bool       `json:"is_allowed" db:"is_allowed"`
	BlockedBy       *string    `json:"blocked_by,omitempty" db:"blocked_by"`
	DeviceName      *string    `json:"device_name,omitempty" db:"device_name"`
	Department      *string    `json:"department,omitempty" db:"department"`
}

type ReportCache struct {
	ID                   uuid.UUID `json:"id" db:"id"`
	OrganizationID       uuid.UUID `json:"organization_id" db:"org_id"`
	ReportType           string    `json:"report_type" db:"report_type"`
	PeriodStart          time.Time `json:"period_start" db:"period_start"`
	PeriodEnd            time.Time `json:"period_end" db:"period_end"`
	Data                 string    `json:"data" db:"data"`
	TotalWebsites        int       `json:"total_websites" db:"total_websites"`
	TotalBandwidthMB     int64     `json:"total_bandwidth_mb" db:"total_bandwidth_mb"`
	TotalDurationMinutes int       `json:"total_duration_minutes" db:"total_duration_minutes"`
	UniqueDevices        int       `json:"unique_devices" db:"unique_devices"`
	UniqueUsers          int       `json:"unique_users" db:"unique_users"`
	BlockedAttempts      int       `json:"blocked_attempts" db:"blocked_attempts"`
	GeneratedAt          time.Time `json:"generated_at" db:"generated_at"`
}

type ReportExport struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	OrganizationID uuid.UUID  `json:"organization_id" db:"org_id"`
	ReportType     string     `json:"report_type" db:"report_type"`
	PeriodStart    time.Time  `json:"period_start" db:"period_start"`
	PeriodEnd      time.Time  `json:"period_end" db:"period_end"`
	Format         string     `json:"format" db:"format"`
	FilePath       *string    `json:"file_path,omitempty" db:"file_path"`
	FileSizeBytes  int        `json:"file_size_bytes" db:"file_size_bytes"`
	Status         string     `json:"status" db:"status"`
	GeneratedBy    *uuid.UUID `json:"generated_by,omitempty" db:"generated_by"`
	GeneratedAt    *time.Time `json:"generated_at,omitempty" db:"generated_at"`
	ExpiresAt      *time.Time `json:"expires_at,omitempty" db:"expires_at"`
}

type AlertRule struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	Name            string     `json:"name" db:"name"`
	Description     *string    `json:"description,omitempty" db:"description"`
	Metric          string     `json:"metric" db:"metric"`
	Condition       string     `json:"condition" db:"condition"`
	Threshold       float64    `json:"threshold" db:"threshold"`
	DurationMinutes int        `json:"duration_minutes" db:"duration_minutes"`
	Severity        string     `json:"severity" db:"severity"`
	Channels        []string   `json:"channels" db:"channels"`
	IsActive        bool       `json:"is_active" db:"is_active"`
	NotifyRoles     []string   `json:"notify_roles,omitempty" db:"notify_roles"`
	CooldownMinutes int        `json:"cooldown_minutes" db:"cooldown_minutes"`
	LastTriggeredAt *time.Time `json:"last_triggered_at,omitempty" db:"last_triggered_at"`
	CreatedBy       *uuid.UUID `json:"created_by,omitempty" db:"created_by"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

type AlertNotification struct {
	ID              uuid.UUID  `json:"id" db:"id"`
	OrganizationID  uuid.UUID  `json:"organization_id" db:"org_id"`
	RuleID          *uuid.UUID `json:"rule_id,omitempty" db:"rule_id"`
	Title           string     `json:"title" db:"title"`
	Message         string     `json:"message" db:"message"`
	Severity        string     `json:"severity" db:"severity"`
	MetricName      *string    `json:"metric_name,omitempty" db:"metric_name"`
	MetricValue     *float64   `json:"metric_value,omitempty" db:"metric_value"`
	Threshold       *float64   `json:"threshold,omitempty" db:"threshold"`
	TriggeredAt     time.Time  `json:"triggered_at" db:"triggered_at"`
	AcknowledgedAt  *time.Time `json:"acknowledged_at,omitempty" db:"acknowledged_at"`
	AcknowledgedBy  *uuid.UUID `json:"acknowledged_by,omitempty" db:"acknowledged_by"`
	IsRead          bool       `json:"is_read" db:"is_read"`
	Channel         string     `json:"channel" db:"channel"`
}

type DashboardWidget struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	OrganizationID uuid.UUID  `json:"organization_id" db:"org_id"`
	UserID         *uuid.UUID `json:"user_id,omitempty" db:"user_id"`
	WidgetType     string     `json:"widget_type" db:"widget_type"`
	Title          string     `json:"title" db:"title"`
	Config         string     `json:"config" db:"config"`
	Position       int        `json:"position" db:"position"`
	Width          int        `json:"width" db:"width"`
	Height         int        `json:"height" db:"height"`
	IsVisible      bool       `json:"is_visible" db:"is_visible"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

type TopWebsite struct {
	Domain       string `json:"domain"`
	VisitCount   int    `json:"visit_count"`
	TotalBytes   int64  `json:"total_bytes"`
	TotalSeconds int    `json:"total_seconds"`
}

type TopUser struct {
	UserID       uuid.UUID `json:"user_id"`
	DisplayName  string    `json:"display_name"`
	VisitCount   int       `json:"visit_count"`
	TotalBytes   int64     `json:"total_bytes"`
	TotalSeconds int       `json:"total_seconds"`
}

type TopBandwidthConsumer struct {
	DeviceID   uuid.UUID `json:"device_id"`
	DeviceName string    `json:"device_name"`
	TotalBytes int64     `json:"total_bytes"`
	Department string    `json:"department"`
}

type DepartmentReport struct {
	Department      string `json:"department"`
	TotalBytes      int64  `json:"total_bytes"`
	VisitCount      int    `json:"visit_count"`
	UniqueDevices   int    `json:"unique_devices"`
	BlockedAttempts int    `json:"blocked_attempts"`
}
