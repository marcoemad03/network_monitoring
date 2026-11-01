//go:build integration

package services

import (
	"context"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

// scanRouter answers the few read commands a scan sends.
type scanRouter struct {
	rows map[string][]map[string]string
}

func (c scanRouter) Command(path string, attrs ...string) ([]map[string]string, error) {
	if path == "/ip/firewall/address-list/print" {
		for _, a := range attrs {
			if strings.HasPrefix(a, "?list=") {
				return c.rows["list:"+strings.TrimPrefix(a, "?list=")], nil
			}
		}
	}
	return c.rows[path], nil
}
func (scanRouter) Close() error { return nil }

// Run with a development database:
//
//	go test -tags integration -run TestSecurityScanAgainstRealDatabase ./internal/services
//
// It stores one scan from a canned router and removes it again.
func TestSecurityScanAgainstRealDatabase(t *testing.T) {
	cfg, err := config.Load(0)
	if err != nil {
		t.Skip("no configuration:", err)
	}
	logger.Init("error", "json")
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		t.Skip("no database:", err)
	}
	defer db.Close()
	ctx := context.Background()

	internetRepo := repository.NewInternetRepository(db)
	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	if _, err := internetRepo.GetActiveMikroTikIntegration(ctx, org); err != nil {
		t.Skip("no router integration in this database:", err)
	}
	cfg.RouterScanCooldown = time.Minute
	cfg.RouterScanMaxCPU = 85
	cfg.RouterScanPlatformLists = map[string]string{"youtube": "collect all youtube ips"}

	inventory := NewClientInventoryService(repository.NewClientRepository(db), internetRepo, cfg)
	svc := NewSecurityScanService(repository.NewSecurityRepository(db), internetRepo, inventory, cfg)
	svc.lookupAddr = func(_ context.Context, ip string) ([]string, error) {
		if ip == "13.35.1.1" {
			return []string{"server-13-35-1-1.cai50.r.cloudfront.net."}, nil
		}
		return nil, fmt.Errorf("no PTR")
	}

	conns := []map[string]string{
		{"protocol": "tcp", "src-address": "172.16.0.5:50000", "dst-address": "142.250.185.78:443", "orig-bytes": "1000", "repl-bytes": "5000000"},
		{"protocol": "tcp", "src-address": "172.16.0.5:50001", "dst-address": "13.35.1.1:443", "orig-bytes": "500", "repl-bytes": "20000"},
		{"protocol": "udp", "src-address": "172.16.0.5:50002", "dst-address": "8.8.8.8:53", "orig-bytes": "80", "repl-bytes": "200"},
	}
	for i := 0; i < 60; i++ { // a sweep, so a finding is stored too
		conns = append(conns, map[string]string{"protocol": "tcp", "src-address": fmt.Sprintf("172.16.0.9:%d", 40000+i),
			"dst-address": fmt.Sprintf("203.0.%d.%d:445", i, i+1), "orig-bytes": "60", "repl-bytes": "0"})
	}
	svc.dial = func(*models.VendorIntegration, *config.Config) (routerCommander, error) {
		return scanRouter{rows: map[string][]map[string]string{
			"/system/resource/print":        {{"cpu-load": "40"}},
			"list:collect all youtube ips":  {{"address": "142.250.185.78"}},
			"/ip/firewall/connection/print": conns,
		}}, nil
	}

	snap, err := svc.Scan(ctx, org)
	if err != nil {
		t.Fatal(err)
	}
	if snap.ID == 0 {
		t.Fatal("the scan was not stored")
	}
	defer db.Exec(ctx, `DELETE FROM security_scans WHERE id = $1`, snap.ID)

	if snap.Connections != len(conns) || snap.RouterCPUBefore != 40 || snap.PlatformLists != 1 {
		t.Fatalf("snapshot: %+v", snap)
	}
	labels := map[string]bool{}
	for _, d := range snap.Destinations {
		labels[d.Name] = true
	}
	for _, want := range []string{"YouTube", "Amazon CloudFront", "DNS"} {
		if !labels[want] {
			t.Errorf("destination %q missing from %v", want, labels)
		}
	}
	if len(snap.Findings) == 0 || snap.Findings[0].Severity != SeverityHigh {
		t.Fatalf("the SMB sweep must be a high finding: %+v", snap.Findings)
	}

	// After a restart the scan is rebuilt from the database.
	svc2 := NewSecurityScanService(repository.NewSecurityRepository(db), internetRepo, inventory, cfg)
	restored := svc2.Latest(ctx, org)
	if restored == nil || !restored.Restored || restored.ID != snap.ID || len(restored.Devices) != 2 || len(restored.Findings) == 0 {
		t.Fatalf("restored: %+v", restored)
	}
	if status := svc2.Status(org); status.CooldownLeft != 0 {
		t.Fatal("a restored scan must not block a new one")
	}

	popular, err := svc.Popular(ctx, org, 7)
	if err != nil {
		t.Fatal(err)
	}
	found := false
	for _, p := range popular {
		if p.Label == "YouTube" && p.Scans >= 1 {
			found = true
		}
	}
	if !found {
		t.Fatalf("YouTube must be ranked in the last 7 days: %+v", popular)
	}
}
