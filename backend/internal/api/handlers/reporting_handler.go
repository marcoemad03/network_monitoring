package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
	"github.com/hospital/nms-backend/internal/services"
)

type LogsHandler struct {
	loggingService *services.LoggingService
}

func NewLogsHandler(loggingService *services.LoggingService) *LogsHandler {
	return &LogsHandler{loggingService: loggingService}
}

func (h *LogsHandler) GetWebLogs(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var filter repository.WebLogFilter
	if deviceID := c.Query("device_id"); deviceID != "" {
		id := uuid.MustParse(deviceID)
		filter.DeviceID = &id
	}
	if domain := c.Query("domain"); domain != "" {
		filter.Domain = &domain
	}
	if category := c.Query("category"); category != "" {
		filter.Category = &category
	}
	if isBlocked := c.Query("is_blocked"); isBlocked != "" {
		b := isBlocked == "true"
		filter.IsBlocked = &b
	}
	if fromStr := c.Query("from"); fromStr != "" {
		t, err := time.Parse(time.RFC3339, fromStr)
		if err == nil {
			filter.FromTime = &t
		}
	}
	if toStr := c.Query("to"); toStr != "" {
		t, err := time.Parse(time.RFC3339, toStr)
		if err == nil {
			filter.ToTime = &t
		}
	}
	if search := c.Query("search"); search != "" {
		filter.Search = &search
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	filter.Page = page
	filter.Limit = limit

	logs, err := h.loggingService.GetWebLogs(c.Request.Context(), orgID, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch web logs", "error_code": "SERVER_ERROR"})
		return
	}
	if logs == nil {
		logs = []models.WebLog{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs, "message": "Web logs retrieved"})
}

func (h *LogsHandler) GetWebLogStats(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))

	stats, err := h.loggingService.GetWebLogStats(c.Request.Context(), orgID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch web log stats", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": stats, "message": "Web log stats retrieved"})
}

func (h *LogsHandler) GetConnectionLogs(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var filter repository.ConnectionLogFilter
	if deviceID := c.Query("device_id"); deviceID != "" {
		id := uuid.MustParse(deviceID)
		filter.DeviceID = &id
	}
	if protocol := c.Query("protocol"); protocol != "" {
		filter.Protocol = &protocol
	}
	if isActive := c.Query("is_active"); isActive != "" {
		b := isActive == "true"
		filter.IsActive = &b
	}
	if fromStr := c.Query("from"); fromStr != "" {
		t, err := time.Parse(time.RFC3339, fromStr)
		if err == nil {
			filter.FromTime = &t
		}
	}
	if toStr := c.Query("to"); toStr != "" {
		t, err := time.Parse(time.RFC3339, toStr)
		if err == nil {
			filter.ToTime = &t
		}
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	filter.Page = page
	filter.Limit = limit

	logs, err := h.loggingService.GetConnectionLogs(c.Request.Context(), orgID, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch connection logs", "error_code": "SERVER_ERROR"})
		return
	}
	if logs == nil {
		logs = []models.ConnectionLog{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs, "message": "Connection logs retrieved"})
}

func (h *LogsHandler) GetActiveConnections(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	conns, err := h.loggingService.GetActiveConnections(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch active connections", "error_code": "SERVER_ERROR"})
		return
	}
	if conns == nil {
		conns = []models.ConnectionLog{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": conns, "message": "Active connections retrieved"})
}

func (h *LogsHandler) GetDownloadLogs(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var filter repository.DownloadLogFilter
	if deviceID := c.Query("device_id"); deviceID != "" {
		id := uuid.MustParse(deviceID)
		filter.DeviceID = &id
	}
	if status := c.Query("status"); status != "" {
		filter.Status = &status
	}
	if fromStr := c.Query("from"); fromStr != "" {
		t, err := time.Parse(time.RFC3339, fromStr)
		if err == nil {
			filter.FromTime = &t
		}
	}
	if toStr := c.Query("to"); toStr != "" {
		t, err := time.Parse(time.RFC3339, toStr)
		if err == nil {
			filter.ToTime = &t
		}
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	filter.Page = page
	filter.Limit = limit

	logs, err := h.loggingService.GetDownloadLogs(c.Request.Context(), orgID, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch download logs", "error_code": "SERVER_ERROR"})
		return
	}
	if logs == nil {
		logs = []models.DownloadLog{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": logs, "message": "Download logs retrieved"})
}

type ReportsHandler struct {
	reportingService *services.ReportingService
}

func NewReportsHandler(reportingService *services.ReportingService) *ReportsHandler {
	return &ReportsHandler{reportingService: reportingService}
}

type generateReportRequest struct {
	ReportType  string `json:"report_type" binding:"required"`
	PeriodStart string `json:"period_start" binding:"required"`
	PeriodEnd   string `json:"period_end" binding:"required"`
}

func (h *ReportsHandler) GenerateReport(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var req generateReportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	periodStart, err := time.Parse("2006-01-02", req.PeriodStart)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid period_start format (use YYYY-MM-DD)", "error_code": "VALIDATION_ERROR"})
		return
	}
	periodEnd, err := time.Parse("2006-01-02", req.PeriodEnd)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid period_end format (use YYYY-MM-DD)", "error_code": "VALIDATION_ERROR"})
		return
	}

	cached, err := h.reportingService.GetCachedReport(c.Request.Context(), orgID, req.ReportType, periodStart, periodEnd)
	if err == nil && cached != nil {
		c.JSON(http.StatusOK, gin.H{"success": true, "data": cached, "message": "Report retrieved from cache"})
		return
	}

	from := periodStart
	to := periodEnd.Add(24*time.Hour - time.Second)

	topWebsites, _ := h.reportingService.GetTopWebsites(c.Request.Context(), orgID, from, to, 10)
	topUsers, _ := h.reportingService.GetTopUsers(c.Request.Context(), orgID, from, to, 10)
	deptReports, _ := h.reportingService.GetDepartmentReports(c.Request.Context(), orgID, from, to)

	var totalWebsites int
	var totalBandwidthMB int64
	var totalDurationMinutes int
	var uniqueDevices int
	var uniqueUsers int
	var blockedAttempts int

	if deptReports != nil {
		for _, d := range deptReports {
			totalBandwidthMB += d.TotalBytes / (1024 * 1024)
			totalWebsites += d.VisitCount
			uniqueDevices += d.UniqueDevices
			blockedAttempts += d.BlockedAttempts
		}
	}
	if topUsers != nil {
		uniqueUsers = len(topUsers)
	}
	for _, s := range topWebsites {
		totalDurationMinutes += s.TotalSeconds / 60
	}

	report := &models.ReportCache{
		ID:                   uuid.New(),
		OrganizationID:       orgID,
		ReportType:           req.ReportType,
		PeriodStart:          periodStart,
		PeriodEnd:            periodEnd,
		TotalWebsites:        totalWebsites,
		TotalBandwidthMB:     totalBandwidthMB,
		TotalDurationMinutes: totalDurationMinutes,
		UniqueDevices:        uniqueDevices,
		UniqueUsers:          uniqueUsers,
		BlockedAttempts:      blockedAttempts,
		GeneratedAt:          time.Now(),
	}
	report.Data = "{}"

	h.reportingService.UpsertReportCache(c.Request.Context(), report)

	c.JSON(http.StatusOK, gin.H{"success": true, "data": report, "message": "Report generated"})
}

func (h *ReportsHandler) GetReportsList(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	reportType := c.DefaultQuery("report_type", "daily")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))

	reports, err := h.reportingService.GetReportsByType(c.Request.Context(), orgID, reportType, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch reports", "error_code": "SERVER_ERROR"})
		return
	}
	if reports == nil {
		reports = []models.ReportCache{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": reports, "message": "Reports retrieved"})
}

func (h *ReportsHandler) GetReportDetail(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	reportType := c.Query("report_type")
	periodStartStr := c.Query("period_start")
	periodEndStr := c.Query("period_end")

	periodStart, _ := time.Parse("2006-01-02", periodStartStr)
	periodEnd, _ := time.Parse("2006-01-02", periodEndStr)

	report, err := h.reportingService.GetCachedReport(c.Request.Context(), orgID, reportType, periodStart, periodEnd)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Report not found", "error_code": "NOT_FOUND"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": report, "message": "Report retrieved"})
}

func (h *ReportsHandler) GetTopWebsites(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))

	sites, err := h.reportingService.GetTopWebsites(c.Request.Context(), orgID, from, to, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch top websites", "error_code": "SERVER_ERROR"})
		return
	}
	if sites == nil {
		sites = []models.TopWebsite{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": sites, "message": "Top websites retrieved"})
}

func (h *ReportsHandler) GetTopUsers(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))

	users, err := h.reportingService.GetTopUsers(c.Request.Context(), orgID, from, to, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch top users", "error_code": "SERVER_ERROR"})
		return
	}
	if users == nil {
		users = []models.TopUser{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": users, "message": "Top users retrieved"})
}

func (h *ReportsHandler) GetTopBandwidthConsumers(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))

	users, err := h.reportingService.GetTopUsers(c.Request.Context(), orgID, from, to, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch top bandwidth consumers", "error_code": "SERVER_ERROR"})
		return
	}

	results := make([]gin.H, 0)
	for _, u := range users {
		results = append(results, gin.H{
			"user_id":     u.UserID,
			"display_name": u.DisplayName,
			"total_bytes": u.TotalBytes,
		})
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": results, "message": "Top bandwidth consumers retrieved"})
}

func (h *ReportsHandler) GetDepartmentReports(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))

	depts, err := h.reportingService.GetDepartmentReports(c.Request.Context(), orgID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch department reports", "error_code": "SERVER_ERROR"})
		return
	}
	if depts == nil {
		depts = []models.DepartmentReport{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": depts, "message": "Department reports retrieved"})
}

type ExportsHandler struct {
	reportingService *services.ReportingService
}

func NewExportsHandler(reportingService *services.ReportingService) *ExportsHandler {
	return &ExportsHandler{reportingService: reportingService}
}

type generateExportRequest struct {
	ReportType  string `json:"report_type" binding:"required"`
	PeriodStart string `json:"period_start" binding:"required"`
	PeriodEnd   string `json:"period_end" binding:"required"`
	Format      string `json:"format" binding:"required"`
}

func (h *ExportsHandler) GenerateExport(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	userID := uuid.MustParse(c.GetString("user_id"))

	var req generateExportRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	periodStart, err := time.Parse("2006-01-02", req.PeriodStart)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid period_start format", "error_code": "VALIDATION_ERROR"})
		return
	}
	periodEnd, err := time.Parse("2006-01-02", req.PeriodEnd)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid period_end format", "error_code": "VALIDATION_ERROR"})
		return
	}

	now := time.Now()
	export := &models.ReportExport{
		ID:             uuid.New(),
		OrganizationID: orgID,
		ReportType:     req.ReportType,
		PeriodStart:    periodStart,
		PeriodEnd:      periodEnd,
		Format:         req.Format,
		Status:         "pending",
		GeneratedBy:    &userID,
		GeneratedAt:    &now,
		ExpiresAt:      func() *time.Time { t := now.Add(24 * time.Hour); return &t }(),
	}

	if err := h.reportingService.CreateExport(c.Request.Context(), export); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create export", "error_code": "SERVER_ERROR"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "data": export, "message": "Export created"})
}

func (h *ExportsHandler) GetExportsList(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var filter repository.ExportFilter
	if rt := c.Query("report_type"); rt != "" {
		filter.ReportType = &rt
	}
	if f := c.Query("format"); f != "" {
		filter.Format = &f
	}
	if s := c.Query("status"); s != "" {
		filter.Status = &s
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	filter.Page = page
	filter.Limit = limit

	exports, err := h.reportingService.GetExports(c.Request.Context(), orgID, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch exports", "error_code": "SERVER_ERROR"})
		return
	}
	if exports == nil {
		exports = []models.ReportExport{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": exports, "message": "Exports retrieved"})
}

func (h *ExportsHandler) DownloadExport(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid export ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	export, err := h.reportingService.GetExportByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Export not found", "error_code": "NOT_FOUND"})
		return
	}

	if export.FilePath == nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Export file not available", "error_code": "NOT_FOUND"})
		return
	}

	c.File(*export.FilePath)
}

func (h *ExportsHandler) DeleteExport(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid export ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	export, err := h.reportingService.GetExportByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Export not found", "error_code": "NOT_FOUND"})
		return
	}

	if err := h.reportingService.UpdateExportStatus(c.Request.Context(), export.ID, "deleted", nil, 0); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete export", "error_code": "SERVER_ERROR"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Export deleted"})
}

type AnalyticsHandler struct {
	analyticsService *services.AnalyticsService
}

func NewAnalyticsHandler(analyticsService *services.AnalyticsService) *AnalyticsHandler {
	return &AnalyticsHandler{analyticsService: analyticsService}
}

func (h *AnalyticsHandler) GetBandwidthOverTime(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-7*24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))
	interval := c.DefaultQuery("interval", "hourly")

	points, err := h.analyticsService.GetBandwidthOverTime(c.Request.Context(), orgID, from, to, interval)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch bandwidth data", "error_code": "SERVER_ERROR"})
		return
	}
	if points == nil {
		points = []repository.BandwidthPoint{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": points, "message": "Bandwidth data retrieved"})
}

func (h *AnalyticsHandler) GetAnalyticsSummary(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))

	stats, err := h.analyticsService.GetAnalyticsSummary(c.Request.Context(), orgID, from, to)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch analytics summary", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": stats, "message": "Analytics summary retrieved"})
}

func (h *AnalyticsHandler) GetDeviceAnalytics(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	deviceID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid device ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	from := parseTime(c.DefaultQuery("from", time.Now().Add(-24*time.Hour).Format(time.RFC3339)))
	to := parseTime(c.DefaultQuery("to", time.Now().Format(time.RFC3339)))

	var filter repository.WebLogFilter
	filter.DeviceID = &deviceID
	filter.FromTime = &from
	filter.ToTime = &to
	filter.Limit = 1000

	// For device analytics we reuse the web log infrastructure
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{
		"device_id":    deviceID,
		"organization_id": orgID,
		"from":        from,
		"to":          to,
	}, "message": "Device analytics retrieved"})
}

type AlertRulesHandler struct {
	alertRuleRepo *repository.AlertRuleRepository
	alertNotifRepo *repository.AlertNotificationRepository
}

func NewAlertRulesHandler(alertRuleRepo *repository.AlertRuleRepository, alertNotifRepo *repository.AlertNotificationRepository) *AlertRulesHandler {
	return &AlertRulesHandler{alertRuleRepo: alertRuleRepo, alertNotifRepo: alertNotifRepo}
}

func (h *AlertRulesHandler) ListAlertRules(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	rules, err := h.alertRuleRepo.GetAlertRules(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch alert rules", "error_code": "SERVER_ERROR"})
		return
	}
	if rules == nil {
		rules = []models.AlertRule{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rules, "message": "Alert rules retrieved"})
}

func (h *AlertRulesHandler) CreateAlertRule(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	userID := uuid.MustParse(c.GetString("user_id"))

	var rule models.AlertRule
	if err := c.ShouldBindJSON(&rule); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule.ID = uuid.New()
	rule.OrganizationID = orgID
	rule.CreatedBy = &userID
	rule.CreatedAt = time.Now()
	rule.UpdatedAt = time.Now()

	if err := h.alertRuleRepo.CreateAlertRule(c.Request.Context(), &rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create alert rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rule, "message": "Alert rule created"})
}

func (h *AlertRulesHandler) UpdateAlertRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	existing, err := h.alertRuleRepo.GetAlertRuleByID(c.Request.Context(), id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"success": false, "message": "Alert rule not found", "error_code": "NOT_FOUND"})
		return
	}

	var rule models.AlertRule
	if err := c.ShouldBindJSON(&rule); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	rule.ID = existing.ID
	rule.OrganizationID = existing.OrganizationID
	rule.CreatedBy = existing.CreatedBy
	rule.CreatedAt = existing.CreatedAt
	rule.UpdatedAt = time.Now()

	if err := h.alertRuleRepo.UpdateAlertRule(c.Request.Context(), &rule); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update alert rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": rule, "message": "Alert rule updated"})
}

func (h *AlertRulesHandler) DeleteAlertRule(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid rule ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.alertRuleRepo.DeleteAlertRule(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete alert rule", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Alert rule deleted"})
}

func (h *AlertRulesHandler) ListNotifications(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))

	var filter repository.NotificationFilter
	if severity := c.Query("severity"); severity != "" {
		filter.Severity = &severity
	}
	if isRead := c.Query("is_read"); isRead != "" {
		b := isRead == "true"
		filter.IsRead = &b
	}
	if fromStr := c.Query("from"); fromStr != "" {
		t, err := time.Parse(time.RFC3339, fromStr)
		if err == nil {
			filter.FromTime = &t
		}
	}
	if toStr := c.Query("to"); toStr != "" {
		t, err := time.Parse(time.RFC3339, toStr)
		if err == nil {
			filter.ToTime = &t
		}
	}
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	filter.Page = page
	filter.Limit = limit

	notifications, err := h.alertNotifRepo.GetNotifications(c.Request.Context(), orgID, filter)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch notifications", "error_code": "SERVER_ERROR"})
		return
	}
	if notifications == nil {
		notifications = []models.AlertNotification{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": notifications, "message": "Notifications retrieved"})
}

func (h *AlertRulesHandler) GetUnreadCount(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	count, err := h.alertNotifRepo.GetUnreadCount(c.Request.Context(), orgID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to get unread count", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": gin.H{"unread_count": count}, "message": "Unread count retrieved"})
}

func (h *AlertRulesHandler) MarkAsRead(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid notification ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.alertNotifRepo.MarkAsRead(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to mark as read", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Notification marked as read"})
}

func (h *AlertRulesHandler) Acknowledge(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid notification ID", "error_code": "VALIDATION_ERROR"})
		return
	}
	userID := uuid.MustParse(c.GetString("user_id"))

	if err := h.alertNotifRepo.AcknowledgeNotification(c.Request.Context(), id, userID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to acknowledge notification", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Notification acknowledged"})
}

type DashboardHandler struct {
	dashboardService *services.DashboardService
}

func NewDashboardHandler(dashboardService *services.DashboardService) *DashboardHandler {
	return &DashboardHandler{dashboardService: dashboardService}
}

func (h *DashboardHandler) GetUserWidgets(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	userID := uuid.MustParse(c.GetString("user_id"))

	widgets, err := h.dashboardService.GetUserWidgets(c.Request.Context(), orgID, userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to fetch widgets", "error_code": "SERVER_ERROR"})
		return
	}
	if widgets == nil {
		widgets = []models.DashboardWidget{}
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": widgets, "message": "Widgets retrieved"})
}

func (h *DashboardHandler) CreateWidget(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	userID := uuid.MustParse(c.GetString("user_id"))

	var widget models.DashboardWidget
	if err := c.ShouldBindJSON(&widget); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	widget.ID = uuid.New()
	widget.OrganizationID = orgID
	widget.UserID = &userID
	widget.CreatedAt = time.Now()
	widget.UpdatedAt = time.Now()

	if err := h.dashboardService.CreateWidget(c.Request.Context(), &widget); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to create widget", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": widget, "message": "Widget created"})
}

func (h *DashboardHandler) UpdateWidget(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid widget ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	orgID := uuid.MustParse(c.GetString("org_id"))

	var widget models.DashboardWidget
	if err := c.ShouldBindJSON(&widget); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	widget.ID = id
	widget.OrganizationID = orgID
	widget.UpdatedAt = time.Now()

	if err := h.dashboardService.UpdateWidget(c.Request.Context(), &widget); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to update widget", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "data": widget, "message": "Widget updated"})
}

func (h *DashboardHandler) DeleteWidget(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid widget ID", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.dashboardService.DeleteWidget(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to delete widget", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Widget deleted"})
}

type reorderRequest struct {
	Positions []repository.WidgetPosition `json:"positions" binding:"required"`
}

func (h *DashboardHandler) ReorderWidgets(c *gin.Context) {
	orgID := uuid.MustParse(c.GetString("org_id"))
	userID := uuid.MustParse(c.GetString("user_id"))

	var req reorderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "Invalid request", "error_code": "VALIDATION_ERROR"})
		return
	}

	if err := h.dashboardService.ReorderWidgets(c.Request.Context(), orgID, userID, req.Positions); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"success": false, "message": "Failed to reorder widgets", "error_code": "SERVER_ERROR"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"success": true, "message": "Widgets reordered"})
}

func parseTime(s string) time.Time {
	t, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return time.Now()
	}
	return t
}
