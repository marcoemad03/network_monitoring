package handlers

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type MonitoringHandler struct {
	monitoringService *services.MonitoringService
}

func NewMonitoringHandler(monitoringService *services.MonitoringService) *MonitoringHandler {
	return &MonitoringHandler{monitoringService: monitoringService}
}

func (h *MonitoringHandler) GetDashboardSummary(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	summary, err := h.monitoringService.GetDashboardSummary(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get dashboard summary",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    summary,
		"message": "Dashboard summary retrieved",
	})
}

func (h *MonitoringHandler) GetDeviceClients(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	clients, err := h.monitoringService.GetDeviceClients(c.Request.Context(), deviceID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get device clients",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if clients == nil {
		clients = []models.DeviceClient{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    clients,
		"message": "Device clients retrieved",
	})
}

func (h *MonitoringHandler) GetAllClients(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	clients, err := h.monitoringService.GetAllClients(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get clients",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if clients == nil {
		clients = []models.DeviceClient{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    clients,
		"message": "Clients retrieved",
	})
}

func (h *MonitoringHandler) GetConnections(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	connections, err := h.monitoringService.GetConnections(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get connections",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if connections == nil {
		connections = []models.DeviceConnection{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    connections,
		"message": "Connections retrieved",
	})
}

func (h *MonitoringHandler) GetDeviceLatestMetrics(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	metrics, err := h.monitoringService.GetLatestMetrics(c.Request.Context(), deviceID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false, "message": "No metrics available",
			"error_code": "NOT_FOUND",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    metrics,
		"message": "Latest metrics retrieved",
	})
}

func (h *MonitoringHandler) GetDeviceMetricsHistory(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	fromStr := c.DefaultQuery("from", time.Now().Add(-1*time.Hour).Format(time.RFC3339))
	toStr := c.DefaultQuery("to", time.Now().Format(time.RFC3339))

	from, err := time.Parse(time.RFC3339, fromStr)
	if err != nil {
		from = time.Now().Add(-1 * time.Hour)
	}
	to, err := time.Parse(time.RFC3339, toStr)
	if err != nil {
		to = time.Now()
	}

	history, err := h.monitoringService.GetMetricsHistory(c.Request.Context(), deviceID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get metrics history",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if history == nil {
		history = []models.DeviceMetrics{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    history,
		"message": "Metrics history retrieved",
	})
}

func (h *MonitoringHandler) GetDevicePingHistory(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	fromStr := c.DefaultQuery("from", time.Now().Add(-1*time.Hour).Format(time.RFC3339))
	toStr := c.DefaultQuery("to", time.Now().Format(time.RFC3339))

	from, _ := time.Parse(time.RFC3339, fromStr)
	to, _ := time.Parse(time.RFC3339, toStr)
	if to.IsZero() {
		to = time.Now()
	}
	if from.IsZero() {
		from = to.Add(-1 * time.Hour)
	}

	history, err := h.monitoringService.GetPingHistory(c.Request.Context(), deviceID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get ping history",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if history == nil {
		history = []models.DevicePing{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    history,
		"message": "Ping history retrieved",
	})
}

func (h *MonitoringHandler) GetDeviceTrafficHistory(c *gin.Context) {
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	fromStr := c.DefaultQuery("from", time.Now().Add(-1*time.Hour).Format(time.RFC3339))
	toStr := c.DefaultQuery("to", time.Now().Format(time.RFC3339))

	from, _ := time.Parse(time.RFC3339, fromStr)
	to, _ := time.Parse(time.RFC3339, toStr)
	if to.IsZero() {
		to = time.Now()
	}
	if from.IsZero() {
		from = to.Add(-1 * time.Hour)
	}

	history, err := h.monitoringService.GetTrafficHistory(c.Request.Context(), deviceID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to get traffic history",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if history == nil {
		history = []models.DeviceTraffic{}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    history,
		"message": "Traffic history retrieved",
	})
}
