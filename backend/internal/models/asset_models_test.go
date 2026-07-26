package models

import (
	"encoding/json"
	"net"
	"testing"

	"github.com/google/uuid"
)

func TestFloorMapDeviceViewJSONIncludesDeviceMetadata(t *testing.T) {
	mac := "AA:BB:CC:DD:EE:FF"
	view := FloorMapDeviceView{
		FloorMapDevice: FloorMapDevice{
			ID:         uuid.New(),
			FloorMapID: uuid.New(),
			DeviceID:   uuid.New(),
			XCoord:     250,
			YCoord:     100,
		},
		DeviceName: "ICU Monitor",
		MACAddress: &mac,
		IPAddress:  net.ParseIP("10.0.0.15"),
		Status:     "degraded",
	}

	encoded, err := json.Marshal(view)
	if err != nil {
		t.Fatalf("marshal floor map device view: %v", err)
	}

	var result map[string]any
	if err := json.Unmarshal(encoded, &result); err != nil {
		t.Fatalf("unmarshal floor map device view: %v", err)
	}
	for key, expected := range map[string]any{
		"device_name": "ICU Monitor",
		"mac_address": mac,
		"ip_address":  "10.0.0.15",
		"status":      "degraded",
		"x_coord":     float64(250),
	} {
		if result[key] != expected {
			t.Errorf("%s = %v, want %v", key, result[key], expected)
		}
	}
}
