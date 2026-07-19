package models

import (
	"net"
	"time"

	"github.com/google/uuid"
)

type DeviceGroup struct {
	ID             uuid.UUID  `json:"id" db:"id"`
	OrganizationID uuid.UUID  `json:"organization_id" db:"organization_id"`
	Name           string     `json:"name" db:"name"`
	Description    *string    `json:"description,omitempty" db:"description"`
	ParentGroupID  *uuid.UUID `json:"parent_group_id,omitempty" db:"parent_group_id"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

type DeviceGroupMember struct {
	ID        uuid.UUID `json:"id" db:"id"`
	DeviceID  uuid.UUID `json:"device_id" db:"device_id"`
	GroupID   uuid.UUID `json:"group_id" db:"group_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type FloorMap struct {
	ID             uuid.UUID `json:"id" db:"id"`
	OrganizationID uuid.UUID `json:"organization_id" db:"organization_id"`
	Name           string    `json:"name" db:"name"`
	ImagePath      string    `json:"image_path" db:"image_path"`
	Width          int       `json:"width" db:"width"`
	Height         int       `json:"height" db:"height"`
	CreatedAt      time.Time `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time `json:"updated_at" db:"updated_at"`
}

type FloorMapDevice struct {
	ID         uuid.UUID `json:"id" db:"id"`
	FloorMapID uuid.UUID `json:"floor_map_id" db:"floor_map_id"`
	DeviceID   uuid.UUID `json:"device_id" db:"device_id"`
	XCoord     float64   `json:"x_coord" db:"x_coord"`
	YCoord     float64   `json:"y_coord" db:"y_coord"`
	CreatedAt  time.Time `json:"created_at" db:"created_at"`
	UpdatedAt  time.Time `json:"updated_at" db:"updated_at"`
}

type FloorMapDeviceView struct {
	FloorMapDevice
	DeviceName string  `json:"device_name" db:"device_name"`
	MACAddress *string `json:"mac_address,omitempty" db:"mac_address"`
	IPAddress  net.IP  `json:"ip_address" db:"ip_address"`
	Status     string  `json:"status" db:"status"`
}

type AssetDetail struct {
	ID            uuid.UUID  `json:"id" db:"id"`
	DeviceID      uuid.UUID  `json:"device_id" db:"device_id"`
	Department    *string    `json:"department,omitempty" db:"department"`
	FloorName     *string    `json:"floor_name,omitempty" db:"floor_name"`
	Room          *string    `json:"room,omitempty" db:"room"`
	SwitchPort    *string    `json:"switch_port,omitempty" db:"switch_port"`
	AccessPointID *uuid.UUID `json:"access_point_id,omitempty" db:"access_point_id"`
	Notes         *string    `json:"notes,omitempty" db:"notes"`
	CreatedAt     time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time  `json:"updated_at" db:"updated_at"`
}

type AssetInventory struct {
	AssetDetail
	DeviceName       string     `json:"device_name" db:"device_name"`
	MACAddress       *string    `json:"mac_address,omitempty" db:"mac_address"`
	IPAddress        net.IP     `json:"ip_address" db:"ip_address"`
	Status           string     `json:"status" db:"status"`
	GroupIDs         []uuid.UUID `json:"group_ids" db:"group_ids"`
	GroupNames       []string   `json:"group_names" db:"group_names"`
	FloorMapID       *uuid.UUID `json:"floor_map_id,omitempty" db:"floor_map_id"`
	FloorMapName     *string    `json:"floor_map_name,omitempty" db:"floor_map_name"`
	XCoord           *float64   `json:"x_coord,omitempty" db:"x_coord"`
	YCoord           *float64   `json:"y_coord,omitempty" db:"y_coord"`
	AccessPointName  *string    `json:"access_point_name,omitempty" db:"access_point_name"`
}

type Policy struct {
	ID             uuid.UUID              `json:"id" db:"id"`
	OrganizationID uuid.UUID              `json:"organization_id" db:"organization_id"`
	Name           string                 `json:"name" db:"name"`
	Description    *string                `json:"description,omitempty" db:"description"`
	PolicyType     string                 `json:"policy_type" db:"policy_type"`
	Config         map[string]interface{} `json:"config" db:"config"`
	IsActive       bool                   `json:"is_active" db:"is_active"`
	CreatedAt      time.Time              `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time              `json:"updated_at" db:"updated_at"`
}

type PolicyAssignment struct {
	ID        uuid.UUID `json:"id" db:"id"`
	PolicyID  uuid.UUID `json:"policy_id" db:"policy_id"`
	GroupID   uuid.UUID `json:"group_id" db:"group_id"`
	CreatedAt time.Time `json:"created_at" db:"created_at"`
}

type SyncLog struct {
	ID                 uuid.UUID              `json:"id" db:"id"`
	OrganizationID     uuid.UUID              `json:"organization_id" db:"organization_id"`
	VendorIntegrationID *uuid.UUID            `json:"vendor_integration_id,omitempty" db:"vendor_integration_id"`
	Status             string                 `json:"status" db:"status"`
	Details            map[string]interface{} `json:"details" db:"details"`
	CreatedAt          time.Time              `json:"created_at" db:"created_at"`
}
