package handlers

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/services"
)

type AlertHandler struct {
	alertService *services.AlertService
}

func NewAlertHandler(alertService *services.AlertService) *AlertHandler {
	return &AlertHandler{alertService: alertService}
}

func (h *AlertHandler) List(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	status := c.Query("status")
	severity := c.Query("severity")
	category := c.Query("category")
	deviceID := c.Query("device_id")
	sortBy := c.DefaultQuery("sort_by", "detected_at")
	ascending := c.DefaultQuery("ascending", "false") == "true"

	alerts, total, err := h.alertService.List(c.Request.Context(), orgID, page, limit, status, severity, category, deviceID, sortBy, ascending)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch alerts",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	totalPages := (total + limit - 1) / limit

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    alerts,
		"message": "Alerts retrieved",
		"meta": gin.H{
			"page":        page,
			"limit":       limit,
			"total":       total,
			"total_pages": totalPages,
		},
	})
}

func (h *AlertHandler) Get(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid alert ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	alert, err := h.alertService.GetByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false, "message": "Alert not found",
			"error_code": "NOT_FOUND",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    alert,
		"message": "Alert retrieved",
	})
}

type acknowledgeRequest struct {
	Notes string `json:"notes"`
}

func (h *AlertHandler) Acknowledge(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid alert ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	var req acknowledgeRequest
	c.ShouldBindJSON(&req)
	userID := uuid.MustParse(c.GetString("user_id"))

	if err := h.alertService.Acknowledge(c.Request.Context(), id, userID, req.Notes); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to acknowledge alert",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Alert acknowledged",
	})
}

type resolveRequest struct {
	ResolutionNotes string `json:"resolution_notes" binding:"required"`
}

func (h *AlertHandler) Resolve(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Invalid alert ID",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}

	var req resolveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false, "message": "Resolution notes are required",
			"error_code": "VALIDATION_ERROR",
		})
		return
	}
	userID := uuid.MustParse(c.GetString("user_id"))

	if err := h.alertService.Resolve(c.Request.Context(), id, userID, req.ResolutionNotes); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to resolve alert",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Alert resolved",
	})
}
