package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/services"
)

type DeviceHandler struct {
	deviceService *services.DeviceService
}

func NewDeviceHandler(deviceService *services.DeviceService) *DeviceHandler {
	return &DeviceHandler{deviceService: deviceService}
}

func (h *DeviceHandler) List(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	search := c.Query("search")
	status := c.Query("status")
	deviceType := c.Query("type")
	department := c.Query("department")
	sortBy := c.DefaultQuery("sort_by", "created_at")
	ascending := c.DefaultQuery("ascending", "true") == "true"

	devices, total, err := h.deviceService.List(c.Request.Context(), orgID, page, limit, search, status, deviceType, department, sortBy, ascending)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch devices",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if devices == nil {
		devices = []models.Device{}
	}

	totalPages := (total + limit - 1) / limit

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    devices,
		"message": "Devices retrieved",
		"meta": gin.H{
			"page":        page,
			"limit":       limit,
			"total":       total,
			"total_pages": totalPages,
		},
	})
}

func (h *DeviceHandler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	device, err := h.deviceService.GetByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false, "message": "Device not found",
			"error_code": "NOT_FOUND",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    device,
		"message": "Device retrieved",
	})
}

func (h *DeviceHandler) Create(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	device, _, ok := bindDevice(c)
	if !ok {
		return
	}

	device.OrganizationID = orgID

	if err := h.deviceService.Create(c.Request.Context(), &device, userID); err != nil {
		status, message := services.DescribeDeviceError(err)
		c.JSON(status, gin.H{"success": false, "message": message, "error_code": deviceErrorCode(status)})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"success": true,
		"data":    device,
		"message": "Device created",
	})
}

func (h *DeviceHandler) Update(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	device, present, ok := bindDevice(c)
	if !ok {
		return
	}

	device.ID = id

	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.deviceService.UpdateFields(c.Request.Context(), &device, present, userID); err != nil {
		status, message := services.DescribeDeviceError(err)
		c.JSON(status, gin.H{"success": false, "message": message, "error_code": deviceErrorCode(status)})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    device,
		"message": "Device updated",
	})
}

func (h *DeviceHandler) Delete(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	userID, err := parseUUID(c.GetString("user_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid user ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.deviceService.Delete(c.Request.Context(), id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to delete device",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Device deleted",
	})
}

func (h *DeviceHandler) GetInterfaces(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	ifaces, err := h.deviceService.GetInterfaces(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch interfaces",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    ifaces,
		"message": "Interfaces retrieved",
	})
}

func (h *DeviceHandler) GetMetrics(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid device ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	metrics, err := h.deviceService.GetMetrics(c.Request.Context(), id)
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
		"message": "Metrics retrieved",
	})
}

// bindDevice reads a device from the request body and also reports which JSON
// keys it contained. It answers the request itself when the body is unusable.
func bindDevice(c *gin.Context) (models.Device, map[string]bool, bool) {
	var device models.Device
	body, err := io.ReadAll(io.LimitReader(c.Request.Body, 1<<20))
	if err != nil || json.Unmarshal(body, &device) != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request. Check that the IP address and the other fields are written correctly.", "error_code": "VALIDATION_ERROR"})
		return device, nil, false
	}
	var keys map[string]json.RawMessage
	_ = json.Unmarshal(body, &keys)
	present := make(map[string]bool, len(keys))
	for k := range keys {
		present[k] = true
	}
	return device, present, true
}

func deviceErrorCode(status int) string {
	switch status {
	case http.StatusBadRequest:
		return "VALIDATION_ERROR"
	case http.StatusConflict:
		return "CONFLICT"
	}
	return "SERVER_ERROR"
}
