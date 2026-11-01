package services

import (
	"errors"
	"net"
	"testing"

	"github.com/hospital/nms-backend/internal/models"
)

func str(v string) *string { return &v }

func storedSwitch() *models.Device {
	return &models.Device{
		Name: "Core-Switch-01", IPAddress: net.ParseIP("10.0.1.1"), DeviceType: "switch", Status: "online",
		Vendor: str("Cisco"), Location: str("Server room"), Notes: str("rack 2"),
		CustomFields: map[string]string{"rack": "2"}, IsCritical: true, IsMonitored: true, IsPinned: true,
	}
}

func TestMergeKeepsWhatTheRequestLeftOut(t *testing.T) {
	// The request only renames the device. Everything else must survive.
	in := &models.Device{Name: "Core-Switch-01B"}
	MergeDeviceUpdate(storedSwitch(), in, map[string]bool{"name": true})

	if in.Name != "Core-Switch-01B" {
		t.Fatalf("name = %q", in.Name)
	}
	if !in.IPAddress.Equal(net.ParseIP("10.0.1.1")) || in.DeviceType != "switch" || in.Status != "online" {
		t.Fatalf("required fields were wiped: %+v", in)
	}
	if in.Vendor == nil || *in.Vendor != "Cisco" || in.Notes == nil || *in.Notes != "rack 2" || in.CustomFields["rack"] != "2" {
		t.Fatalf("optional fields were wiped: %+v", in)
	}
	if !in.IsCritical || !in.IsMonitored || !in.IsPinned {
		t.Fatalf("flags left out of the request must be kept: critical=%v monitored=%v pinned=%v", in.IsCritical, in.IsMonitored, in.IsPinned)
	}
}

func TestMergeLetsTheRequestTurnFlagsOffWhenItSendsThem(t *testing.T) {
	in := &models.Device{Name: "Core-Switch-01", IsMonitored: false, IsCritical: false}
	MergeDeviceUpdate(storedSwitch(), in, map[string]bool{"name": true, "is_monitored": true, "is_critical": true})

	if in.IsMonitored || in.IsCritical {
		t.Fatalf("flags sent as false must become false: %+v", in)
	}
	if !in.IsPinned {
		t.Fatal("is_pinned was not sent and must stay on")
	}
}

func TestMergeLetsTheRequestReplaceValues(t *testing.T) {
	in := &models.Device{Name: "X", IPAddress: net.ParseIP("10.0.9.9"), DeviceType: "router", Vendor: str("MikroTik")}
	MergeDeviceUpdate(storedSwitch(), in, map[string]bool{"name": true, "ip_address": true, "device_type": true, "vendor": true})

	if !in.IPAddress.Equal(net.ParseIP("10.0.9.9")) || in.DeviceType != "router" || *in.Vendor != "MikroTik" {
		t.Fatalf("sent values must win: %+v", in)
	}
	if in.Location == nil || *in.Location != "Server room" {
		t.Fatal("a value that was not sent must be kept")
	}
}

func TestValidateDevice(t *testing.T) {
	good := &models.Device{Name: "Printer", IPAddress: net.ParseIP("10.0.70.10"), MACAddress: str("AA:BB:CC:DD:EE:FF")}
	if err := ValidateDevice(good); err != nil {
		t.Fatalf("valid device rejected: %v", err)
	}
	cases := map[string]*models.Device{
		"no name":      {Name: "  ", IPAddress: net.ParseIP("10.0.0.1")},
		"no address":   {Name: "X"},
		"zero address": {Name: "X", IPAddress: net.ParseIP("0.0.0.0")},
		"bad mac":      {Name: "X", IPAddress: net.ParseIP("10.0.0.1"), MACAddress: str("not-a-mac")},
	}
	for name, d := range cases {
		err := ValidateDevice(d)
		var input *DeviceInputError
		if err == nil || !errors.As(err, &input) {
			t.Errorf("%s: expected a DeviceInputError, got %v", name, err)
		}
	}
	// An empty MAC means "none", not an error.
	if err := ValidateDevice(&models.Device{Name: "X", IPAddress: net.ParseIP("10.0.0.1"), MACAddress: str("")}); err != nil {
		t.Fatalf("an empty MAC must be accepted: %v", err)
	}
}

func TestDescribeDeviceErrorGivesPeopleAUsableMessage(t *testing.T) {
	if status, msg := DescribeDeviceError(&DeviceInputError{"Enter a valid IP address"}); status != 400 || msg != "Enter a valid IP address" {
		t.Fatalf("input error: %d %q", status, msg)
	}
	if status, _ := DescribeDeviceError(errors.New(`ERROR: duplicate key value violates unique constraint "devices_ip_key"`)); status != 409 {
		t.Fatalf("duplicate must be a conflict, got %d", status)
	}
	if status, msg := DescribeDeviceError(errors.New("connection reset")); status != 500 || msg == "" {
		t.Fatalf("unknown error: %d %q", status, msg)
	}
}

func TestNormalizeIPStoresIPv4InFourBytes(t *testing.T) {
	// net.ParseIP returns the 16-byte form, which the database would store as "::ffff:10.0.0.1".
	got := NormalizeIP(net.ParseIP("10.0.0.1"))
	if len(got) != net.IPv4len {
		t.Fatalf("IPv4 address has %d bytes, want 4", len(got))
	}
	if v6 := NormalizeIP(net.ParseIP("2001:db8::1")); len(v6) != net.IPv6len {
		t.Fatal("an IPv6 address must stay 16 bytes")
	}
	in := &models.Device{Name: "X", IPAddress: net.ParseIP("10.0.0.1")}
	MergeDeviceUpdate(storedSwitch(), in, map[string]bool{"name": true, "ip_address": true})
	if len(in.IPAddress) != net.IPv4len {
		t.Fatal("an update must normalize the address too")
	}
}
