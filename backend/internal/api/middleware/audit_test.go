package middleware

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/models"
)

type memAudit struct{ logs []*models.AuditLog }

func (m *memAudit) Create(_ context.Context, l *models.AuditLog) error {
	m.logs = append(m.logs, l)
	return nil
}

func auditRouter(store AuditStore) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) {
		c.Set("org_id", "00000000-0000-0000-0000-000000000001")
		c.Set("user_id", "00000000-0000-0000-0000-000000000002")
	}, AuditTrail(store))
	ok := func(c *gin.Context) { c.Status(http.StatusOK) }
	r.GET("/api/v1/marco/groups", ok)
	r.POST("/api/v1/marco/groups", ok)
	r.PUT("/api/v1/monitoring/clients/inventory/x", ok)
	r.DELETE("/api/v1/marco/groups/1", func(c *gin.Context) { c.Status(http.StatusNotFound) })
	r.POST("/api/v1/marco/sites/check", ok)
	r.POST("/api/v1/marco/terminal", func(c *gin.Context) {
		c.Set(AuditDetailKey, "/ip firewall filter remove")
		c.Status(http.StatusOK)
	})
	r.POST("/api/v1/preview", func(c *gin.Context) {
		c.Set(AuditSkipKey, true)
		c.Status(http.StatusOK)
	})
	return r
}

func TestAuditTrail(t *testing.T) {
	store := &memAudit{}
	r := auditRouter(store)
	call := func(method, path string) {
		r.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(method, path, nil))
	}
	call(http.MethodGet, "/api/v1/marco/groups")
	call(http.MethodPost, "/api/v1/marco/sites/check")
	call(http.MethodPost, "/api/v1/preview")
	if len(store.logs) != 0 {
		t.Fatalf("reads and skipped requests must not be logged: %+v", store.logs)
	}
	call(http.MethodPost, "/api/v1/marco/groups")
	call(http.MethodPut, "/api/v1/monitoring/clients/inventory/x")
	call(http.MethodDelete, "/api/v1/marco/groups/1")
	call(http.MethodPost, "/api/v1/marco/terminal")
	if len(store.logs) != 4 {
		t.Fatalf("logged %d", len(store.logs))
	}
	first := store.logs[0]
	if first.Action != "create" || first.EntityType != "marco" || *first.Description != "POST /marco/groups" || !first.IsSuccess || first.PerformedBy == nil || first.Timestamp.IsZero() {
		t.Errorf("%+v", first)
	}
	if store.logs[1].Action != "update" || store.logs[1].EntityType != "monitoring" {
		t.Errorf("%+v", store.logs[1])
	}
	failed := store.logs[2]
	if failed.Action != "delete" || failed.IsSuccess || *failed.FailureReason != "HTTP 404" {
		t.Errorf("%+v", failed)
	}
	if *store.logs[3].Description != "/ip firewall filter remove" {
		t.Errorf("%+v", store.logs[3])
	}
}
