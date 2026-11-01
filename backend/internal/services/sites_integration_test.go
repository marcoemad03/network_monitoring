//go:build integration

package services

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/pkg/logger"
)

// Run with a development database:
//
//	go test -tags integration -run TestSitesAgainstRealDatabase ./internal/services
//
// It stores a few lookups under a made-up address range and a catalog entry,
// reads them back by name, and deletes everything it added.
func TestSitesAgainstRealDatabase(t *testing.T) {
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
	if err := db.RunMigrations(ctx, "../database/migrations"); err != nil {
		t.Fatal("migrations:", err)
	}

	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	repo := repository.NewDNSRepository(db)
	collector := NewDNSCollector(repo, nil, 30)
	collector.RegisterSource("test", true)
	collector.orgFn = func(context.Context) ([]uuid.UUID, error) { return []uuid.UUID{org}, nil }
	svc := NewSitesService(repo, collector, NewClientInventoryService(repository.NewClientRepository(db), repository.NewInternetRepository(db), cfg))

	// Documentation address range: never a real device of the hospital.
	const dev1, dev2 = "192.0.2.10", "192.0.2.11"
	cleanup := func() {
		_, _ = db.Exec(ctx, `DELETE FROM dns_activity WHERE organization_id = $1 AND client_ip LIKE '192.0.2.%'`, org)
		_, _ = db.Exec(ctx, `DELETE FROM site_catalog WHERE organization_id = $1 AND name LIKE 'ZZ Test %'`, org)
	}
	cleanup()
	defer cleanup()

	now := time.Now()
	for i := 0; i < 3; i++ {
		collector.Add("test", DNSEvent{Time: now, ClientIP: dev1, Name: "portal.zz-test-insurer.com.eg", QType: "A"})
	}
	collector.Add("test", DNSEvent{Time: now, ClientIP: dev2, Name: "www.zz-test-insurer.com.eg", QType: "A"})
	collector.Add("test", DNSEvent{Time: now, ClientIP: dev2, Name: "claims.zz-test-insurer-2.com.eg", QType: "A"})
	collector.Add("test", DNSEvent{Time: now, ClientIP: dev1, Name: "www.youtube.com", QType: "A"})
	collector.Add("test", DNSEvent{Time: now, ClientIP: dev1, Name: "d1.cloudfront.net", QType: "A"})
	collector.Flush(ctx)
	// A second flush in the same hour adds to the same rows.
	collector.Add("test", DNSEvent{Time: now, ClientIP: dev1, Name: "portal.zz-test-insurer.com.eg", QType: "A"})
	collector.Flush(ctx)

	// Before it is named, an unknown site shows by its domain.
	out, err := svc.Overview(ctx, org, 24, false, 30)
	if err != nil {
		t.Fatal(err)
	}
	find := func(o SitesOverview, name string) *SiteView {
		for i := range o.Sites {
			if o.Sites[i].Name == name {
				return &o.Sites[i]
			}
		}
		return nil
	}
	raw := find(out, "zz-test-insurer.com.eg")
	if raw == nil || raw.Named || raw.Queries != 5 || raw.Devices != 2 {
		t.Fatalf("unnamed site = %+v", raw)
	}
	if yt := find(out, "YouTube"); yt == nil || !yt.BuiltIn || yt.Category != CategoryVideo {
		t.Fatalf("YouTube = %+v", yt)
	}
	if find(out, "Content delivery") != nil || out.Hidden[CategoryBackground] == 0 {
		t.Error("background services should be hidden by default")
	}
	withBackground, _ := svc.Overview(ctx, org, 24, true, 30)
	if find(withBackground, "Content delivery") == nil {
		t.Error("background services should show when asked for")
	}

	// Name it, with two domains, as the hospital would for an insurer.
	entry, err := svc.Create(ctx, org, CatalogInput{Name: "ZZ Test Insurance", Category: CategoryInsurance, Domains: []string{"https://www.zz-test-insurer.com.eg/login", "zz-test-insurer-2.com.eg"}})
	if err != nil {
		t.Fatal(err)
	}
	if _, err := svc.Create(ctx, org, CatalogInput{Name: "ZZ Test Duplicate", Domains: []string{"zz-test-insurer.com.eg"}}); !errors.Is(err, ErrSiteExists) {
		t.Errorf("a domain in two entries: err = %v, want ErrSiteExists", err)
	}
	named, _ := svc.Overview(ctx, org, 24, false, 30)
	site := find(named, "ZZ Test Insurance")
	if site == nil || !site.Named || site.Category != CategoryInsurance || site.Queries != 6 || len(site.Domains) != 2 || site.HasLogo {
		t.Fatalf("named site = %+v", site)
	}
	if named.ByCategory[CategoryInsurance] < 1 {
		t.Errorf("by category = %v", named.ByCategory)
	}

	// Logo: refused when it is not an image, kept and served when it is.
	if _, err := svc.SetLogo(ctx, org, entry.ID, []byte("<svg onload=alert(1)>")); !errors.Is(err, ErrNotAnImage) {
		t.Errorf("svg upload: err = %v", err)
	}
	logo := pngBytes(t)
	if e, err := svc.SetLogo(ctx, org, entry.ID, logo); err != nil || !e.HasLogo || e.LogoSource != "upload" {
		t.Fatalf("SetLogo: %+v, %v", e, err)
	}
	for _, domain := range []string{"zz-test-insurer.com.eg", "https://claims.zz-test-insurer-2.com.eg/x"} {
		data, ct, err := svc.Logo(ctx, org, domain)
		if err != nil || ct != "image/png" || len(data) != len(logo) {
			t.Errorf("Logo(%s): %d bytes, %q, %v", domain, len(data), ct, err)
		}
	}
	if _, _, err := svc.Logo(ctx, org, "youtube.com"); !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("a site without a logo: err = %v", err)
	}

	// Who asked for it, and what one device asked for.
	detail, err := svc.SiteDevices(ctx, org, "zz-test-insurer.com.eg", 24)
	if err != nil || detail.Site.Name != "ZZ Test Insurance" || len(detail.Devices) != 2 {
		t.Fatalf("SiteDevices: %+v, %v", detail, err)
	}
	if detail.Devices[0].IP != dev1 || detail.Devices[0].Queries != 4 {
		t.Errorf("busiest device = %+v, want %s with 4", detail.Devices[0], dev1)
	}
	mine, err := svc.DeviceSites(ctx, org, dev1, 24, false)
	if err != nil || !mine.Recording {
		t.Fatalf("DeviceSites: %+v, %v", mine, err)
	}
	if len(mine.Sites) != 2 || mine.Sites[0].Name != "ZZ Test Insurance" || mine.Sites[0].Queries != 4 || mine.Hidden != 1 {
		t.Errorf("device sites = %+v, hidden %d", mine.Sites, mine.Hidden)
	}

	// Renaming moves the numbers with it; deleting puts the domains back.
	if _, err := svc.Update(ctx, org, entry.ID, CatalogInput{Name: "ZZ Test Renamed", Category: CategoryInsurance, Domains: []string{"zz-test-insurer.com.eg"}}); err != nil {
		t.Fatal(err)
	}
	if err := svc.Delete(ctx, org, entry.ID); err != nil {
		t.Fatal(err)
	}
	if err := svc.Delete(ctx, org, entry.ID); !errors.Is(err, repository.ErrNotFound) {
		t.Errorf("deleting twice: err = %v", err)
	}
	after, _ := svc.Overview(ctx, org, 24, false, 30)
	if find(after, "ZZ Test Renamed") != nil || find(after, "zz-test-insurer.com.eg") == nil {
		t.Error("after deleting the entry the domain should show by its own name again")
	}

	// Adopting a built-in site keeps its name and category.
	adopted, err := svc.Adopt(ctx, org, "www.youtube.com", "", "")
	if err != nil || adopted.Name != "YouTube" || adopted.Category != CategoryVideo || len(adopted.Domains) < 2 {
		t.Fatalf("Adopt: %+v, %v", adopted, err)
	}
	_ = svc.Delete(ctx, org, adopted.ID)
}
