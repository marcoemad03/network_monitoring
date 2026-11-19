//go:build integration

package services

import (
	"context"
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

// Read-only: runs the network problems check on the real router and prints it.
//
//	go test -tags integration -v -run TestNetworkProblemsLive ./internal/services
func TestNetworkProblemsLive(t *testing.T) {
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
	inv := NewClientInventoryService(repository.NewClientRepository(db), repository.NewInternetRepository(db), cfg)
	res, err := inv.Problems(ctx, org)
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("available=%v error=%q devices=%d issues=%d", res.Available, res.Error, res.DevicesSeen, len(res.Issues))
	for _, i := range res.Issues {
		t.Logf("[%s] %s: %s (%d devices)", i.Severity, i.Kind, i.Title, len(i.Devices))
		for n, d := range i.Devices {
			if n == 4 {
				break
			}
			t.Logf("      %s %s %s (%s)", d.MAC, d.IP, d.Name, d.Seen)
		}
	}
}

// Read-only: what the group source lists would become with blocks following the
// MAC, against what is on the router now.
//
//	go test -tags integration -v -run TestMemberAddressesLive ./internal/services
func TestMemberAddressesLive(t *testing.T) {
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
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	internetRepo := repository.NewInternetRepository(db)
	marcoRepo := repository.NewMarcoRepository(db)
	inv := NewClientInventoryService(repository.NewClientRepository(db), internetRepo, cfg)
	inv.Poll(ctx, org)
	if inv.LiveIPs(org) == nil {
		t.Fatal("router device list not read")
	}
	vendor, err := internetRepo.GetActiveMikroTikIntegration(ctx, org)
	if err != nil {
		t.Skip(err)
	}
	groups, _ := marcoRepo.ListGroups(ctx, org)
	members, _ := marcoRepo.ListAllMembers(ctx, org)
	by := map[uuid.UUID][]models.MarcoGroupMember{}
	for _, m := range members {
		by[m.GroupID] = append(by[m.GroupID], m)
	}
	s := NewMarcoSyncService(marcoRepo, repository.NewDeviceRepository(db), internetRepo, cfg, nil, nil)
	s.live = inv
	// buildOptions saves addresses it learns; this test must not write, so it works
	// on the address rule directly.
	live, holders := inv.LiveIPs(org), inv.AddressHolders(org)
	want := map[string]string{}
	for _, g := range groups {
		for _, m := range by[g.ID] {
			mac := strings.ToUpper(orEmpty(m.MACAddress))
			ip := m.IPAddress
			if mac != "" {
				ip = memberAddress(mac, m.IPAddress, live, holders)
			}
			if ip != nil {
				want[marcoSrcListPrefix+marcoShortID(g.ID)+"|"+ip.String()] = g.Name + " " + m.DeviceName
				if ip.String() == "172.16.0.125" {
					t.Logf(".125 kept for %s %s mac=%s saved=%v live=%q holders=%v", g.Name, m.DeviceName, mac, m.IPAddress, live[mac], holders["172.16.0.125"])
				}
			}
		}
	}
	conn, err := dialRouterConnection(vendor, cfg)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	rows, err := conn.Command("/ip/firewall/address-list/print", "=.proplist=list,address,comment")
	if err != nil {
		t.Fatal(err)
	}
	have := map[string]bool{}
	for _, r := range rows {
		if strings.HasPrefix(r["list"], marcoSrcListPrefix) {
			k := r["list"] + "|" + strings.TrimSuffix(r["address"], "/32")
			have[k] = true
			if _, ok := want[k]; !ok {
				t.Logf("would remove: %s (%s)", k, r["comment"])
			}
		}
	}
	for k, who := range want {
		if !have[k] {
			t.Logf("would add: %s (%s)", k, who)
		}
	}
	t.Logf("source entries on router %d, wanted %d", len(have), len(want))
}
