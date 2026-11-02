//go:build integration

package handlers

import (
	"bytes"
	"context"
	"encoding/json"
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
//	go test -tags integration -v -run TestNetworkMapAgainstRealDatabase ./internal/api/handlers
//
// It reads the router with print commands only (the same tables the server reads
// every few seconds, plus the bridge host and neighbour tables) and checks that
// the HTTP handler returns a coherent map. Set MAP_DUMP=1 to print the devices.
func TestNetworkMapAgainstRealDatabase(t *testing.T) {
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
	clientRepo := repository.NewClientRepository(db)
	internetRepo := repository.NewInternetRepository(db)
	inventory := services.NewClientInventoryService(clientRepo, internetRepo, cfg)
	pollCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
	inventory.Poll(pollCtx, org)
	cancel()
	topology := services.NewTopologyService(internetRepo, cfg)
	svc := services.NewNetworkMapService(inventory, topology, clientRepo, repository.NewMonitoringRepository(db))
	h := NewNetworkMapHandler(svc)

	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) { c.Set("org_id", org.String()) })
	r.GET("/map", h.Get)
	r.PUT("/places/:port", h.SavePlace)

	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest("GET", "/map", nil))
	if w.Code != http.StatusOK {
		t.Fatalf("map: %d %s", w.Code, w.Body.String())
	}
	var body struct {
		Data services.NetworkMap `json:"data"`
	}
	if err := json.Unmarshal(w.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	m := body.Data
	t.Logf("router=%q ip=%s online=%v | topology_error=%q notes=%v", m.Router.Name, m.Router.IP, m.Router.Online, m.TopologyError, m.TopologyNotes)
	t.Logf("summary=%+v", m.Summary)
	for _, p := range m.Ports {
		t.Logf("port %-10s type=%-6s running=%-5v devices=%-3d online=%-3d label=%q (%s) rx=%d tx=%d", p.Name, p.Type, p.Running, p.Devices, p.Online, p.Label, p.LabelSource, p.RxBps, p.TxBps)
	}
	if m.Summary.Total != len(m.Devices) || m.Summary.Online+m.Summary.Offline != m.Summary.Total {
		t.Errorf("summary does not add up: %+v with %d devices", m.Summary, len(m.Devices))
	}
	seen := map[string]bool{}
	for _, d := range m.Devices {
		if seen[d.ID] {
			t.Errorf("device listed twice: %s", d.ID)
		}
		seen[d.ID] = true
		if d.Name == "" || d.Kind == "" {
			t.Errorf("device without name or kind: %+v", d)
		}
	}
	if testing.Verbose() && len(m.Devices) > 0 {
		limit := len(m.Devices)
		if limit > 60 {
			limit = 60
		}
		for _, d := range m.Devices[:limit] {
			t.Logf("%-8s %-7v %-15s %-17s %-13s %-9s port=%-8s(%s) place=%q(%s) name=%q", d.Source, d.Online, d.IP, d.MAC, d.Kind, d.Confidence, d.Port, d.PortSource, d.Place, d.PlaceSource, d.Name)
		}
	}

	// Naming a port is stored and shows on the next read, then is removed again.
	if len(m.Ports) > 0 {
		port := m.Ports[0].Name
		put := func(label string) int {
			req := httptest.NewRequest("PUT", "/places/"+port, nil)
			req.Body = http.NoBody
			rec := httptest.NewRecorder()
			r2 := gin.New()
			r2.Use(func(c *gin.Context) { c.Set("org_id", org.String()) })
			r2.PUT("/places/:port", h.SavePlace)
			req2 := httptest.NewRequest("PUT", "/places/"+port, jsonBody(label))
			req2.Header.Set("Content-Type", "application/json")
			r2.ServeHTTP(rec, req2)
			return rec.Code
		}
		if code := put("ZZ test place"); code != http.StatusOK {
			t.Fatalf("save place: %d", code)
		}
		defer put("")
		places, _ := clientRepo.Places(ctx, org)
		if places[port] != "ZZ test place" {
			t.Errorf("place not stored: %v", places)
		}
	}
}

func jsonBody(label string) *bytes.Reader {
	b, _ := json.Marshal(map[string]string{"label": label})
	return bytes.NewReader(b)
}
