package mikrotik

import "testing"

func TestMergeEnhancedDeviceMergesIPOnlyObservationIntoMACDevice(t *testing.T) {
	seen := make(map[string]EnhancedDevice)
	mergeEnhancedDevice(seen, EnhancedDevice{
		IPAddress:  "172.16.0.252",
		MACAddress: "50:65:f3:3b:78:b5",
		IsActive:   true,
	}, "dhcp")
	mergeEnhancedDevice(seen, EnhancedDevice{
		IPAddress: "172.16.0.252",
	}, "arp")

	if len(seen) != 1 {
		t.Fatalf("expected one merged device, got %d", len(seen))
	}
	device := seen["50:65:F3:3B:78:B5"]
	if device.IPAddress != "172.16.0.252" || !device.IsActive {
		t.Fatalf("unexpected merged device: %+v", device)
	}
}

func TestMergeEnhancedDevicePromotesIPOnlyDeviceToMACKey(t *testing.T) {
	seen := make(map[string]EnhancedDevice)
	mergeEnhancedDevice(seen, EnhancedDevice{IPAddress: "172.16.0.10"}, "arp")
	mergeEnhancedDevice(seen, EnhancedDevice{
		IPAddress:  "172.16.0.10",
		MACAddress: "aa:bb:cc:dd:ee:ff",
		Hostname:   "workstation",
	}, "dhcp")

	if len(seen) != 1 {
		t.Fatalf("expected one merged device, got %d", len(seen))
	}
	device, ok := seen["AA:BB:CC:DD:EE:FF"]
	if !ok || device.Hostname != "workstation" {
		t.Fatalf("expected MAC-keyed device with hostname, got %+v", seen)
	}
}

func TestMergeEnhancedDeviceKeepsDistinctMACDevices(t *testing.T) {
	seen := make(map[string]EnhancedDevice)
	mergeEnhancedDevice(seen, EnhancedDevice{
		IPAddress:  "172.16.0.20",
		MACAddress: "00:11:22:33:44:55",
	}, "dhcp")
	mergeEnhancedDevice(seen, EnhancedDevice{
		IPAddress:  "172.16.0.20",
		MACAddress: "66:77:88:99:AA:BB",
	}, "arp")

	if len(seen) != 2 {
		t.Fatalf("expected distinct MAC devices to remain visible, got %d", len(seen))
	}
}
