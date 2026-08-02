package handlers

import (
	"context"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/logger"
)

type MikroTikStatus struct {
	Status   string `json:"status"`
	RouterIP string `json:"router_ip"`
}

type HealthHandler struct {
	db           *database.DB
	discoverySvc *services.EnhancedDiscoveryService
	startTime    time.Time
	version      string
}

func NewHealthHandler(db *database.DB, discoverySvc *services.EnhancedDiscoveryService) *HealthHandler {
	return &HealthHandler{
		db:           db,
		discoverySvc: discoverySvc,
		startTime:    time.Now(),
		version:      "1.0.0",
	}
}

type HealthResponse struct {
	Status   string `json:"status"`
	Server   string `json:"server"`
	Database string `json:"database"`
	MikroTik string `json:"mikrotik,omitempty"`
	RouterIP string `json:"router,omitempty"`
	Version  string `json:"version"`
	Uptime   string `json:"uptime"`
}

func (h *HealthHandler) Check(c *gin.Context) {
	resp := HealthResponse{
		Server:  "running",
		Version: h.version,
		Uptime:  time.Since(h.startTime).Round(time.Second).String(),
	}

	ctx, cancel := context.WithTimeout(c.Request.Context(), 3*time.Second)
	defer cancel()
	if err := h.db.Pool.Ping(ctx); err != nil {
		resp.Database = "disconnected"
		resp.Status = "degraded"
		logger.Warn("Health check: database ping failed", "error", err)
	} else {
		resp.Database = "connected"
	}

	if h.discoverySvc != nil {
		resp.MikroTik = "unknown"
		resp.RouterIP = ""
	}

	if resp.Status == "" {
		resp.Status = "ok"
	}

	c.JSON(http.StatusOK, resp)
}
