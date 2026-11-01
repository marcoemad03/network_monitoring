package services

import (
	"context"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
)

func TestAnalyzeFlowsGroupsByDeviceAndSumsDestinations(t *testing.T) {
	lb := newLabeler([]string{"172.16.0.1"})
	lb.addPlatform("YouTube", "142.250.185.78")
	idents := map[string]DeviceIdentity{
		"172.16.0.5": {MAC: "AA:BB:CC:00:00:05", Name: "Reception PC", Kind: KindComputer},
		"172.16.0.6": {MAC: "AA:BB:CC:00:00:06", Name: "Dr Sara phone", Kind: KindPhone},
	}
	flows := []Flow{
		{Proto: "tcp", SrcIP: "172.16.0.5", DstIP: "142.250.185.78", DstPort: 443, Down: 8_000_000, Up: 200_000},
		{Proto: "tcp", SrcIP: "172.16.0.6", DstIP: "142.250.185.78", DstPort: 443, Down: 2_000_000, Up: 50_000},
		{Proto: "udp", SrcIP: "172.16.0.6", DstIP: "8.8.8.8", DstPort: 53, Down: 300, Up: 80},
		// Not worth listing: the router talking out, internet hosts calling in, broadcast.
		{Proto: "tcp", SrcIP: "172.16.0.1", DstIP: "8.8.8.8", DstPort: 53},
		{Proto: "tcp", SrcIP: "203.0.113.9", DstIP: "172.16.0.1", DstPort: 8291},
		{Proto: "udp", SrcIP: "172.16.0.6", DstIP: "255.255.255.255", DstPort: 67},
	}

	devices, findings, destinations := analyzeFlows(flows, lb, idents, "172.16.0.1")

	if len(devices) != 2 || len(findings) != 0 {
		t.Fatalf("devices=%d findings=%d: %+v", len(devices), len(findings), devices)
	}
	byName := map[string]DeviceActivity{}
	for _, d := range devices {
		byName[d.Name] = d
	}
	pc := byName["Reception PC"]
	if pc.MAC != "AA:BB:CC:00:00:05" || pc.Connections != 1 || pc.Down != 8_000_000 || pc.Top[0].Name != "YouTube" {
		t.Fatalf("reception PC: %+v", pc)
	}
	phone := byName["Dr Sara phone"]
	if phone.Connections != 2 || phone.Destinations != 2 {
		t.Fatalf("the broadcast flow must not count: %+v", phone)
	}

	var youtube *DestinationStat
	for i := range destinations {
		if destinations[i].Name == "YouTube" {
			youtube = &destinations[i]
		}
	}
	if youtube == nil || youtube.Devices != 2 || youtube.Connections != 2 || youtube.Down != 10_000_000 {
		t.Fatalf("YouTube summed over both devices: %+v", youtube)
	}
}

func TestAnalyzeFlowsKeepsUnknownDevicesByAddress(t *testing.T) {
	lb := newLabeler([]string{"172.16.0.1"})
	devices, _, _ := analyzeFlows([]Flow{{Proto: "tcp", SrcIP: "172.16.0.77", DstIP: "203.0.113.5", DstPort: 443}}, lb, nil, "172.16.0.1")
	if len(devices) != 1 || devices[0].Name != "172.16.0.77" || devices[0].MAC != "" {
		t.Fatalf("an unnamed device is shown by its address: %+v", devices)
	}
}

func TestFindingsSurfaceInTheSnapshotAndRankDevicesWorstFirst(t *testing.T) {
	lb := newLabeler([]string{"172.16.0.1"})
	var flows []Flow
	for i := 0; i < 80; i++ { // a device sweeping SMB on the internet
		flows = append(flows, Flow{Proto: "tcp", SrcIP: "172.16.0.9", DstIP: fmt.Sprintf("203.0.%d.%d", i, i+1), DstPort: 445})
	}
	flows = append(flows, Flow{Proto: "tcp", SrcIP: "172.16.0.5", DstIP: "142.250.1.1", DstPort: 443, Down: 99_000_000})

	devices, findings, destinations := analyzeFlows(flows, lb, nil, "172.16.0.1")
	snap := &ScanSnapshot{Devices: devices, Findings: findings, Destinations: destinations}
	finishSnapshot(snap)

	if len(snap.Findings) == 0 || snap.Findings[0].Severity != SeverityHigh || snap.Findings[0].IP != "172.16.0.9" {
		t.Fatalf("findings: %+v", snap.Findings)
	}
	if snap.Devices[0].IP != "172.16.0.9" || snap.Devices[0].High == 0 {
		t.Fatalf("the flagged device must be first even though the other moved more data: %+v", snap.Devices[0])
	}
}

func TestScansAreRateLimitedAndNeverOverlap(t *testing.T) {
	s := NewSecurityScanService(nil, nil, nil, &config.Config{RouterScanCooldown: 5 * time.Minute})
	org := uuid.New()

	s.mu.Lock()
	s.state(org).snapshot = &ScanSnapshot{TakenAt: time.Now().Add(-90 * time.Second)}
	s.mu.Unlock()

	_, err := s.Scan(context.Background(), org)
	var cool *ScanCooldownError
	if !errors.As(err, &cool) || cool.RetryAfter < 3*time.Minute || cool.RetryAfter > 4*time.Minute {
		t.Fatalf("a scan 90 seconds ago must ask for about 3.5 more minutes, got %v", err)
	}
	if left := s.Status(org).CooldownLeft; left < 3*time.Minute {
		t.Fatalf("status must show the wait too: %v", left)
	}

	// A scan restored from the database after a restart does not block a new one.
	s.mu.Lock()
	s.state(org).snapshot = &ScanSnapshot{TakenAt: time.Now(), Restored: true}
	s.mu.Unlock()
	if left := s.Status(org).CooldownLeft; left != 0 {
		t.Fatalf("a restored scan must not impose a wait: %v", left)
	}

	// While one runs, another is refused.
	s.mu.Lock()
	s.state(org).scanning = true
	s.mu.Unlock()
	if _, err := s.Scan(context.Background(), org); !errors.Is(err, ErrScanBusy) {
		t.Fatalf("a second scan must be refused while one runs, got %v", err)
	}
}

func TestPlatformTitle(t *testing.T) {
	for in, want := range map[string]string{"youtube": "YouTube", "tiktok": "TikTok", "facebook": "Facebook", "zoom": "Zoom", "": ""} {
		if got := platformTitle(in); got != want {
			t.Errorf("platformTitle(%q) = %q, want %q", in, got, want)
		}
	}
}
