package services

import (
	"strings"
	"testing"
	"time"

	"github.com/hospital/nms-backend/internal/repository"
)

func TestSNMPRequestAndAnswer(t *testing.T) {
	req := snmpGetRequest("public", 7, []string{oidSysDescr})
	if req[0] != 0x30 || !strings.Contains(string(req), "public") {
		t.Fatalf("request = %x", req)
	}
	// Build an answer the same way a device does.
	bind := func(oid string, v []byte) []byte { return berTLV(0x30, append(berOID(oid), v...)) }
	binds := append(bind(oidSysDescr, berTLV(0x04, []byte("HP LaserJet M404\x00"))), bind(oidPageCount, berTLV(0x41, []byte{0x01, 0x00}))...)
	binds = append(binds, bind(oidSerial, []byte{0x81, 0x00})...) // no such object
	binds = append(binds, bind(oidTonerLevel, berInt(40))...)
	pdu := append(append(append(berInt(7), berInt(0)...), berInt(0)...), berTLV(0x30, binds)...)
	msg := berTLV(0x30, append(append(berInt(1), berTLV(0x04, []byte("public"))...), berTLV(0xA2, pdu)...))
	got, err := parseSNMPResponse(msg)
	if err != nil {
		t.Fatal(err)
	}
	if got[oidSysDescr] != "HP LaserJet M404" || got[oidPageCount] != "256" || got[oidTonerLevel] != "40" {
		t.Errorf("got %v", got)
	}
	if _, ok := got[oidSerial]; ok {
		t.Error("a missing object must be left out")
	}
	if _, err := parseSNMPResponse([]byte{0x30, 0x50, 0x01}); err == nil {
		t.Error("a broken packet must be an error, not a crash")
	}
	if len(berLen(300)) != 3 || berLen(300)[0] != 0x82 {
		t.Errorf("long length = %x", berLen(300))
	}
}

func TestKindFromScan(t *testing.T) {
	cases := []struct {
		ports []int
		descr string
		want  string
	}{
		{[]int{9100, 80}, "", KindPrinter},
		{[]int{515, 631}, "", KindPrinter},
		{[]int{631}, "", ""}, // a Linux PC can have this alone
		{nil, "HP ETHERNET MULTI-ENVIRONMENT,JETDIRECT", KindPrinter},
		{nil, "RouterOS RB951", KindRouter},
		{nil, "TP-Link JetStream 24-Port Switch", KindSwitch},
		{[]int{445, 3389}, "", KindComputer},
		{[]int{445, 1433}, "", KindServer},
		{[]int{88, 389, 445}, "", KindServer},
		{[]int{445}, "Hardware: Intel64 - Software: Windows Server 2019", KindServer},
		{[]int{554}, "", KindCamera},
		{[]int{135, 445, 554}, "", KindComputer}, // a PC running video software
		{[]int{104}, "", KindMedical},
		{[]int{8291}, "", KindRouter},
		{nil, "", ""},
	}
	for _, c := range cases {
		if got, _, _ := kindFromScan(c.ports, c.descr); got != c.want {
			t.Errorf("%v %q: got %q, want %q", c.ports, c.descr, got, c.want)
		}
	}
}

func TestApplyScanReadsPrinterDetails(t *testing.T) {
	f := repository.AssetFingerprint{Ports: []int{9100}}
	applyScan(&f, map[string]string{oidSysDescr: "HP JETDIRECT;SN:1", oidDeviceName: "HP LaserJet M404", oidSerial: "PHB123", oidPageCount: "5000", oidTonerMax: "200", oidTonerLevel: "50"})
	if f.Kind != KindPrinter || f.Model != "HP LaserJet M404" || f.Serial != "PHB123" || *f.PageCount != 5000 || *f.TonerPercent != 25 {
		t.Errorf("%+v", f)
	}
	// Printers report negative numbers when they cannot tell.
	f = repository.AssetFingerprint{Ports: []int{9100}}
	applyScan(&f, map[string]string{oidTonerMax: "-2", oidTonerLevel: "-3", oidPageCount: "-1"})
	if f.TonerPercent != nil || f.PageCount != nil {
		t.Errorf("unknown values must stay empty: %+v", f)
	}
}

func TestComposeInventory(t *testing.T) {
	devices := []MapDevice{
		{ID: "r", Source: "router", IP: "172.16.0.1", MAC: "AA:00:00:00:00:01", Kind: KindUnknown, Online: true},
		{ID: "p", Source: "client", IP: "172.16.0.20", MAC: "AA:00:00:00:00:02", Kind: KindUnknown, Confidence: ConfidenceNone, Online: true},
		{ID: "m", Source: "client", IP: "172.16.0.21", MAC: "AA:00:00:00:00:03", Kind: KindRouter, KindCustom: true, Confidence: ConfidenceHigh, Online: false},
		{ID: "h", Source: "client", IP: "172.16.0.22", MAC: "AA:00:00:00:00:04", Kind: KindPhone, Confidence: ConfidenceHigh, Online: true},
		{ID: "t", Source: "client", IP: "172.16.0.23", MAC: "AA:00:00:00:00:05", Kind: KindTablet, Confidence: ConfidenceMedium, Online: true},
		{ID: "c", Source: "client", IP: "172.16.0.24", MAC: "AA:00:00:00:00:06", Kind: KindComputer, Confidence: ConfidenceHigh, Online: true},
		{ID: "u", Source: "client", IP: "172.16.0.25", MAC: "AA:00:00:00:00:07", Kind: KindUnknown, Confidence: ConfidenceNone, Online: false},
		// A phone the name got wrong: the scan found it prints.
		{ID: "w", Source: "client", IP: "172.16.0.26", MAC: "AA:00:00:00:00:08", Kind: KindPhone, Confidence: ConfidenceMedium, Online: true},
		// The person said computer, the scan says printer: the person wins.
		{ID: "k", Source: "client", IP: "172.16.0.27", MAC: "AA:00:00:00:00:09", Kind: KindComputer, KindCustom: true, Confidence: ConfidenceHigh, Online: true},
	}
	pages := int64(900)
	printer := repository.AssetFingerprint{Kind: KindPrinter, Confidence: ConfidenceHigh, Reason: "port 9100", Model: "HP M404", Serial: "S1", PageCount: &pages}
	inv := composeInventory(devices, map[string]repository.AssetFingerprint{
		"AA:00:00:00:00:02": printer, "AA:00:00:00:00:08": printer, "AA:00:00:00:00:09": printer,
	})
	if len(inv.Excluded) != 2 || inv.Total != 7 || inv.Online != 5 {
		t.Fatalf("excluded=%d total=%d online=%d", len(inv.Excluded), inv.Total, inv.Online)
	}
	got := map[string]int{}
	for _, c := range inv.Counts {
		got[c.Kind] = c.Total
	}
	if got[KindRouter] != 2 || got[KindPrinter] != 2 || got[KindComputer] != 2 || got[KindUnknown] != 1 || got[KindPhone] != 0 {
		t.Errorf("counts = %v", got)
	}
	if inv.NeedsReview != 1 {
		t.Errorf("needs review = %d", inv.NeedsReview)
	}
	for _, it := range inv.Items {
		if it.ID == "p" && (it.KindSource != "scan" || it.Serial != "S1" || it.Model != "HP M404" || *it.PageCount != 900) {
			t.Errorf("printer = %+v", it)
		}
		if it.ID == "k" && (it.Kind != KindComputer || it.KindSource != "manual") {
			t.Errorf("a person's choice must win: %+v", it)
		}
	}
	if inv.Items[0].Kind != KindRouter {
		t.Errorf("routers come first: %+v", inv.Items[0])
	}
}

func TestScanTargetsLeaveMedicalAndPhonesAlone(t *testing.T) {
	got := scanTargets([]MapDevice{
		{IP: "172.16.0.2", Online: true, Kind: KindUnknown},
		{IP: "172.16.0.3", Online: true, Kind: KindMedical},
		{IP: "172.16.0.4", Online: true, Kind: KindPhone},
		{IP: "172.16.0.5", Online: false, Kind: KindPrinter},
		{IP: "172.16.0.1", Online: true, Source: "router", Kind: KindRouter},
		{IP: "8.8.8.8", Online: true, Kind: KindUnknown},
		{IP: "", Online: true, Kind: KindUnknown},
	})
	if len(got) != 1 || got[0].IP != "172.16.0.2" {
		t.Errorf("targets = %+v", got)
	}
}

func TestExportInventory(t *testing.T) {
	pages := int64(12)
	out := string(ExportInventoryCSV(Inventory{
		Total: 1, Online: 1, Excluded: []InventoryItem{{}, {}},
		Counts: []InventoryCount{{Kind: KindPrinter, Total: 1, Online: 1}},
		Items:  []InventoryItem{{Kind: KindPrinter, Name: "=cmd()", IP: "172.16.0.9", Online: true, PageCount: &pages}},
	}, time.Date(2026, 11, 4, 9, 0, 0, 0, time.UTC)))
	if !strings.HasPrefix(out, "\xEF\xBB\xBF") {
		t.Error("Excel needs the byte order mark for Arabic")
	}
	for _, want := range []string{"2026-11-04 09:00", "\"Phones and tablets, not counted\",2", "Printer,1,1", "'=cmd()", "172.16.0.9", ",12,"} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

func TestInventoryIncludesTheMainRouterOnce(t *testing.T) {
	m := NetworkMap{Router: MapRouter{Name: "RB2011", IP: "172.16.0.1", Online: true}, Devices: []MapDevice{{ID: "c", IP: "172.16.0.9", Kind: KindComputer}}}
	got := withMainRouter(m)
	if len(got) != 2 || got[0].Kind != KindRouter || got[0].Name != "RB2011" || !got[0].Online {
		t.Fatalf("%+v", got)
	}
	inv := composeInventory(got, nil)
	if inv.Counts[0].Kind != KindRouter || inv.Counts[0].Total != 1 {
		t.Errorf("%+v", inv.Counts)
	}
	m.Devices = got
	if len(withMainRouter(m)) != 2 {
		t.Error("the router must not be counted twice")
	}
	if len(withMainRouter(NetworkMap{Devices: m.Devices[1:]})) != 1 {
		t.Error("no router known, nothing to add")
	}
}
