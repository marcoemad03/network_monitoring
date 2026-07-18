package services

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/models"
	"github.com/hospital/nms-backend/internal/repository"
)

type LoggingService struct {
	webLogRepo   *repository.WebLogRepository
	connLogRepo  *repository.ConnectionLogRepository
	downLogRepo  *repository.DownloadLogRepository
}

func NewLoggingService(webLogRepo *repository.WebLogRepository, connLogRepo *repository.ConnectionLogRepository, downLogRepo *repository.DownloadLogRepository) *LoggingService {
	return &LoggingService{
		webLogRepo:  webLogRepo,
		connLogRepo: connLogRepo,
		downLogRepo: downLogRepo,
	}
}

func (s *LoggingService) InsertWebLog(ctx context.Context, w *models.WebLog) error {
	return s.webLogRepo.InsertWebLog(ctx, w)
}

func (s *LoggingService) GetWebLogs(ctx context.Context, orgID uuid.UUID, filter repository.WebLogFilter) ([]models.WebLog, error) {
	return s.webLogRepo.GetWebLogs(ctx, orgID, filter)
}

func (s *LoggingService) GetWebLogStats(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*repository.WebLogStats, error) {
	return s.webLogRepo.GetWebLogStats(ctx, orgID, from, to)
}

func (s *LoggingService) GetTopWebsites(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopWebsite, error) {
	return s.webLogRepo.GetTopWebsites(ctx, orgID, from, to, limit)
}

func (s *LoggingService) GetTopUsers(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopUser, error) {
	return s.webLogRepo.GetTopUsers(ctx, orgID, from, to, limit)
}

func (s *LoggingService) GetDepartmentReports(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]models.DepartmentReport, error) {
	return s.webLogRepo.GetDepartmentReports(ctx, orgID, from, to)
}

func (s *LoggingService) InsertConnectionLog(ctx context.Context, c *models.ConnectionLog) error {
	return s.connLogRepo.InsertConnectionLog(ctx, c)
}

func (s *LoggingService) UpdateConnectionEnd(ctx context.Context, id uuid.UUID, endTime time.Time, bytesSent, bytesReceived int64, packetsSent, packetsReceived, durationSeconds int) error {
	return s.connLogRepo.UpdateConnectionEnd(ctx, id, endTime, bytesSent, bytesReceived, packetsSent, packetsReceived, durationSeconds)
}

func (s *LoggingService) GetActiveConnections(ctx context.Context, orgID uuid.UUID) ([]models.ConnectionLog, error) {
	return s.connLogRepo.GetActiveConnections(ctx, orgID)
}

func (s *LoggingService) GetConnectionLogs(ctx context.Context, orgID uuid.UUID, filter repository.ConnectionLogFilter) ([]models.ConnectionLog, error) {
	return s.connLogRepo.GetConnectionLogs(ctx, orgID, filter)
}

func (s *LoggingService) GetActiveConnectionCount(ctx context.Context, orgID uuid.UUID) (int, error) {
	return s.connLogRepo.GetActiveConnectionCount(ctx, orgID)
}

func (s *LoggingService) InsertDownloadLog(ctx context.Context, d *models.DownloadLog) error {
	return s.downLogRepo.InsertDownloadLog(ctx, d)
}

func (s *LoggingService) UpdateDownloadStatus(ctx context.Context, id uuid.UUID, status string, endTime time.Time, durationSeconds int) error {
	return s.downLogRepo.UpdateDownloadStatus(ctx, id, status, endTime, durationSeconds)
}

func (s *LoggingService) GetDownloadLogs(ctx context.Context, orgID uuid.UUID, filter repository.DownloadLogFilter) ([]models.DownloadLog, error) {
	return s.downLogRepo.GetDownloadLogs(ctx, orgID, filter)
}

func (s *LoggingService) GetDownloadStats(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*repository.DownloadStats, error) {
	return s.downLogRepo.GetDownloadStats(ctx, orgID, from, to)
}

type ReportingService struct {
	reportCacheRepo  *repository.ReportCacheRepository
	reportExportRepo *repository.ReportExportRepository
	webLogRepo       *repository.WebLogRepository
}

func NewReportingService(reportCacheRepo *repository.ReportCacheRepository, reportExportRepo *repository.ReportExportRepository, webLogRepo *repository.WebLogRepository) *ReportingService {
	return &ReportingService{
		reportCacheRepo:  reportCacheRepo,
		reportExportRepo: reportExportRepo,
		webLogRepo:       webLogRepo,
	}
}

func (s *ReportingService) GetCachedReport(ctx context.Context, orgID uuid.UUID, reportType string, periodStart, periodEnd time.Time) (*models.ReportCache, error) {
	return s.reportCacheRepo.GetCachedReport(ctx, orgID, reportType, periodStart, periodEnd)
}

func (s *ReportingService) UpsertReportCache(ctx context.Context, rc *models.ReportCache) error {
	return s.reportCacheRepo.UpsertReportCache(ctx, rc)
}

func (s *ReportingService) GetReportsByType(ctx context.Context, orgID uuid.UUID, reportType string, limit int) ([]models.ReportCache, error) {
	return s.reportCacheRepo.GetReportsByType(ctx, orgID, reportType, limit)
}

func (s *ReportingService) CreateExport(ctx context.Context, e *models.ReportExport) error {
	return s.reportExportRepo.CreateExport(ctx, e)
}

func (s *ReportingService) UpdateExportStatus(ctx context.Context, id uuid.UUID, status string, filePath *string, fileSizeBytes int) error {
	return s.reportExportRepo.UpdateExportStatus(ctx, id, status, filePath, fileSizeBytes)
}

func (s *ReportingService) GetExports(ctx context.Context, orgID uuid.UUID, filter repository.ExportFilter) ([]models.ReportExport, error) {
	return s.reportExportRepo.GetExports(ctx, orgID, filter)
}

func (s *ReportingService) GetExportByID(ctx context.Context, id uuid.UUID) (*models.ReportExport, error) {
	return s.reportExportRepo.GetExportByID(ctx, id)
}

func (s *ReportingService) DeleteOldExports(ctx context.Context, before time.Time) error {
	return s.reportExportRepo.DeleteOldExports(ctx, before)
}

func (s *ReportingService) GetTopWebsites(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopWebsite, error) {
	return s.webLogRepo.GetTopWebsites(ctx, orgID, from, to, limit)
}

func (s *ReportingService) GetTopUsers(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopUser, error) {
	return s.webLogRepo.GetTopUsers(ctx, orgID, from, to, limit)
}

func (s *ReportingService) GetDepartmentReports(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]models.DepartmentReport, error) {
	return s.webLogRepo.GetDepartmentReports(ctx, orgID, from, to)
}

type AnalyticsService struct {
	webLogRepo *repository.WebLogRepository
}

func NewAnalyticsService(webLogRepo *repository.WebLogRepository) *AnalyticsService {
	return &AnalyticsService{webLogRepo: webLogRepo}
}

func (s *AnalyticsService) GetBandwidthOverTime(ctx context.Context, orgID uuid.UUID, from, to time.Time, interval string) ([]repository.BandwidthPoint, error) {
	return s.webLogRepo.GetBandwidthOverTime(ctx, orgID, from, to, interval)
}

func (s *AnalyticsService) GetAnalyticsSummary(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*repository.WebLogStats, error) {
	return s.webLogRepo.GetWebLogStats(ctx, orgID, from, to)
}

type DashboardService struct {
	dashboardRepo *repository.DashboardWidgetRepository
}

func NewDashboardService(dashboardRepo *repository.DashboardWidgetRepository) *DashboardService {
	return &DashboardService{dashboardRepo: dashboardRepo}
}

func (s *DashboardService) CreateWidget(ctx context.Context, w *models.DashboardWidget) error {
	return s.dashboardRepo.CreateWidget(ctx, w)
}

func (s *DashboardService) UpdateWidget(ctx context.Context, w *models.DashboardWidget) error {
	return s.dashboardRepo.UpdateWidget(ctx, w)
}

func (s *DashboardService) DeleteWidget(ctx context.Context, id uuid.UUID) error {
	return s.dashboardRepo.DeleteWidget(ctx, id)
}

func (s *DashboardService) GetUserWidgets(ctx context.Context, orgID, userID uuid.UUID) ([]models.DashboardWidget, error) {
	return s.dashboardRepo.GetUserWidgets(ctx, orgID, userID)
}

func (s *DashboardService) ReorderWidgets(ctx context.Context, orgID, userID uuid.UUID, positions []repository.WidgetPosition) error {
	return s.dashboardRepo.ReorderWidgets(ctx, orgID, userID, positions)
}
