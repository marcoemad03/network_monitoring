//go:build integration

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
	"image"
	"image/png"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/config"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/logger"
)

// Run with a development database:
//
//	go test -tags integration -run TestSitesAPIAgainstRealDatabase ./internal/api/handlers
//
// It goes through the HTTP handlers (no router is contacted) with made-up lookups,
// and removes what it added.
func TestSitesAPIAgainstRealDatabase(t *testing.T) {
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
	if err := db.RunMigrations(ctx, "../../database/migrations"); err != nil {
		t.Fatal("migrations:", err)
	}

	org := uuid.MustParse("00000000-0000-0000-0000-000000000001")
	repo := repository.NewDNSRepository(db)
	collector := services.NewDNSCollector(repo, nil, 30)
	collector.RegisterSource("test", true)
	svc := services.NewSitesService(repo, collector, services.NewClientInventoryService(repository.NewClientRepository(db), repository.NewInternetRepository(db), cfg))
	h := NewSitesHandler(svc, repository.NewAuditRepository(db), 30)

	cleanup := func() {
		_, _ = db.Exec(ctx, `DELETE FROM dns_activity WHERE organization_id = $1 AND client_ip LIKE '192.0.2.%'`, org)
		_, _ = db.Exec(ctx, `DELETE FROM site_catalog WHERE organization_id = $1 AND name LIKE 'ZZ API %'`, org)
	}
	cleanup()
	defer cleanup()

	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("org_id", org.String()); c.Set("user_id", uuid.NewString()) })
	g := r.Group("/security")
	g.GET("/sites", h.Overview)
	g.GET("/sites/device/:key", h.Device)
	g.GET("/sites/logo/:domain", h.Logo)
	g.GET("/sites/detail/:domain", h.Site)
	g.POST("/sites/adopt", h.Adopt)
	g.POST("/catalog", h.Create)
	g.PUT("/catalog/:id", h.Update)
	g.DELETE("/catalog/:id", h.Delete)
	g.POST("/catalog/:id/logo/fetch", h.FetchLogo)
	g.PUT("/catalog/:id/logo", h.UploadLogo)
	g.DELETE("/catalog/:id/logo", h.ClearLogo)

	do := func(method, path string, body []byte, contentType string) *httptest.ResponseRecorder {
		req := httptest.NewRequest(method, path, bytes.NewReader(body))
		if contentType != "" {
			req.Header.Set("Content-Type", contentType)
		}
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}
	asJSON := func(v any) []byte { b, _ := json.Marshal(v); return b }
	decode := func(w *httptest.ResponseRecorder) map[string]any {
		var out map[string]any
		_ = json.Unmarshal(w.Body.Bytes(), &out)
		return out
	}

	img := image.NewRGBA(image.Rect(0, 0, 4, 4))
	var logo bytes.Buffer
	_ = png.Encode(&logo, img)

	// Lookups arrive and are stored.
	collector.RegisterSource("test", true)
	for i := 0; i < 4; i++ {
		collector.Add("test", services.DNSEvent{Time: time.Now(), ClientIP: "192.0.2.50", Name: "claims.zz-api-insurer.com.eg", QType: "A"})
	}
	collector.Flush(ctx)
	// Flush needs an organization; without one the lookups wait, so set it up directly.
	if err := repo.UpsertActivity(ctx, org, []repository.DNSRow{{Bucket: time.Now().UTC().Truncate(time.Hour), IP: "192.0.2.50", Site: "zz-api-insurer.com.eg", Queries: 4}}); err != nil {
		t.Fatal(err)
	}

	// Name it.
	w := do("POST", "/security/catalog", asJSON(map[string]any{"name": "ZZ API Insurance", "category": "insurance", "domains": []string{"https://www.zz-api-insurer.com.eg/login"}}), "application/json")
	if w.Code != http.StatusCreated {
		t.Fatalf("create: %d %s", w.Code, w.Body.String())
	}
	id := decode(w)["data"].(map[string]any)["id"].(string)
	if w := do("POST", "/security/catalog", asJSON(map[string]any{"name": "ZZ API Other", "domains": []string{"zz-api-insurer.com.eg"}}), "application/json"); w.Code != http.StatusConflict {
		t.Errorf("duplicate domain: %d %s", w.Code, w.Body.String())
	}
	if w := do("POST", "/security/catalog", asJSON(map[string]any{"name": "ZZ API Bad", "category": "nonsense", "domains": []string{"x.com.eg"}}), "application/json"); w.Code != http.StatusBadRequest {
		t.Errorf("unknown category: %d", w.Code)
	}
	if w := do("POST", "/security/catalog", []byte(`{`), "application/json"); w.Code != http.StatusBadRequest {
		t.Errorf("broken JSON: %d", w.Code)
	}

	// No logo yet, then a bad upload, then a good one.
	if w := do("GET", "/security/sites/logo/zz-api-insurer.com.eg", nil, ""); w.Code != http.StatusNotFound {
		t.Errorf("logo before upload: %d", w.Code)
	}
	if w := do("PUT", "/security/catalog/"+id+"/logo", []byte(`<svg onload="alert(1)"/>`), "image/svg+xml"); w.Code != http.StatusBadRequest {
		t.Errorf("svg upload: %d %s", w.Code, w.Body.String())
	}
	if w := do("PUT", "/security/catalog/"+id+"/logo", append(logo.Bytes(), make([]byte, 300<<10)...), "image/png"); w.Code != http.StatusRequestEntityTooLarge && w.Code != http.StatusBadRequest {
		t.Errorf("oversized upload: %d", w.Code)
	}
	if w := do("PUT", "/security/catalog/"+id+"/logo", logo.Bytes(), "image/png"); w.Code != http.StatusOK {
		t.Fatalf("png upload: %d %s", w.Code, w.Body.String())
	}
	w = do("GET", "/security/sites/logo/claims.zz-api-insurer.com.eg", nil, "")
	if w.Code != http.StatusOK || w.Header().Get("Content-Type") != "image/png" || w.Header().Get("X-Content-Type-Options") != "nosniff" || !bytes.Equal(w.Body.Bytes(), logo.Bytes()) {
		t.Errorf("logo: %d %q nosniff=%q", w.Code, w.Header().Get("Content-Type"), w.Header().Get("X-Content-Type-Options"))
	}
	// An address inside the hospital is refused by the server-side fetch.
	if w := do("POST", "/security/catalog/"+id+"/logo/fetch", asJSON(map[string]string{"logo_url": "http://172.16.0.1/logo.png"}), "application/json"); w.Code != http.StatusBadGateway {
		t.Errorf("fetch from the local network: %d %s", w.Code, w.Body.String())
	}

	// The page's data.
	w = do("GET", "/security/sites?hours=24", nil, "")
	if w.Code != http.StatusOK {
		t.Fatalf("sites: %d %s", w.Code, w.Body.String())
	}
	var found map[string]any
	for _, s := range decode(w)["data"].(map[string]any)["sites"].([]any) {
		if s.(map[string]any)["name"] == "ZZ API Insurance" {
			found = s.(map[string]any)
		}
	}
	if found == nil || found["category"] != "insurance" || found["has_logo"] != true || found["named"] != true || found["queries"].(float64) < 4 {
		t.Fatalf("site in overview = %v", found)
	}
	if w := do("GET", "/security/sites/detail/zz-api-insurer.com.eg?hours=24", nil, ""); w.Code != http.StatusOK {
		t.Errorf("detail: %d %s", w.Code, w.Body.String())
	}
	if w := do("GET", "/security/sites/detail/not%20a%20domain", nil, ""); w.Code != http.StatusBadRequest {
		t.Errorf("detail of nonsense: %d", w.Code)
	}
	if w := do("GET", "/security/sites/device/192.0.2.50", nil, ""); w.Code != http.StatusOK {
		t.Errorf("device: %d %s", w.Code, w.Body.String())
	}

	// Remove the logo, then the entry.
	if w := do("DELETE", "/security/catalog/"+id+"/logo", nil, ""); w.Code != http.StatusOK {
		t.Errorf("remove logo: %d", w.Code)
	}
	if w := do("GET", "/security/sites/logo/zz-api-insurer.com.eg", nil, ""); w.Code != http.StatusNotFound {
		t.Errorf("logo after removal: %d", w.Code)
	}
	if w := do("DELETE", "/security/catalog/"+id, nil, ""); w.Code != http.StatusOK {
		t.Errorf("delete: %d", w.Code)
	}
	if w := do("DELETE", "/security/catalog/"+id, nil, ""); w.Code != http.StatusNotFound {
		t.Errorf("delete twice: %d", w.Code)
	}
	if w := do("PUT", "/security/catalog/not-a-uuid", asJSON(map[string]any{"name": "x"}), "application/json"); w.Code != http.StatusBadRequest {
		t.Errorf("bad id: %d", w.Code)
	}
}
