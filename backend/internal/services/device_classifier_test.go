package services

import (
	"fmt"
	"testing"
)

func TestClassifyDevice(t *testing.T) {
	cases := []struct {
		host, mac string
		kind      string
		brand     string
		conf      string
	}{
		// Names seen on the hospital network.
		{"iPhone", "98:4B:E1:04:93:B2", KindPhone, "Apple", ConfidenceHigh},
		{"OPPO-A54", "44:1E:A1:3C:CB:04", KindPhone, "OPPO", ConfidenceHigh},
		{"OPPO-Reno12-F-5G", "44:1E:A1:3C:CB:05", KindPhone, "OPPO", ConfidenceHigh},
		{"Redmi-Note-9S", "64:51:06:5C:C8:48", KindPhone, "Xiaomi", ConfidenceHigh},
		{"V2247", "50:65:F3:37:52:39", KindPhone, "vivo", ConfidenceHigh},
		{"Galaxy-A24", "50:65:F3:37:52:40", KindPhone, "Samsung", ConfidenceHigh},
		{"Galaxy-Tab-A-2016", "50:65:F3:37:52:41", KindTablet, "Samsung", ConfidenceHigh},
		{"Comp-1", "00:21:85:3E:35:44", KindComputer, "", ConfidenceMedium},
		// Common defaults.
		{"DESKTOP-AB12CD3", "AC:1E:9E:B6:27:94", KindComputer, "Microsoft", ConfidenceHigh},
		{"LAPTOP-9XQ2L1K", "AC:1E:9E:B6:27:95", KindComputer, "Microsoft", ConfidenceHigh},
		{"MacBook-Pro-de-Ahmed", "AC:1E:9E:B6:27:96", KindComputer, "Apple", ConfidenceHigh},
		{"iPad", "AC:1E:9E:B6:27:97", KindTablet, "Apple", ConfidenceHigh},
		{"NPI3F8A21", "AC:1E:9E:B6:27:98", KindPrinter, "HP", ConfidenceHigh},
		{"BRN30055C1A2B3C", "AC:1E:9E:B6:27:99", KindPrinter, "Brother", ConfidenceHigh},
		{"HPLaserJetM404", "AC:1E:9E:B6:27:9A", KindPrinter, "HP", ConfidenceHigh},
		{"android-1234567890abcdef", "AC:1E:9E:B6:27:9B", KindPhone, "Android", ConfidenceMedium},
		{"ESP_A1B2C3", "AC:1E:9E:B6:27:9C", KindIoT, "Espressif", ConfidenceHigh},
		{"HIKVISION-DS-2CD2043", "AC:1E:9E:B6:27:9D", KindCamera, "Hikvision", ConfidenceHigh},
		{"ECG-Room-3", "AC:1E:9E:B6:27:9E", KindMedical, "", ConfidenceMedium},
		{"Samsung-TV-55", "AC:1E:9E:B6:27:9F", KindTV, "Samsung", ConfidenceHigh},
		// No usable name.
		{"", "DA:A1:19:00:11:22", KindPhone, "", ConfidenceLow}, // private address
		{"", "98:4B:E1:04:93:B2", KindUnknown, "", ConfidenceNone},
		{"A32-alkhas-b-Engy", "98:4B:E1:04:93:B3", KindPhone, "Samsung", ConfidenceMedium},
	}
	for _, c := range cases {
		got := ClassifyDevice(c.host, testMACFor(c.mac), "")
		if got.Kind != c.kind || (c.brand != "" && got.Brand != c.brand) || got.Confidence != c.conf {
			t.Errorf("%q (%s): got %+v, want kind=%s brand=%q conf=%s", c.host, c.mac, got, c.kind, c.brand, c.conf)
		}
		if got.Reason == "" {
			t.Errorf("%q: classification has no reason", c.host)
		}
	}
}

func TestPrivateMACDetection(t *testing.T) {
	for mac, want := range map[string]bool{
		"DA:A1:19:00:11:22": true, // 0xDA has the locally-administered bit
		"02:00:00:00:00:01": true,
		"A6:11:22:33:44:55": true,
		"98:4B:E1:04:93:B2": false, // manufacturer-assigned
		"44:1E:A1:3C:CB:04": false,
		"":                  false,
		"zz:00":             false,
	} {
		if got := IsPrivateMAC(mac); got != want {
			t.Errorf("IsPrivateMAC(%q) = %v, want %v", mac, got, want)
		}
	}
}

func TestDecodeRouterTextReadsWindows1256Arabic(t *testing.T) {
	// "اعط" as Windows-1256 bytes, the way WinBox on Arabic Windows stores it.
	if got := decodeRouterText("\xc7\xda\xd8"); got != "اعط" {
		t.Fatalf("decoded %q", got)
	}
	// UTF-8 and plain ASCII are returned untouched.
	if got := decodeRouterText("Reception 2"); got != "Reception 2" {
		t.Fatalf("ascii changed: %q", got)
	}
	if got := decodeRouterText("صيدلية"); got != "صيدلية" {
		t.Fatalf("utf-8 changed: %q", got)
	}
}

// Names and comments seen on the hospital network.
func TestClassifyRealHospitalNames(t *testing.T) {
	cases := []struct {
		host, mac, comment string
		kind               string
		conf               string
	}{
		// Workstations named after departments.
		{"Emergency2", "AC:1E:9E:B6:27:A0", "", KindComputer, ConfidenceLow},
		{"ENT-clinic", "AC:1E:9E:B6:27:A1", "", KindComputer, ConfidenceLow},
		{"Pharm-5", "AC:1E:9E:B6:27:A2", "", KindComputer, ConfidenceLow},
		{"PED-Clinc", "AC:1E:9E:B6:27:A3", "", KindComputer, ConfidenceLow},
		{"Physiotherapy", "AC:1E:9E:B6:27:A4", "", KindComputer, ConfidenceLow},
		{"Dr-Hany-Clinic", "AC:1E:9E:B6:27:A5", "", KindComputer, ConfidenceLow},
		// Samsung A-series phones named after their owners.
		{"A30s-alkhas-b-Amany", "AC:1E:9E:B6:27:A6", "", KindPhone, ConfidenceMedium},
		{"Tona-s-A17", "AC:1E:9E:B6:27:A7", "", KindPhone, ConfidenceMedium},
		{"Dina-s-A05s", "AC:1E:9E:B6:27:A8", "", KindPhone, ConfidenceMedium},
		{"Hany-s-A54", "AC:1E:9E:B6:27:A9", "", KindPhone, ConfidenceMedium},
		// No name: the comment written on the router decides.
		{"", "AC:1E:9E:B6:27:B0", "طابعة الاستقبال", KindPrinter, ConfidenceMedium},
		{"", "AC:1E:9E:B6:27:B1", "كمبيوتر الخزينة", KindComputer, ConfidenceMedium},
		{"", "AC:1E:9E:B6:27:B2", "كاميرا المدخل", KindCamera, ConfidenceMedium},
		{"", "AC:1E:9E:B6:27:B3", "جهاز اشعة", KindMedical, ConfidenceMedium},
		// A damaged name is ignored; the private address still says "mobile".
		{"??�?", "DA:A1:19:00:11:22", "", KindPhone, ConfidenceLow},
		// Nothing to go on stays unknown, even with a comment that says nothing.
		{"", "98:4B:E1:04:93:B2", "عيادات الكاونتر*", KindUnknown, ConfidenceNone},
		{"Lolo", "98:4B:E1:04:93:B3", "", KindUnknown, ConfidenceNone},
	}
	for _, c := range cases {
		got := ClassifyDevice(c.host, testMACFor(c.mac), c.comment)
		if got.Kind != c.kind || got.Confidence != c.conf {
			t.Errorf("host %q comment %q: got %+v, want kind=%s conf=%s", c.host, c.comment, got, c.kind, c.conf)
		}
	}
}

// testMACFor keeps private (randomized) addresses as they are and swaps every
// other test address for one the IEEE registry knows nothing about, so a
// vendor guess cannot change what these tests say about names and comments.
func testMACFor(mac string) string {
	if IsPrivateMAC(mac) {
		return mac
	}
	for b := 0x04; b < 0x100; b += 4 {
		candidate := fmt.Sprintf("%02X:EE:EE:00:00:01", b)
		if !IsPrivateMAC(candidate) && LookupVendor(candidate) == "" {
			return candidate
		}
	}
	return mac
}
