package services

import "testing"

func TestLookupVendorReadsTheEmbeddedRegistry(t *testing.T) {
	cases := map[string]string{
		"B8:69:F4:B3:A8:FC": "Routerboard.com", // the hospital's MikroTik router
		"b8-69-f4-b3-a8-fc": "Routerboard.com", // any case and separator
		"B869.F4B3.A8FC":    "Routerboard.com",
		"00:03:93:00:00:01": "Apple, Inc.",
		"DC:4A:3E:68:76:3F": "Hewlett Packard",
	}
	for mac, want := range cases {
		if got := LookupVendor(mac); got != want {
			t.Errorf("LookupVendor(%q) = %q, want %q", mac, got, want)
		}
	}
}

func TestLookupVendorGivesNothingWhereThereIsNoVendor(t *testing.T) {
	// A randomized address belongs to no company, even if its bytes look like one.
	if got := LookupVendor("DA:A1:19:00:11:22"); got != "" {
		t.Errorf("private address matched %q", got)
	}
	for _, mac := range []string{"", "12", "not a mac"} {
		if got := LookupVendor(mac); got != "" {
			t.Errorf("LookupVendor(%q) = %q, want nothing", mac, got)
		}
	}
}

func TestShortVendorDropsLegalSuffixes(t *testing.T) {
	cases := map[string]string{
		"Apple, Inc.":                  "Apple",
		"Micro-Star Int'L Co.,Ltd.":    "Micro-Star Int'L",
		"Xiaomi Communications Co Ltd": "Xiaomi Communications",
		"Hewlett Packard":              "Hewlett Packard",
		"Samsung Electronics Co.,Ltd":  "Samsung Electronics",
		"Cisco Systems, Inc":           "Cisco Systems",
		"Inc":                          "Inc", // never reduced to nothing
		"":                             "",
	}
	for in, want := range cases {
		if got := ShortVendor(in); got != want {
			t.Errorf("ShortVendor(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestVendorGuessIsHonestAboutVendorsThatMakeManyThings(t *testing.T) {
	cases := []struct {
		vendor string
		kind   string
		conf   string
	}{
		{"Canon Inc.", KindPrinter, ConfidenceMedium},
		{"Hangzhou Hikvision Digital Technology Co.,Ltd.", KindCamera, ConfidenceMedium},
		{"Routerboard.com", KindNetwork, ConfidenceMedium},
		{"Intel Corporate", KindComputer, ConfidenceMedium},
		{"Guangdong Oppo Mobile Telecommunications Corp.,Ltd", KindPhone, ConfidenceMedium},
		{"Infinix mobility limited", KindPhone, ConfidenceMedium},
		// Makers of many kinds of device: a guess, and said to be one.
		{"Samsung Electronics Co.,Ltd", KindPhone, ConfidenceLow},
		{"Hewlett Packard", KindComputer, ConfidenceLow},
	}
	for _, c := range cases {
		g, ok := guessFromVendor(c.vendor)
		if !ok || g.Kind != c.kind || g.Confidence != c.conf || g.Reason == "" {
			t.Errorf("%q: got %+v ok=%v, want kind=%s conf=%s", c.vendor, g, ok, c.kind, c.conf)
		}
	}
	for _, vendor := range []string{"Apple, Inc.", "Huawei Technologies Co.,Ltd", "Some Unknown Vendor", ""} {
		if g, ok := guessFromVendor(vendor); ok {
			t.Errorf("%q must stay unclassified, got %+v", vendor, g)
		}
	}
}

func TestVendorDoesNotOverrideAHostName(t *testing.T) {
	// An iPhone name wins over whatever the (HP) network card says.
	g := ClassifyDevice("iPhone", "DC:4A:3E:68:76:3F", "")
	if g.Kind != KindPhone || g.Brand != "Apple" {
		t.Fatalf("host name must win: %+v", g)
	}
	if g.Vendor != "Hewlett Packard" {
		t.Fatalf("the vendor is still reported: %+v", g)
	}
	// No name and no comment: the vendor decides, as a low-confidence guess.
	g = ClassifyDevice("", "DC:4A:3E:68:76:3F", "")
	if g.Kind != KindComputer || g.Confidence != ConfidenceLow || g.Brand != "Hewlett Packard" {
		t.Fatalf("vendor guess: %+v", g)
	}
}
