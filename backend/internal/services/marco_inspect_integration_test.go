//go:build integration

package services

import (
	"context"
	"sort"
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

// Read-only: prints the nms-marco- entries on the router and which of them the
// current groups no longer want. It only issues print commands.
//
//	go test -tags integration -v -run TestInspectMarcoRouterState ./internal/services
func TestInspectMarcoRouterState(t *testing.T) {
	cfg, err := config.Load(0)
	if err != nil {
		t.Skip(err)
	}
	logger.Init("error", "json")
	db, err := database.NewPostgresDB(cfg)
	if err != nil {
		t.Skip(err)
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	internetRepo := repository.NewInternetRepository(db)
	marcoRepo := repository.NewMarcoRepository(db)
	vendor, err := internetRepo.GetActiveMikroTikIntegration(ctx, org)
	if err != nil {
		t.Skip(err)
	}
	conn, err := dialRouterConnection(vendor, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()

	groups, _ := marcoRepo.ListGroups(ctx, org)
	members, _ := marcoRepo.ListAllMembers(ctx, org)
	by := map[uuid.UUID][]models.MarcoGroupMember{}
	for _, m := range members {
		by[m.GroupID] = append(by[m.GroupID], m)
	}
	s := NewMarcoSyncService(marcoRepo, repository.NewDeviceRepository(db), internetRepo, cfg, nil, nil)
	opts, err := s.buildOptions(ctx, org, vendor, groups, by)
	if err != nil {
		t.Fatal(err)
	}
	desired := buildMarcoDesiredState(groups, by, opts)
	for _, g := range groups {
		t.Logf("group %q members=%d policy=%+v", g.Name, len(by[g.ID]), g.Policy)
	}
	for _, w := range desired.warnings {
		t.Logf("warning: %s", w)
	}

	for path, tbl := range marcoTables(desired) {
		existing, dups, err := listManaged(conn, path, marcoManagedPrefix, isMarcoExcluded)
		if err != nil {
			t.Fatal(err)
		}
		var stale []string
		for c := range existing {
			if _, ok := tbl.desired[c]; !ok {
				stale = append(stale, c)
			}
		}
		sort.Strings(stale)
		t.Logf("%s: on router %d, wanted %d, stale %d, duplicates %d", path, len(existing), len(tbl.desired), len(stale), len(dups))
		prefixes := map[string]int{}
		for _, c := range stale {
			parts := strings.SplitN(strings.TrimPrefix(c, marcoManagedPrefix), "-", 2)
			prefixes[parts[0]]++
		}
		t.Logf("   stale by first part of the name: %v", prefixes)
		for i, c := range stale {
			if i >= 6 && !strings.Contains(c, "-src-") && path != "/ip/firewall/filter" {
				continue
			}
			e := existing[c]
			t.Logf("   stale: %s | addr=%s list=%s chain=%s action=%s src=%s dst=%s time=%s disabled=%s bytes=%s", c, e["address"], e["list"], e["chain"], e["action"], e["src-address-list"], e["dst-address-list"], e["time"], e["disabled"], e["bytes"])
		}
	}
}
