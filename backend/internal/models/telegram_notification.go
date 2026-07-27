package models

import (
	"time"

	"github.com/google/uuid"
)

type TelegramConfig struct {
	OrganizationID      uuid.UUID `json:"organization_id"`
	BotToken            string    `json:"bot_token"`
	ChatID              string    `json:"chat_id"`
	GracePeriodMinutes  int       `json:"grace_period_minutes"`
	OncePerDay          bool      `json:"once_per_day"`
	NotifyConnect       bool      `json:"notify_connect"`
	NotifyDisconnect    bool      `json:"notify_disconnect"`
	NotifyNewDevice     bool      `json:"notify_new_device"`
	NotifyPolicyViolation bool    `json:"notify_policy_violation"`
	Enabled             bool      `json:"enabled"`
	CreatedAt           time.Time `json:"created_at"`
	UpdatedAt           time.Time `json:"updated_at"`
}

type TelegramNotificationHistory struct {
	ID             uuid.UUID `json:"id"`
	OrganizationID uuid.UUID `json:"organization_id"`
	DeviceMAC      string    `json:"device_mac"`
	DeviceName     string    `json:"device_name"`
	IPAddress      string    `json:"ip_address"`
	AccessPoint    string    `json:"access_point"`
	EventType      string    `json:"event_type"`
	SentAt         time.Time `json:"sent_at"`
	DayDate        time.Time `json:"day_date"`
}

type TelegramEventType string

const (
	TelegramEventConnect         TelegramEventType = "device_connected"
	TelegramEventDisconnect      TelegramEventType = "device_disconnected"
	TelegramEventNewDevice       TelegramEventType = "new_device"
	TelegramEventPolicyViolation TelegramEventType = "policy_violation"
)
