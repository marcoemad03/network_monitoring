package handlers

import (
	"errors"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/hospital/nms-backend/internal/services"
)

// UsageReportHandler serves the Reports & Analytics page.
type UsageReportHandler struct {
	service *services.UsageReportService
}

func NewUsageReportHandler(service *services.UsageReportService) *UsageReportHandler {
	return &UsageReportHandler{service: service}
}

func (h *UsageReportHandler) fail(c *gin.Context, err error) {
	var bad *services.ReportRangeError
	if errors.As(err, &bad) {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": bad.Message, "error_code": "VALIDATION_ERROR"})
		return
	}
	c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to build the report", "error_code": "SERVER_ERROR"})
}

// Usage returns the report for ?from=YYYY-MM-DD&to=YYYY-MM-DD (both days included).
func (h *UsageReportHandler) Usage(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	from, to, err := services.ParseReportRange(c.Query("from"), c.Query("to"), time.Now())
	if err != nil {
		h.fail(c, err)
		return
	}
	report, err := h.service.Build(c.Request.Context(), orgID, from, to)
	if err != nil {
		h.fail(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": report, "message": "Report built"})
}

// Export returns one view of the report as a CSV file.
func (h *UsageReportHandler) Export(c *gin.Context) {
	orgID, err := parseUUID(c.GetString("org_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid organization", "error_code": "VALIDATION_ERROR"})
		return
	}
	from, to, err := services.ParseReportRange(c.Query("from"), c.Query("to"), time.Now())
	if err != nil {
		h.fail(c, err)
		return
	}
	name, data, err := h.service.ExportUsageCSV(c.Request.Context(), orgID, from, to, c.Query("view"))
	if err != nil {
		h.fail(c, err)
		return
	}
	c.Header("Content-Disposition", `attachment; filename="`+name+`"`)
	c.Header("X-Content-Type-Options", "nosniff")
	c.Data(http.StatusOK, "text/csv; charset=utf-8", data)
}
