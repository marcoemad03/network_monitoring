package models

import (
	"time"

	"github.com/google/uuid"
)

type HotspotWelcomeConfig struct {
	OrganizationID uuid.UUID `json:"organization_id"`
	HospitalName   string    `json:"hospital_name"`
	LogoURL        string    `json:"logo_url"`
	PrimaryColor   string    `json:"primary_color"`
	AccentColor    string    `json:"accent_color"`
	WelcomeMessage string    `json:"welcome_message"`
	Announcements  []string  `json:"announcements"`
	Enabled        bool      `json:"enabled"`
	CreatedAt      time.Time `json:"created_at"`
	UpdatedAt      time.Time `json:"updated_at"`
}

type HotspotProfileResult struct {
	ProfileConfigured bool   `json:"profile_configured"`
	FileUploaded      bool   `json:"file_uploaded"`
	HTMLDirectory     string `json:"html_directory"`
	Message           string `json:"message"`
}
