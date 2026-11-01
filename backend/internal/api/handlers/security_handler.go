package handlers

import (
	"context"
	"errors"
	"net"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
	"github.com/hospital/nms-backend/pkg/logger"
)

// SecurityHandler serves the security page: what devices are connected to,
// findings worth a look, and the scan that produces them.
type SecurityHandler struct {
	service   *services.SecurityScanService
	auditRepo *repository.AuditRepository
}

func NewSecurityHandler(service *services.SecurityScanService, auditRepo *repository.AuditRepository) *SecurityHandler {
	return &SecurityHandler{service: service, auditRepo: auditRepo}
}

type scanMeta struct {
	TakenAt         time.Time `json:"taken_at"`
	DurationMs      int       `json:"duration_ms"`
	Connections     int       `json:"connections"`
	RouterCPUBefore int       `json:"router_cpu_before"`
	RouterCPUAfter  int       `json:"router_cpu_after"`
	PlatformLists   int       `json:"platform_lists_read"`
	Restored        bool      `json:"restored"`
}

type scanSettings struct {
	Scanning            bool     `json:"scanning"`
	LastError           string   `json:"last_error,omitempty"`
	CooldownSeconds     int      `json:"cooldown_seconds"`
	AutoIntervalSeconds int      `json:"auto_interval_seconds"`
	MaxRouterCPU        int      `json:"max_router_cpu"`
	RetentionDays       int      `json:"retention_days"`
	PlatformsFromRouter []string `json:"platforms_from_router"`
}

type newDevice struct {
	MAC       string     `json:"mac"`
	IP        string     `json:"ip"`
	Name      string     `json:"name"`
	Kind      string     `json:"kind"`
	Vendor    string     `json:"vendor,omitempty"`
	Online    bool       `json:"online"`
	FirstSeen *time.Time `json:"first_seen"`
}

type securitySummary struct {
	Devices     int `json:"devices"`
	Connections int `json:"connections"`
	High        int `json:"findings_high"`
	Medium      int `json:"findings_medium"`
	NewDevices  int `json:"new_devices"`
}

type securityOverview struct {
	Scanned      bool                       `json:"scanned"`
	Scan         *scanMeta                  `json:"scan,omitempty"`
	Settings     scanSettings               `json:"settings"`
	Summary      securitySummary            `json:"summary"`
	Findings     []services.Finding         `json:"findings"`
	Devices      []services.DeviceActivity  `json:"devices"`
	TopByData    []services.DestinationStat `json:"top_by_data"`
	TopByDevices []services.DestinationStat `json:"top_by_devices"`
	Popular      []repository.PopularLabel  `json:"popular_7d"`
	NewDevices   []newDevice                `json:"new_devices"`
	// MonitoringSince is when devices started being recorded; before a full day has
	// passed, "new" is not meaningful.
	MonitoringSince *time.Time `json:"monitoring_since,omitempty"`
}

func (h *SecurityHandler) orgID(c *gin.Context) (uuid.UUID, bool) {
	id, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return uuid.Nil, false
	}
	return id, true
}

func (h *SecurityHandler) overview(ctx context.Context, orgID uuid.UUID) securityOverview {
	status := h.service.Status(orgID)
	out := securityOverview{
		Settings: scanSettings{
			Scanning: status.Scanning, LastError: status.LastError, CooldownSeconds: int(status.CooldownLeft.Seconds()),
			AutoIntervalSeconds: int(status.AutoInterval.Seconds()), MaxRouterCPU: status.MaxCPU, RetentionDays: status.RetentionDays,
			PlatformsFromRouter: status.HasPlatformFor,
		},
		Findings: []services.Finding{}, Devices: []services.DeviceActivity{},
		TopByData: []services.DestinationStat{}, TopByDevices: []services.DestinationStat{},
		Popular: []repository.PopularLabel{}, NewDevices: []newDevice{},
	}
	if out.Settings.PlatformsFromRouter == nil {
		out.Settings.PlatformsFromRouter = []string{}
	}

	if fresh := h.service.NewDevices(ctx, orgID, time.Now().Add(-24*time.Hour)); len(fresh) > 0 {
		for _, c := range fresh {
			out.NewDevices = append(out.NewDevices, newDevice{MAC: c.MAC, IP: c.IP, Name: c.DisplayName, Kind: c.Kind, Vendor: c.Vendor, Online: c.Online, FirstSeen: c.FirstSeen})
		}
	}
	out.Summary.NewDevices = len(out.NewDevices)
	out.MonitoringSince = h.service.MonitoringSince(ctx, orgID)

	if popular, err := h.service.Popular(ctx, orgID, 7); err == nil {
		out.Popular = popular
	}

	snap := h.service.Latest(ctx, orgID)
	if snap == nil {
		return out
	}
	out.Scanned = true
	out.Scan = &scanMeta{
		TakenAt: snap.TakenAt, DurationMs: snap.DurationMs, Connections: snap.Connections, RouterCPUBefore: snap.RouterCPUBefore,
		RouterCPUAfter: snap.RouterCPUAfter, PlatformLists: snap.PlatformLists, Restored: snap.Restored,
	}
	out.Summary.Devices, out.Summary.Connections = len(snap.Devices), snap.Connections
	for _, f := range snap.Findings {
		switch f.Severity {
		case services.SeverityHigh:
			out.Summary.High++
		case services.SeverityMedium:
			out.Summary.Medium++
		}
	}
	if len(snap.Findings) > 40 {
		out.Findings = snap.Findings[:40]
	} else {
		out.Findings = snap.Findings
	}
	for _, d := range snap.Devices {
		d.Flows = nil // the connection list is only sent with a single device
		if len(d.Top) > 6 {
			d.Top = d.Top[:6]
		}
		out.Devices = append(out.Devices, d)
	}
	dests := append([]services.DestinationStat(nil), snap.Destinations...)
	out.TopByData = topDestinations(dests, func(a, b services.DestinationStat) bool { return a.Down+a.Up > b.Down+b.Up }, 10)
	out.TopByDevices = topDestinations(dests, func(a, b services.DestinationStat) bool {
		if a.Devices != b.Devices {
			return a.Devices > b.Devices
		}
		return a.Connections > b.Connections
	}, 10)
	return out
}

// topDestinations returns the first n destinations in the given order, leaving
// out traffic between devices inside the network.
func topDestinations(all []services.DestinationStat, less func(a, b services.DestinationStat) bool, n int) []services.DestinationStat {
	var kept []services.DestinationStat
	for _, d := range all {
		if d.Kind != services.LabelInternal {
			kept = append(kept, d)
		}
	}
	for i := 1; i < len(kept); i++ { // small lists: an insertion sort keeps this dependency-free
		for j := i; j > 0 && less(kept[j], kept[j-1]); j-- {
			kept[j], kept[j-1] = kept[j-1], kept[j]
		}
	}
	if len(kept) > n {
		kept = kept[:n]
	}
	return kept
}

// Overview returns the latest scan, findings, rankings and new devices.
func (h *SecurityHandler) Overview(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": h.overview(c.Request.Context(), orgID), "message": "Security overview retrieved"})
}

// Scan reads the router's connection table now.
func (h *SecurityHandler) Scan(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	h.audit(c, orgID, "security.scan_started", "connection table", "")

	if _, err := h.service.Scan(c.Request.Context(), orgID); err != nil {
		var cool *services.ScanCooldownError
		var busy *services.RouterBusyError
		switch {
		case errors.As(err, &cool):
			c.JSON(http.StatusTooManyRequests, gin.H{"success": false, "message": err.Error(), "error_code": "COOLDOWN", "retry_after_seconds": int(cool.RetryAfter.Seconds()) + 1})
		case errors.Is(err, services.ErrScanBusy):
			c.JSON(http.StatusConflict, gin.H{"success": false, "message": err.Error(), "error_code": "SCAN_RUNNING"})
		case errors.As(err, &busy):
			c.JSON(http.StatusServiceUnavailable, gin.H{"success": false, "message": busy.Reason, "error_code": "ROUTER_BUSY", "router_cpu": busy.CPU})
		default:
			c.JSON(http.StatusBadGateway, gin.H{"success": false, "message": err.Error(), "error_code": "ROUTER_ERROR"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": h.overview(c.Request.Context(), orgID), "message": "Scan finished"})
}

type deviceDetail struct {
	Device  services.DeviceActivity   `json:"device"`
	History []repository.PopularLabel `json:"history_7d"`
	Scan    scanMeta                  `json:"scan"`
}

// Device returns what the latest scan saw for one device, by MAC or IP.
func (h *SecurityHandler) Device(c *gin.Context) {
	orgID, ok := h.orgID(c)
	if !ok {
		return
	}
	device, snap := h.service.Device(c.Request.Context(), orgID, c.Param("key"))
	if snap == nil || device == nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "No scan has seen this device", "error_code": "NOT_FOUND"})
		return
	}
	h.audit(c, orgID, "security.device_activity_viewed", device.Name, device.MAC)

	history, err := h.service.DeviceHistory(c.Request.Context(), orgID, device.MAC, 7)
	if err != nil {
		history = []repository.PopularLabel{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": deviceDetail{
		Device: *device, History: history,
		Scan: scanMeta{TakenAt: snap.TakenAt, DurationMs: snap.DurationMs, Connections: snap.Connections, Restored: snap.Restored},
	}, "message": "Device activity retrieved"})
}

// audit records who looked at what. Looking at a person's activity is itself
// something worth being able to account for. A failure to record is logged and
// does not stop the request.
func (h *SecurityHandler) audit(c *gin.Context, orgID uuid.UUID, action, name, detail string) {
	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		return
	}
	entry := &models.AuditLog{
		ID: uuid.New(), OrganizationID: orgID, Action: action, EntityType: "security", EntityName: &name,
		PerformedBy: &userID, IsSuccess: true,
	}
	if ip := net.ParseIP(c.ClientIP()); ip != nil {
		entry.IPAddress = &ip
	}
	if detail != "" {
		entry.Description = &detail
	}
	if err := h.auditRepo.Create(c.Request.Context(), entry); err != nil {
		logger.Debug("Audit entry not stored", "action", action, "error", err)
	}
}
