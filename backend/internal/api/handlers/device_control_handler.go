package handlers

import (
	"context"
	"net"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

func (h *DeviceControlHandler) ConnectDevelopmentMikroTik(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid development organization"})
		return
	}

	var req struct {
		RouterIP string `json:"router_ip" binding:"required"`
		Username string `json:"username" binding:"required"`
		Password string `json:"password"`
		APIPort  int    `json:"api_port" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Router IP, username and API port are required"})
		return
	}
	req.RouterIP = strings.TrimSpace(req.RouterIP)
	req.Username = strings.TrimSpace(req.Username)
	if net.ParseIP(req.RouterIP) == nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Enter a valid router IP address"})
		return
	}
	if req.APIPort != 8728 && req.APIPort != 8729 {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "API port must be 8728 or 8729"})
		return
	}

	result, err := h.discoverySvc.ConnectDevelopmentMikroTik(c.Request.Context(), orgID, req.RouterIP, req.Username, req.Password, req.APIPort)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": result.Connection.Reachable, "data": result, "message": result.Connection.Message})
}

type DeviceControlHandler struct {
	controlService *services.DeviceControlService
	eventService   *services.DeviceEventService
	discoverySvc   *services.EnhancedDiscoveryService
}

func NewDeviceControlHandler(controlService *services.DeviceControlService, eventService *services.DeviceEventService, discoverySvc *services.EnhancedDiscoveryService) *DeviceControlHandler {
	return &DeviceControlHandler{
		controlService: controlService,
		eventService:   eventService,
		discoverySvc:   discoverySvc,
	}
}

func (h *DeviceControlHandler) DiscoverDevices(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization"})
		return
	}

	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found"})
		return
	}

	devices, err := h.discoverySvc.DiscoverDevices172(c.Request.Context(), vendor, orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    devices,
		"message": "Discovery completed",
	})
}

func (h *DeviceControlHandler) GetConnectedDevices(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization"})
		return
	}
	var vendorID *uuid.UUID
	if raw := c.Query("vendor_id"); raw != "" {
		parsed, parseErr := uuid.Parse(raw)
		if parseErr != nil {
			c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
			return
		}
		vendorID = &parsed
	}
	result, err := h.discoverySvc.GetConnectedDevices(c.Request.Context(), orgID, vendorID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": result, "message": result.Connection.Message})
}

func (h *DeviceControlHandler) StartPolling(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization"})
		return
	}

	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	var req struct {
		IntervalSeconds int `json:"interval_seconds"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		req.IntervalSeconds = 30
	}

	_, err = h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor integration not found"})
		return
	}

	h.discoverySvc.StartPolling(c.Request.Context(), vendorID, orgID, time.Duration(req.IntervalSeconds)*time.Second)

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Polling started"})
}

func (h *DeviceControlHandler) StopPolling(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	h.discoverySvc.StopPolling(vendorID)
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Polling stopped"})
}

func (h *DeviceControlHandler) DisconnectDevice(c *gin.Context) {
	h.executeControl(c, h.controlService.DisconnectDevice)
}

func (h *DeviceControlHandler) ReconnectDevice(c *gin.Context) {
	h.executeControl(c, h.controlService.ReconnectDevice)
}

func (h *DeviceControlHandler) BlockInternet(c *gin.Context) {
	h.executeControl(c, h.controlService.BlockInternet)
}

func (h *DeviceControlHandler) UnblockInternet(c *gin.Context) {
	h.executeControl(c, h.controlService.UnblockInternet)
}

func (h *DeviceControlHandler) LimitSpeed(c *gin.Context) {
	orgID, deviceID, userID := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		DownloadLimit int64 `json:"download_limit" binding:"required"`
		UploadLimit   int64 `json:"upload_limit" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "download_limit and upload_limit required"})
		return
	}

	if err := h.controlService.LimitSpeed(c.Request.Context(), *deviceID, *orgID, userID, req.DownloadLimit, req.UploadLimit); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Speed limit applied"})
}

func (h *DeviceControlHandler) UnlimitedSpeed(c *gin.Context) {
	h.executeControl(c, func(ctx context.Context, deviceID, orgID, userID uuid.UUID) error {
		return h.controlService.UnlimitedSpeed(ctx, deviceID, orgID, userID)
	})
}

func (h *DeviceControlHandler) RenameDevice(c *gin.Context) {
	orgID, deviceID, userID := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		Name string `json:"name" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Name required"})
		return
	}

	if err := h.controlService.RenameDevice(c.Request.Context(), *deviceID, *orgID, userID, req.Name); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Device renamed"})
}

func (h *DeviceControlHandler) ChangeDepartment(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		Department string `json:"department" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Department required"})
		return
	}

	if err := h.controlService.ChangeDepartment(c.Request.Context(), *deviceID, *orgID, uuid.Nil, req.Department); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Department updated"})
}

func (h *DeviceControlHandler) ChangeRoom(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		Room string `json:"room" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Room required"})
		return
	}

	if err := h.controlService.ChangeRoom(c.Request.Context(), *deviceID, *orgID, uuid.Nil, req.Room); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Room updated"})
}

func (h *DeviceControlHandler) MoveToGroup(c *gin.Context) {
	orgID, deviceID, userID := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		GroupID string `json:"group_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "group_id required"})
		return
	}

	groupID, err := uuid.Parse(req.GroupID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid group ID"})
		return
	}

	if err := h.controlService.MoveToGroup(c.Request.Context(), *deviceID, groupID, *orgID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Device moved to group"})
}

func (h *DeviceControlHandler) PinDevice(c *gin.Context) {
	h.executeControl(c, h.controlService.PinDevice)
}

func (h *DeviceControlHandler) UnpinDevice(c *gin.Context) {
	h.executeControl(c, h.controlService.UnpinDevice)
}

func (h *DeviceControlHandler) MarkCritical(c *gin.Context) {
	h.executeControl(c, h.controlService.MarkCritical)
}

func (h *DeviceControlHandler) UnmarkCritical(c *gin.Context) {
	h.executeControl(c, h.controlService.UnmarkCritical)
}

func (h *DeviceControlHandler) AddNotes(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		Notes string `json:"notes"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request"})
		return
	}

	if err := h.controlService.AddNotes(c.Request.Context(), *deviceID, *orgID, uuid.Nil, req.Notes); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Notes updated"})
}

func (h *DeviceControlHandler) GetDeviceHistory(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	logs, err := h.controlService.ViewHistory(c.Request.Context(), *deviceID, *orgID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs})
}

func (h *DeviceControlHandler) ReserveDHCPIP(c *gin.Context) {
	orgID, deviceID, userID := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	var req struct {
		IPAddress  string `json:"ip_address" binding:"required"`
		MACAddress string `json:"mac_address" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "IP and MAC required"})
		return
	}

	if err := h.controlService.ReserveDHCPIP(c.Request.Context(), *deviceID, *orgID, userID, req.IPAddress, req.MACAddress); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "DHCP IP reserved"})
}

func (h *DeviceControlHandler) ViewActiveConnections(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	conns, err := h.controlService.ViewActiveConnections(c.Request.Context(), *deviceID, *orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": conns})
}

func (h *DeviceControlHandler) ViewCurrentBandwidth(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	metrics, err := h.controlService.ViewCurrentBandwidth(c.Request.Context(), *deviceID, *orgID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "No metrics available"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": metrics})
}

func (h *DeviceControlHandler) ViewHistoricalUsage(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	from := parseTimeQuery(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTimeQuery(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))

	usage, err := h.controlService.ViewHistoricalUsage(c.Request.Context(), *deviceID, *orgID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": usage})
}

func (h *DeviceControlHandler) GetDeviceEvents(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	eventType := c.Query("event_type")
	from := parseTimeQuery(c.DefaultQuery("from", ""))
	to := parseTimeQuery(c.DefaultQuery("to", ""))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	events, total, err := h.eventService.GetDeviceEvents(c.Request.Context(), *orgID, *deviceID, eventType, from, to, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    events,
		"total":   total,
	})
}

func (h *DeviceControlHandler) GetOrganizationEvents(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization"})
		return
	}

	eventType := c.Query("event_type")
	from := parseTimeQuery(c.DefaultQuery("from", ""))
	to := parseTimeQuery(c.DefaultQuery("to", ""))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	events, total, err := h.eventService.GetOrganizationEvents(c.Request.Context(), orgID, eventType, from, to, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    events,
		"total":   total,
	})
}

func (h *DeviceControlHandler) GetDeviceEventSummary(c *gin.Context) {
	orgID, deviceID, _ := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	summary, err := h.eventService.GetDeviceEventSummary(c.Request.Context(), *orgID, *deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": summary})
}

func (h *DeviceControlHandler) GetMikroTikInterfaces(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	ifaces, err := client.GetInterfacesDetail()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": ifaces})
}

func (h *DeviceControlHandler) GetMikroTikQueues(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	queues, err := client.GetSimpleQueues()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": queues})
}

func (h *DeviceControlHandler) GetMikroTikFirewallRules(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	rules, err := client.GetFirewallFilterRules()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": rules})
}

func (h *DeviceControlHandler) GetMikroTikAddressLists(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	lists, err := client.GetFirewallAddressLists()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": lists})
}

func (h *DeviceControlHandler) GetMikroTikDNS(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	entries, err := client.GetDNSStatic()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": entries})
}

func (h *DeviceControlHandler) GetMikroTikRouterIdentity(c *gin.Context) {
	vendorID, err := uuid.Parse(c.Param("vendorId"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid vendor ID"})
		return
	}

	vendor, err := h.getVendorIntegration(c, vendorID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Vendor not found"})
		return
	}

	client := h.createMikroTikClient(vendor)
	identity, err := client.GetRouterIdentity()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": identity})
}

func (h *DeviceControlHandler) createMikroTikClient(vendor *models.VendorIntegration) *models.MikroTikClientWrapper {
	password := ""
	if vendor.EncryptedPassword != nil {
		password = *vendor.EncryptedPassword
	}
	username := "admin"
	if vendor.Username != nil {
		username = *vendor.Username
	}
	host := vendor.BaseURL
	return models.NewMikroTikClientWrapper(host, username, password)
}

func (h *DeviceControlHandler) getVendorIntegration(c *gin.Context, vendorID uuid.UUID) (*models.VendorIntegration, error) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		return nil, err
	}
	return h.discoverySvc.GetVendorIntegration(c.Request.Context(), vendorID, orgID)
}

type controlFunc func(ctx context.Context, deviceID, orgID, userID uuid.UUID) error

func (h *DeviceControlHandler) executeControl(c *gin.Context, fn controlFunc) {
	orgID, deviceID, userID := h.extractContext(c)
	if deviceID == nil || orgID == nil {
		return
	}

	if err := fn(c.Request.Context(), *deviceID, *orgID, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Action completed"})
}

func (h *DeviceControlHandler) extractContext(c *gin.Context) (*uuid.UUID, *uuid.UUID, uuid.UUID) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization"})
		return nil, nil, uuid.Nil
	}

	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID"})
		return nil, nil, uuid.Nil
	}

	userID, _ := parseUUID(c.GetString("user_id"))
	return &orgID, &deviceID, userID
}

func parseTimeQuery(s string) time.Time {
	if s == "" {
		return time.Time{}
	}
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Time{}
	}
	return t
}

func strPtr(s string) *string {
	return &s
}
