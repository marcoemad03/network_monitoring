package handlers

import (
	"bytes"
	"encoding/csv"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type AuditHandler struct {
	auditRepo *repository.AuditRepository
}

func NewAuditHandler(auditRepo *repository.AuditRepository) *AuditHandler {
	return &AuditHandler{auditRepo: auditRepo}
}

func (h *AuditHandler) List(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	action := c.Query("action")
	entityType := c.Query("entity_type")
	performedBy := c.Query("performed_by")

	var from, to time.Time
	if f := c.Query("from"); f != "" {
		from, _ = time.Parse(time.RFC3339, f)
	}
	if t := c.Query("to"); t != "" {
		to, _ = time.Parse(time.RFC3339, t)
	}

	logs, total, err := h.auditRepo.List(c.Request.Context(), orgID, page, limit, action, entityType, performedBy, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false, "message": "Failed to fetch audit logs",
			"error_code": "SERVER_ERROR",
		})
		return
	}

	if logs == nil {
		logs = []models.AuditLog{}
	}
	totalPages := (total + limit - 1) / limit
	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data":    logs,
		"message": "Audit logs retrieved",
		"meta": gin.H{
			"page": page, "limit": limit,
			"total": total, "total_pages": totalPages,
		},
	})
}

func (h *AuditHandler) Export(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	var from, to time.Time
	if f := c.Query("from"); f != "" {
		from, _ = time.Parse(time.RFC3339, f)
	}
	if t := c.Query("to"); t != "" {
		to, _ = time.Parse(time.RFC3339, t)
	}
	logs, _, err := h.auditRepo.List(c.Request.Context(), orgID, 1, 10000, c.Query("action"), c.Query("entity_type"), "", from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch audit logs", "error_code": "SERVER_ERROR"})
		return
	}
	var buf bytes.Buffer
	buf.WriteString("\xEF\xBB\xBF")
	w := csv.NewWriter(&buf)
	_ = w.Write([]string{"Time", "Action", "Area", "What", "Result", "Reason"})
	for _, l := range logs {
		result, what, reason := "Success", "", ""
		if !l.IsSuccess {
			result = "Failed"
		}
		if l.Description != nil {
			what = *l.Description
		}
		if l.FailureReason != nil {
			reason = *l.FailureReason
		}
		_ = w.Write([]string{l.Timestamp.Format("2006-01-02 15:04:05"), l.Action, l.EntityType, "'" + what, result, reason})
	}
	w.Flush()
	c.Header("Content-Disposition", `attachment; filename="audit-log-`+time.Now().Format("2006-01-02")+`.csv"`)
	c.Header("X-Content-Type-Options", "nosniff")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", buf.Bytes())
}

func (h *AuditHandler) GetDashboardSummary(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	_ = orgID

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"data": gin.H{
			"total_devices":       0,
			"online_devices":      0,
			"offline_devices":     0,
			"degraded_devices":    0,
			"maintenance_devices": 0,
			"critical_alerts":     0,
			"high_alerts":         0,
			"medium_alerts":       0,
			"low_alerts":          0,
			"open_alerts":         0,
			"acknowledged_alerts": 0,
			"active_scans":        0,
			"new_devices_today":   0,
			"events_last_hour":    0,
		},
		"message": "Dashboard summary retrieved",
	})
}
