package services

import (
	"context"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/repository"
)

func find(t *testing.T, clients []LiveClient, mac string) LiveClient {
	t.Helper()
	for _, c := range clients {
		if c.MAC == mac {
			return c
		}
	}
	t.Fatalf("client %s not found in %+v", mac, clients)
	return LiveClient{}
}

func TestMergeClientTablesJoinsByMACAndDecidesWhoIsOnline(t *testing.T) {
	hosts := []map[string]string{
		// Active hotspot host with an Arabic comment typed in WinBox (Windows-1256).
		{"mac-address": "98:4b:e1:04:93:b2", "address": "172.16.0.5", "server": "hotspot1", "bytes-in": "1000", "bytes-out": "5000",
			"uptime": "2h", "idle-time": "10s", "comment": "\xc7\xda\xd8", "authorized": "true"},
		// A host that left twenty minutes ago but is still in the table.
		{"mac-address": "44:1E:A1:3C:CB:04", "address": "172.16.0.6", "server": "hotspot1", "bytes-in": "1", "bytes-out": "2",
			"uptime": "3h", "idle-time": "20m", "authorized": "true"},
	}
	leases := []map[string]string{
		{"mac-address": "98:4B:E1:04:93:B2", "address": "172.16.0.5", "host-name": "iPhone", "status": "bound", "last-seen": "5s"},
		{"mac-address": "44:1E:A1:3C:CB:04", "address": "172.16.0.6", "host-name": "OPPO-A54", "status": "bound", "last-seen": "5s"},
		// DHCP-only device, seen long ago.
		{"mac-address": "AA:AA:AA:AA:AA:01", "address": "172.16.0.20", "host-name": "OldPC", "status": "bound", "last-seen": "3h"},
		// DHCP-only device, seen a minute ago.
		{"mac-address": "AA:AA:AA:AA:AA:02", "address": "172.16.0.21", "host-name": "Printer", "status": "bound", "last-seen": "1m"},
	}
	arps := []map[string]string{
		{"mac-address": "BB:BB:BB:BB:BB:01", "address": "172.16.0.30", "interface": "ether3", "complete": "true", "invalid": "false"},
		{"mac-address": "BB:BB:BB:BB:BB:02", "address": "172.16.0.31", "interface": "ether3", "complete": "false"}, // never answered
		{"mac-address": "", "address": "172.16.0.32", "complete": "true"},                                          // no MAC
	}

	clients := mergeClientTables(hosts, leases, arps)

	phone := find(t, clients, "98:4B:E1:04:93:B2")
	if !phone.Online || phone.Hostname != "iPhone" || phone.IP != "172.16.0.5" || phone.Network != "hotspot1" {
		t.Fatalf("phone: %+v", phone)
	}
	if phone.RouterComment != "اعط" {
		t.Fatalf("comment was not decoded: %q", phone.RouterComment)
	}
	// Counters: bytes-out is data sent to the device, i.e. its download.
	if !phone.HasCounters || phone.BytesDown != 5000 || phone.BytesUp != 1000 || phone.UptimeSeconds != 7200 {
		t.Fatalf("counters: %+v", phone)
	}
	if find(t, clients, "44:1E:A1:3C:CB:04").Online {
		t.Fatal("a host idle for 20 minutes must not count as online")
	}
	if find(t, clients, "AA:AA:AA:AA:AA:01").Online {
		t.Fatal("a lease last seen 3 hours ago must not count as online")
	}
	if !find(t, clients, "AA:AA:AA:AA:AA:02").Online {
		t.Fatal("a lease seen a minute ago is online")
	}
	if find(t, clients, "AA:AA:AA:AA:AA:01").HasCounters {
		t.Fatal("a device outside the hotspot has no byte counters")
	}
	if !find(t, clients, "BB:BB:BB:BB:BB:01").Online {
		t.Fatal("a complete ARP entry is online")
	}
	for _, c := range clients {
		if c.MAC == "BB:BB:BB:BB:BB:02" || c.MAC == "" {
			t.Fatalf("incomplete or MAC-less ARP entries must be ignored: %+v", c)
		}
	}
}

func TestApplyCountsOnlyMovementSinceTheLastPoll(t *testing.T) {
	st := &inventoryState{prev: map[string]counterReading{}, pendDown: map[string]int64{}, pendUp: map[string]int64{}}
	t0 := time.Now()
	mac := "98:4B:E1:04:93:B2"

	// First sight only sets the baseline: bytes the device moved before we looked are not ours to count.
	first := []LiveClient{{MAC: mac, HasCounters: true, BytesDown: 1_000_000, BytesUp: 100_000}}
	st.apply(first, t0)
	if st.pendDown[mac] != 0 || first[0].DownBps != 0 {
		t.Fatalf("baseline must not count: %+v %v", first[0], st.pendDown)
	}

	second := []LiveClient{{MAC: mac, HasCounters: true, BytesDown: 1_000_000 + 3_750_000, BytesUp: 100_000 + 375_000}}
	st.apply(second, t0.Add(30*time.Second))
	if second[0].DownBps != 1_000_000 || second[0].UpBps != 100_000 {
		t.Fatalf("speeds: down %d up %d", second[0].DownBps, second[0].UpBps)
	}
	if st.pendDown[mac] != 3_750_000 || st.pendUp[mac] != 375_000 {
		t.Fatalf("pending usage: %v %v", st.pendDown, st.pendUp)
	}

	// The hotspot dropped and recreated the host: counters restart from zero.
	third := []LiveClient{{MAC: mac, HasCounters: true, BytesDown: 500, BytesUp: 50}}
	st.apply(third, t0.Add(60*time.Second))
	if st.pendDown[mac] != 3_750_000 {
		t.Fatalf("a counter reset must not add usage: %v", st.pendDown)
	}
	if third[0].DownBps != 0 {
		t.Fatalf("a counter reset must not give a speed: %+v", third[0])
	}

	// Devices without counters are ignored, not counted as zero.
	st.apply([]LiveClient{{MAC: "AA:AA:AA:AA:AA:01"}}, t0.Add(90*time.Second))
	if _, ok := st.prev["AA:AA:AA:AA:AA:01"]; ok {
		t.Fatal("a device without counters must not be tracked")
	}
}

func TestSaveNoteRejectsBadInputBeforeTouchingTheDatabase(t *testing.T) {
	s := &ClientInventoryService{} // no repository: validation must stop first
	ctx := context.Background()
	org := uuid.New()
	long := strings.Repeat("x", maxNoteLen+1)
	longName := strings.Repeat("y", maxDisplayNameLen+1)
	badKind := "toaster"

	cases := []struct {
		name string
		mac  string
		in   NoteInput
	}{
		{"invalid MAC", "not-a-mac", NoteInput{}},
		{"note too long", "98:4B:E1:04:93:B2", NoteInput{Note: &long}},
		{"name too long", "98:4B:E1:04:93:B2", NoteInput{DisplayName: &longName}},
		{"unknown kind", "98:4B:E1:04:93:B2", NoteInput{Kind: &badKind}},
	}
	for _, c := range cases {
		_, err := s.SaveNote(ctx, org, c.mac, c.in)
		var input *ClientNoteError
		if err == nil || !asNoteError(err, &input) {
			t.Errorf("%s: expected a validation error, got %v", c.name, err)
		}
	}
}

func asNoteError(err error, target **ClientNoteError) bool {
	e, ok := err.(*ClientNoteError)
	if ok {
		*target = e
	}
	return ok
}

func TestDescribeClientNamesAndOverrides(t *testing.T) {
	v := &ClientView{MAC: "98:4B:E1:04:93:B2", IP: "172.16.0.5", Hostname: "iPhone"}
	describeClient(v, noteWith("", "", ""))
	if v.DisplayName != "iPhone" || v.NameSource != "hostname" || v.Kind != KindPhone || v.KindSource != "detected" {
		t.Fatalf("detected: %+v", v)
	}

	v = &ClientView{MAC: "98:4B:E1:04:93:B2", IP: "172.16.0.5", Hostname: "iPhone"}
	describeClient(v, noteWith("Dr. Sara phone", "Cardiology, floor 2", KindTablet))
	if v.DisplayName != "Dr. Sara phone" || v.NameSource != "custom" || v.Kind != KindTablet || v.KindSource != "custom" || v.Note != "Cardiology, floor 2" {
		t.Fatalf("custom: %+v", v)
	}

	// No name and an address nobody registered: fall back to the IP, never to an empty label.
	v = &ClientView{MAC: testMACFor("98:4B:E1:04:93:B2"), IP: "172.16.0.9"}
	describeClient(v, noteWith("", "", ""))
	if v.DisplayName != "172.16.0.9" || v.NameSource != "ip" || v.Kind != KindUnknown {
		t.Fatalf("fallback: %+v", v)
	}

	// No name, but the vendor is known: say what it probably is, with the address to tell devices apart.
	v = &ClientView{MAC: "98:4B:E1:04:93:B2", IP: "172.16.0.5"}
	describeClient(v, noteWith("", "", ""))
	if v.Vendor != "Hewlett Packard" || v.Kind != KindComputer || v.Confidence != ConfidenceLow {
		t.Fatalf("vendor guess: %+v", v)
	}
	if v.DisplayName != "Hewlett Packard computer · 172.16.0.5" || v.NameSource != "guess" {
		t.Fatalf("vendor name: %q (%s)", v.DisplayName, v.NameSource)
	}
}

func noteWith(name, note, kind string) repository.ClientNote {
	return repository.ClientNote{DisplayName: name, Note: note, KindOverride: kind}
}
