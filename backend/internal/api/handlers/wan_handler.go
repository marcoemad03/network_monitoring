package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
)

// WANHandler serves the internet speed and usage measured on the router.
type WANHandler struct {
	telemetry *services.RouterTelemetryService
	repo      *repository.WANRepository
	interval  time.Duration
}

func NewWANHandler(telemetry *services.RouterTelemetryService, repo *repository.WANRepository, interval time.Duration) *WANHandler {
	return &WANHandler{telemetry: telemetry, repo: repo, interval: interval}
}

type wanCurrent struct {
	DownloadBps int64     `json:"download_bps"`
	UploadBps   int64     `json:"upload_bps"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type wanSinceBoot struct {
	DownloadBytes int64 `json:"download_bytes"`
	UploadBytes   int64 `json:"upload_bytes"`
	UptimeSeconds int64 `json:"uptime_seconds"`
}

type wanUsagePeriods struct {
	Today repository.WANUsage `json:"today"`
	Month repository.WANUsage `json:"month"`
}

type wanResponse struct {
	// Available is false until the first measurement succeeds; Error then says why.
	Available bool   `json:"available"`
	Error     string `json:"error,omitempty"`
	// Stale means the latest measurement is older than a few polling intervals.
	Stale         bool                    `json:"stale"`
	Interface     string                  `json:"interface,omitempty"`
	LinkRunning   bool                    `json:"link_running"`
	Current       *wanCurrent             `json:"current,omitempty"`
	SinceBoot     *wanSinceBoot           `json:"since_boot,omitempty"`
	Router        *services.RouterHealth  `json:"router,omitempty"`
	Usage         wanUsagePeriods         `json:"usage"`
	TrackingSince *time.Time              `json:"tracking_since,omitempty"`
	Live          []services.WANLivePoint `json:"live"`
	LastHour      []repository.WANPoint   `json:"last_hour"`
	Daily         []repository.WANDay     `json:"daily"`
}

// Get returns speed, usage totals and chart series.
func (h *WANHandler) Get(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	ctx := c.Request.Context()
	now := time.Now()
	todayStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, now.Location())
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, now.Location())

	resp := wanResponse{Live: h.telemetry.Live(orgID), LastHour: []repository.WANPoint{}, Daily: []repository.WANDay{}}

	if snap, ok := h.telemetry.Snapshot(orgID); ok {
		resp.Available = true
		resp.Interface = snap.Interface
		resp.LinkRunning = snap.Running
		resp.Current = &wanCurrent{DownloadBps: snap.DownloadBps, UploadBps: snap.UploadBps, UpdatedAt: snap.UpdatedAt}
		resp.SinceBoot = &wanSinceBoot{DownloadBytes: snap.DownloadBytesSinceBoot, UploadBytes: snap.UploadBytesSinceBoot, UptimeSeconds: snap.Router.UptimeSeconds}
		router := snap.Router
		resp.Router = &router
		resp.Stale = now.Sub(snap.UpdatedAt) > 4*h.interval
		resp.Error = snap.Error
	} else {
		resp.Error = h.telemetry.LastError(orgID)
	}

	var dbErr error
	if resp.Usage.Today, dbErr = h.repo.Usage(ctx, orgID, todayStart); dbErr == nil {
		resp.Usage.Month, dbErr = h.repo.Usage(ctx, orgID, monthStart)
	}
	if dbErr == nil {
		if points, err := h.repo.History(ctx, orgID, now.Add(-time.Hour)); err == nil {
			resp.LastHour = points
		}
		if days, err := h.repo.Daily(ctx, orgID, todayStart.AddDate(0, 0, -6)); err == nil {
			resp.Daily = days
		}
		if first, err := h.repo.FirstSampleAt(ctx, orgID); err == nil && !first.IsZero() {
			resp.TrackingSince = &first
		}
	} else {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to read usage", "error_code": "DB_ERROR"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": resp, "message": "Internet usage retrieved"})
}
