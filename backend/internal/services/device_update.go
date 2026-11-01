package services

import (
	"errors"
	"net"
	"regexp"
	"strings"

	"github.com/hospital/nms-backend/internal/models"
)

var deviceMACPattern = regexp.MustCompile(`^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$`)

// DeviceInputError is returned for a device that cannot be saved as sent.
type DeviceInputError struct{ Message string }

func (e *DeviceInputError) Error() string { return e.Message }

// ValidateDevice checks what a person typed. Messages are shown to them as is.
func ValidateDevice(d *models.Device) error {
	if strings.TrimSpace(d.Name) == "" {
		return &DeviceInputError{"The device needs a name"}
	}
	if len([]rune(d.Name)) > 200 {
		return &DeviceInputError{"The name can be at most 200 characters"}
	}
	if len(d.IPAddress) == 0 || d.IPAddress.IsUnspecified() {
		return &DeviceInputError{"Enter a valid IP address"}
	}
	if d.MACAddress != nil && strings.TrimSpace(*d.MACAddress) != "" && !deviceMACPattern.MatchString(strings.TrimSpace(*d.MACAddress)) {
		return &DeviceInputError{"The MAC address must look like AA:BB:CC:DD:EE:FF"}
	}
	return nil
}

// MergeDeviceUpdate lays an incoming update over the stored device so that a
// request which leaves a field out keeps the stored value instead of wiping it.
// present lists the JSON keys that were actually in the request; it is needed
// for the true/false fields, where "left out" and "false" look the same.
func MergeDeviceUpdate(existing, in *models.Device, present map[string]bool) {
	keep := func(key string) bool { return present != nil && !present[key] }

	if in.Name == "" {
		in.Name = existing.Name
	}
	if len(in.IPAddress) == 0 {
		in.IPAddress = net.IP(existing.IPAddress)
	}
	if in.DeviceType == "" {
		in.DeviceType = existing.DeviceType
	}
	if in.Status == "" {
		in.Status = existing.Status
	}
	keepStr := func(dst **string, old *string) {
		if *dst == nil {
			*dst = old
		}
	}
	keepStr(&in.Hostname, existing.Hostname)
	keepStr(&in.MACAddress, existing.MACAddress)
	keepStr(&in.Vendor, existing.Vendor)
	keepStr(&in.Model, existing.Model)
	keepStr(&in.SerialNumber, existing.SerialNumber)
	keepStr(&in.OSVersion, existing.OSVersion)
	keepStr(&in.FirmwareVersion, existing.FirmwareVersion)
	keepStr(&in.Location, existing.Location)
	keepStr(&in.Department, existing.Department)
	keepStr(&in.Notes, existing.Notes)
	if in.CustomFields == nil {
		in.CustomFields = existing.CustomFields
	}
	if in.LastBoot == nil {
		in.LastBoot = existing.LastBoot
	}
	if keep("is_critical") {
		in.IsCritical = existing.IsCritical
	}
	if keep("is_monitored") {
		in.IsMonitored = existing.IsMonitored
	}
	if keep("is_pinned") {
		in.IsPinned = existing.IsPinned
	}
	in.IPAddress = NormalizeIP(in.IPAddress)
}

// DescribeDeviceError turns a failure into something a person can act on and the
// HTTP status to report it with.
func DescribeDeviceError(err error) (int, string) {
	var input *DeviceInputError
	if errors.As(err, &input) {
		return 400, input.Message
	}
	text := err.Error()
	if strings.Contains(text, "unique") || strings.Contains(text, "duplicate") {
		return 409, "A device with this IP address or MAC address already exists"
	}
	return 500, "Could not save the device"
}

// NormalizeIP gives IPv4 addresses their 4-byte form. Left as 16 bytes, the
// address is stored as an IPv4-mapped IPv6 one ("::ffff:10.0.0.1"), which then
// shows up that way and never equals the same address written normally.
func NormalizeIP(ip net.IP) net.IP {
	if v4 := ip.To4(); v4 != nil {
		return v4
	}
	return ip
}
