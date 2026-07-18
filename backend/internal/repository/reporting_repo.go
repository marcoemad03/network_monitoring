package repository

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/hospital/nms-backend/internal/database"
	"github.com/hospital/nms-backend/internal/models"
)

type WebLogRepository struct {
	db *database.DB
}

func NewWebLogRepository(db *database.DB) *WebLogRepository {
	return &WebLogRepository{db: db}
}

type WebLogFilter struct {
	DeviceID  *uuid.UUID
	UserID    *uuid.UUID
	Domain    *string
	Category  *string
	IsBlocked *bool
	FromTime  *time.Time
	ToTime    *time.Time
	Search    *string
	Page      int
	Limit     int
}

func (r *WebLogRepository) InsertWebLog(ctx context.Context, w *models.WebLog) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO web_logs (id, org_id, device_id, user_id, url, domain, category, timestamp, duration_seconds, bytes_sent, bytes_received, is_blocked, blocked_by, is_encrypted, protocol, method, content_type, status_code, user_agent, device_name, department) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20,$21)`,
		w.ID, w.OrganizationID, w.DeviceID, w.UserID, w.URL, w.Domain, w.Category, w.Timestamp, w.DurationSeconds, w.BytesSent, w.BytesReceived, w.IsBlocked, w.BlockedBy, w.IsEncrypted, w.Protocol, w.Method, w.ContentType, w.StatusCode, w.UserAgent, w.DeviceName, w.Department)
	return err
}

func (r *WebLogRepository) GetWebLogs(ctx context.Context, orgID uuid.UUID, filter WebLogFilter) ([]models.WebLog, error) {
	query := `SELECT id, org_id, device_id, user_id, url, domain, category, timestamp, duration_seconds, bytes_sent, bytes_received, is_blocked, blocked_by, is_encrypted, protocol, method, content_type, status_code, user_agent, device_name, department FROM web_logs WHERE org_id = $1`
	countQuery := `SELECT COUNT(*) FROM web_logs WHERE org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if filter.DeviceID != nil {
		query += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		args = append(args, *filter.DeviceID)
		argIdx++
	}
	if filter.UserID != nil {
		query += fmt.Sprintf(` AND user_id = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND user_id = $%d`, argIdx)
		args = append(args, *filter.UserID)
		argIdx++
	}
	if filter.Domain != nil {
		query += fmt.Sprintf(` AND domain = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND domain = $%d`, argIdx)
		args = append(args, *filter.Domain)
		argIdx++
	}
	if filter.Category != nil {
		query += fmt.Sprintf(` AND category = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND category = $%d`, argIdx)
		args = append(args, *filter.Category)
		argIdx++
	}
	if filter.IsBlocked != nil {
		query += fmt.Sprintf(` AND is_blocked = $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND is_blocked = $%d`, argIdx)
		args = append(args, *filter.IsBlocked)
		argIdx++
	}
	if filter.FromTime != nil {
		query += fmt.Sprintf(` AND timestamp >= $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND timestamp >= $%d`, argIdx)
		args = append(args, *filter.FromTime)
		argIdx++
	}
	if filter.ToTime != nil {
		query += fmt.Sprintf(` AND timestamp <= $%d`, argIdx)
		countQuery += fmt.Sprintf(` AND timestamp <= $%d`, argIdx)
		args = append(args, *filter.ToTime)
		argIdx++
	}
	if filter.Search != nil {
		query += fmt.Sprintf(` AND (url ILIKE $%d OR domain ILIKE $%d)`, argIdx, argIdx)
		countQuery += fmt.Sprintf(` AND (url ILIKE $%d OR domain ILIKE $%d)`, argIdx, argIdx)
		args = append(args, "%"+*filter.Search+"%")
		argIdx++
	}

	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	query += ` ORDER BY timestamp DESC`
	query += fmt.Sprintf(` LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []models.WebLog
	for rows.Next() {
		var w models.WebLog
		if err := rows.Scan(&w.ID, &w.OrganizationID, &w.DeviceID, &w.UserID, &w.URL, &w.Domain, &w.Category, &w.Timestamp, &w.DurationSeconds, &w.BytesSent, &w.BytesReceived, &w.IsBlocked, &w.BlockedBy, &w.IsEncrypted, &w.Protocol, &w.Method, &w.ContentType, &w.StatusCode, &w.UserAgent, &w.DeviceName, &w.Department); err != nil {
			return nil, err
		}
		logs = append(logs, w)
	}
	return logs, nil
}

type WebLogStats struct {
	TotalCount    int   `json:"total_count"`
	TotalBytes    int64 `json:"total_bytes"`
	BlockedCount  int   `json:"blocked_count"`
	UniqueDomains int   `json:"unique_domains"`
}

func (r *WebLogRepository) GetWebLogStats(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*WebLogStats, error) {
	stats := &WebLogStats{}
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*), COALESCE(SUM(bytes_sent + bytes_received), 0), COALESCE(SUM(CASE WHEN is_blocked THEN 1 ELSE 0 END), 0), COUNT(DISTINCT domain) FROM web_logs WHERE org_id = $1 AND timestamp >= $2 AND timestamp <= $3`,
		orgID, from, to).Scan(&stats.TotalCount, &stats.TotalBytes, &stats.BlockedCount, &stats.UniqueDomains)
	if err != nil {
		return nil, err
	}
	return stats, nil
}

func (r *WebLogRepository) GetTopWebsites(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopWebsite, error) {
	if limit < 1 {
		limit = 10
	}
	rows, err := r.db.Query(ctx,
		`SELECT domain, COUNT(*) as visit_count, COALESCE(SUM(bytes_sent + bytes_received), 0) as total_bytes, COALESCE(SUM(duration_seconds), 0) as total_seconds FROM web_logs WHERE org_id = $1 AND timestamp >= $2 AND timestamp <= $3 AND domain IS NOT NULL GROUP BY domain ORDER BY visit_count DESC LIMIT $4`,
		orgID, from, to, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sites []models.TopWebsite
	for rows.Next() {
		var s models.TopWebsite
		if err := rows.Scan(&s.Domain, &s.VisitCount, &s.TotalBytes, &s.TotalSeconds); err != nil {
			return nil, err
		}
		sites = append(sites, s)
	}
	return sites, nil
}

func (r *WebLogRepository) GetTopUsers(ctx context.Context, orgID uuid.UUID, from, to time.Time, limit int) ([]models.TopUser, error) {
	if limit < 1 {
		limit = 10
	}
	rows, err := r.db.Query(ctx,
		`SELECT w.user_id, COALESCE(u.display_name, 'Unknown') as display_name, COUNT(*) as visit_count, COALESCE(SUM(w.bytes_sent + w.bytes_received), 0) as total_bytes, COALESCE(SUM(w.duration_seconds), 0) as total_seconds FROM web_logs w LEFT JOIN users u ON u.id = w.user_id WHERE w.org_id = $1 AND w.timestamp >= $2 AND w.timestamp <= $3 AND w.user_id IS NOT NULL GROUP BY w.user_id, u.display_name ORDER BY visit_count DESC LIMIT $4`,
		orgID, from, to, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var users []models.TopUser
	for rows.Next() {
		var u models.TopUser
		if err := rows.Scan(&u.UserID, &u.DisplayName, &u.VisitCount, &u.TotalBytes, &u.TotalSeconds); err != nil {
			return nil, err
		}
		users = append(users, u)
	}
	return users, nil
}

func (r *WebLogRepository) GetDepartmentReports(ctx context.Context, orgID uuid.UUID, from, to time.Time) ([]models.DepartmentReport, error) {
	rows, err := r.db.Query(ctx,
		`SELECT COALESCE(department, 'Unassigned') as department, COALESCE(SUM(bytes_sent + bytes_received), 0) as total_bytes, COUNT(*) as visit_count, COUNT(DISTINCT device_id) as unique_devices, COALESCE(SUM(CASE WHEN is_blocked THEN 1 ELSE 0 END), 0) as blocked_attempts FROM web_logs WHERE org_id = $1 AND timestamp >= $2 AND timestamp <= $3 GROUP BY department ORDER BY total_bytes DESC`,
		orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var depts []models.DepartmentReport
	for rows.Next() {
		var d models.DepartmentReport
		if err := rows.Scan(&d.Department, &d.TotalBytes, &d.VisitCount, &d.UniqueDevices, &d.BlockedAttempts); err != nil {
			return nil, err
		}
		depts = append(depts, d)
	}
	return depts, nil
}

type BandwidthPoint struct {
	Timestamp    time.Time `json:"timestamp"`
	BytesSent    int64     `json:"bytes_sent"`
	BytesRecv    int64     `json:"bytes_received"`
	TotalBytes   int64     `json:"total_bytes"`
}

func (r *WebLogRepository) GetBandwidthOverTime(ctx context.Context, orgID uuid.UUID, from, to time.Time, interval string) ([]BandwidthPoint, error) {
	var trunc string
	switch interval {
	case "hourly":
		trunc = "date_trunc('hour', timestamp)"
	case "daily":
		trunc = "date_trunc('day', timestamp)"
	default:
		trunc = "date_trunc('hour', timestamp)"
	}

	rows, err := r.db.Query(ctx,
		fmt.Sprintf(`SELECT %s as bucket, COALESCE(SUM(bytes_sent), 0) as bytes_sent, COALESCE(SUM(bytes_received), 0) as bytes_recv, COALESCE(SUM(bytes_sent + bytes_received), 0) as total_bytes FROM web_logs WHERE org_id = $1 AND timestamp >= $2 AND timestamp <= $3 GROUP BY bucket ORDER BY bucket ASC`, trunc),
		orgID, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var points []BandwidthPoint
	for rows.Next() {
		var p BandwidthPoint
		if err := rows.Scan(&p.Timestamp, &p.BytesSent, &p.BytesRecv, &p.TotalBytes); err != nil {
			return nil, err
		}
		points = append(points, p)
	}
	return points, nil
}

type ConnectionLogRepository struct {
	db *database.DB
}

func NewConnectionLogRepository(db *database.DB) *ConnectionLogRepository {
	return &ConnectionLogRepository{db: db}
}

func (r *ConnectionLogRepository) InsertConnectionLog(ctx context.Context, c *models.ConnectionLog) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO connection_logs (id, org_id, device_id, user_id, protocol, source_ip, dest_ip, source_port, dest_port, bytes_sent, bytes_received, packets_sent, packets_received, start_time, end_time, duration_seconds, is_active, application, department, device_name) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)`,
		c.ID, c.OrganizationID, c.DeviceID, c.UserID, c.Protocol, c.SourceIP, c.DestIP, c.SourcePort, c.DestPort, c.BytesSent, c.BytesReceived, c.PacketsSent, c.PacketsReceived, c.StartTime, c.EndTime, c.DurationSeconds, c.IsActive, c.Application, c.Department, c.DeviceName)
	return err
}

func (r *ConnectionLogRepository) UpdateConnectionEnd(ctx context.Context, id uuid.UUID, endTime time.Time, bytesSent, bytesReceived int64, packetsSent, packetsReceived, durationSeconds int) error {
	_, err := r.db.Exec(ctx,
		`UPDATE connection_logs SET end_time=$1, bytes_sent=$2, bytes_received=$3, packets_sent=$4, packets_received=$5, duration_seconds=$6, is_active=false WHERE id=$7`,
		endTime, bytesSent, bytesReceived, packetsSent, packetsReceived, durationSeconds, id)
	return err
}

func (r *ConnectionLogRepository) GetActiveConnections(ctx context.Context, orgID uuid.UUID) ([]models.ConnectionLog, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, device_id, user_id, protocol, source_ip, dest_ip, source_port, dest_port, bytes_sent, bytes_received, packets_sent, packets_received, start_time, end_time, duration_seconds, is_active, application, department, device_name FROM connection_logs WHERE org_id = $1 AND is_active = true ORDER BY start_time DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conns []models.ConnectionLog
	for rows.Next() {
		var c models.ConnectionLog
		if err := rows.Scan(&c.ID, &c.OrganizationID, &c.DeviceID, &c.UserID, &c.Protocol, &c.SourceIP, &c.DestIP, &c.SourcePort, &c.DestPort, &c.BytesSent, &c.BytesReceived, &c.PacketsSent, &c.PacketsReceived, &c.StartTime, &c.EndTime, &c.DurationSeconds, &c.IsActive, &c.Application, &c.Department, &c.DeviceName); err != nil {
			return nil, err
		}
		conns = append(conns, c)
	}
	return conns, nil
}

type ConnectionLogFilter struct {
	DeviceID  *uuid.UUID
	Protocol  *string
	IsActive  *bool
	FromTime  *time.Time
	ToTime    *time.Time
	Page      int
	Limit     int
}

func (r *ConnectionLogRepository) GetConnectionLogs(ctx context.Context, orgID uuid.UUID, filter ConnectionLogFilter) ([]models.ConnectionLog, error) {
	query := `SELECT id, org_id, device_id, user_id, protocol, source_ip, dest_ip, source_port, dest_port, bytes_sent, bytes_received, packets_sent, packets_received, start_time, end_time, duration_seconds, is_active, application, department, device_name FROM connection_logs WHERE org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if filter.DeviceID != nil {
		query += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		args = append(args, *filter.DeviceID)
		argIdx++
	}
	if filter.Protocol != nil {
		query += fmt.Sprintf(` AND protocol = $%d`, argIdx)
		args = append(args, *filter.Protocol)
		argIdx++
	}
	if filter.IsActive != nil {
		query += fmt.Sprintf(` AND is_active = $%d`, argIdx)
		args = append(args, *filter.IsActive)
		argIdx++
	}
	if filter.FromTime != nil {
		query += fmt.Sprintf(` AND start_time >= $%d`, argIdx)
		args = append(args, *filter.FromTime)
		argIdx++
	}
	if filter.ToTime != nil {
		query += fmt.Sprintf(` AND start_time <= $%d`, argIdx)
		args = append(args, *filter.ToTime)
		argIdx++
	}

	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	query += ` ORDER BY start_time DESC`
	query += fmt.Sprintf(` LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conns []models.ConnectionLog
	for rows.Next() {
		var c models.ConnectionLog
		if err := rows.Scan(&c.ID, &c.OrganizationID, &c.DeviceID, &c.UserID, &c.Protocol, &c.SourceIP, &c.DestIP, &c.SourcePort, &c.DestPort, &c.BytesSent, &c.BytesReceived, &c.PacketsSent, &c.PacketsReceived, &c.StartTime, &c.EndTime, &c.DurationSeconds, &c.IsActive, &c.Application, &c.Department, &c.DeviceName); err != nil {
			return nil, err
		}
		conns = append(conns, c)
	}
	return conns, nil
}

func (r *ConnectionLogRepository) GetActiveConnectionCount(ctx context.Context, orgID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM connection_logs WHERE org_id = $1 AND is_active = true`, orgID).Scan(&count)
	return count, err
}

type DownloadLogRepository struct {
	db *database.DB
}

func NewDownloadLogRepository(db *database.DB) *DownloadLogRepository {
	return &DownloadLogRepository{db: db}
}

func (r *DownloadLogRepository) InsertDownloadLog(ctx context.Context, d *models.DownloadLog) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO download_logs (id, org_id, device_id, user_id, filename, url, size_bytes, protocol, mime_type, start_time, end_time, duration_seconds, status, is_allowed, blocked_by, device_name, department) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
		d.ID, d.OrganizationID, d.DeviceID, d.UserID, d.Filename, d.URL, d.SizeBytes, d.Protocol, d.MimeType, d.StartTime, d.EndTime, d.DurationSeconds, d.Status, d.IsAllowed, d.BlockedBy, d.DeviceName, d.Department)
	return err
}

func (r *DownloadLogRepository) UpdateDownloadStatus(ctx context.Context, id uuid.UUID, status string, endTime time.Time, durationSeconds int) error {
	_, err := r.db.Exec(ctx,
		`UPDATE download_logs SET status=$1, end_time=$2, duration_seconds=$3 WHERE id=$4`,
		status, endTime, durationSeconds, id)
	return err
}

type DownloadLogFilter struct {
	DeviceID  *uuid.UUID
	UserID    *uuid.UUID
	Status    *string
	FromTime  *time.Time
	ToTime    *time.Time
	Page      int
	Limit     int
}

func (r *DownloadLogRepository) GetDownloadLogs(ctx context.Context, orgID uuid.UUID, filter DownloadLogFilter) ([]models.DownloadLog, error) {
	query := `SELECT id, org_id, device_id, user_id, filename, url, size_bytes, protocol, mime_type, start_time, end_time, duration_seconds, status, is_allowed, blocked_by, device_name, department FROM download_logs WHERE org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if filter.DeviceID != nil {
		query += fmt.Sprintf(` AND device_id = $%d`, argIdx)
		args = append(args, *filter.DeviceID)
		argIdx++
	}
	if filter.UserID != nil {
		query += fmt.Sprintf(` AND user_id = $%d`, argIdx)
		args = append(args, *filter.UserID)
		argIdx++
	}
	if filter.Status != nil {
		query += fmt.Sprintf(` AND status = $%d`, argIdx)
		args = append(args, *filter.Status)
		argIdx++
	}
	if filter.FromTime != nil {
		query += fmt.Sprintf(` AND start_time >= $%d`, argIdx)
		args = append(args, *filter.FromTime)
		argIdx++
	}
	if filter.ToTime != nil {
		query += fmt.Sprintf(` AND start_time <= $%d`, argIdx)
		args = append(args, *filter.ToTime)
		argIdx++
	}

	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	query += ` ORDER BY start_time DESC`
	query += fmt.Sprintf(` LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var logs []models.DownloadLog
	for rows.Next() {
		var d models.DownloadLog
		if err := rows.Scan(&d.ID, &d.OrganizationID, &d.DeviceID, &d.UserID, &d.Filename, &d.URL, &d.SizeBytes, &d.Protocol, &d.MimeType, &d.StartTime, &d.EndTime, &d.DurationSeconds, &d.Status, &d.IsAllowed, &d.BlockedBy, &d.DeviceName, &d.Department); err != nil {
			return nil, err
		}
		logs = append(logs, d)
	}
	return logs, nil
}

type DownloadStats struct {
	TotalDownloads int   `json:"total_downloads"`
	TotalSizeBytes int64 `json:"total_size_bytes"`
	HTTPSDownloads int   `json:"https_downloads"`
	FTPDownloads   int   `json:"ftp_downloads"`
	BlockedCount   int   `json:"blocked_count"`
}

func (r *DownloadLogRepository) GetDownloadStats(ctx context.Context, orgID uuid.UUID, from, to time.Time) (*DownloadStats, error) {
	stats := &DownloadStats{}
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*), COALESCE(SUM(size_bytes), 0), COALESCE(SUM(CASE WHEN protocol='HTTPS' THEN 1 ELSE 0 END), 0), COALESCE(SUM(CASE WHEN protocol='FTP' THEN 1 ELSE 0 END), 0), COALESCE(SUM(CASE WHEN is_allowed=false THEN 1 ELSE 0 END), 0) FROM download_logs WHERE org_id = $1 AND start_time >= $2 AND start_time <= $3`,
		orgID, from, to).Scan(&stats.TotalDownloads, &stats.TotalSizeBytes, &stats.HTTPSDownloads, &stats.FTPDownloads, &stats.BlockedCount)
	if err != nil {
		return nil, err
	}
	return stats, nil
}

type ReportCacheRepository struct {
	db *database.DB
}

func NewReportCacheRepository(db *database.DB) *ReportCacheRepository {
	return &ReportCacheRepository{db: db}
}

func (r *ReportCacheRepository) GetCachedReport(ctx context.Context, orgID uuid.UUID, reportType string, periodStart, periodEnd time.Time) (*models.ReportCache, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, report_type, period_start, period_end, data::text, total_websites, total_bandwidth_mb, total_duration_minutes, unique_devices, unique_users, blocked_attempts, generated_at FROM report_cache WHERE org_id = $1 AND report_type = $2 AND period_start = $3 AND period_end = $4`,
		orgID, reportType, periodStart, periodEnd)
	var rc models.ReportCache
	err := row.Scan(&rc.ID, &rc.OrganizationID, &rc.ReportType, &rc.PeriodStart, &rc.PeriodEnd, &rc.Data, &rc.TotalWebsites, &rc.TotalBandwidthMB, &rc.TotalDurationMinutes, &rc.UniqueDevices, &rc.UniqueUsers, &rc.BlockedAttempts, &rc.GeneratedAt)
	if err != nil {
		return nil, err
	}
	return &rc, nil
}

func (r *ReportCacheRepository) UpsertReportCache(ctx context.Context, rc *models.ReportCache) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO report_cache (id, org_id, report_type, period_start, period_end, data, total_websites, total_bandwidth_mb, total_duration_minutes, unique_devices, unique_users, blocked_attempts, generated_at) VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12,NOW()) ON CONFLICT (org_id, report_type, period_start, period_end) DO UPDATE SET data=$6::jsonb, total_websites=$7, total_bandwidth_mb=$8, total_duration_minutes=$9, unique_devices=$10, unique_users=$11, blocked_attempts=$12, generated_at=NOW()`,
		rc.ID, rc.OrganizationID, rc.ReportType, rc.PeriodStart, rc.PeriodEnd, rc.Data, rc.TotalWebsites, rc.TotalBandwidthMB, rc.TotalDurationMinutes, rc.UniqueDevices, rc.UniqueUsers, rc.BlockedAttempts)
	return err
}

func (r *ReportCacheRepository) GetReportsByType(ctx context.Context, orgID uuid.UUID, reportType string, limit int) ([]models.ReportCache, error) {
	if limit < 1 {
		limit = 10
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, report_type, period_start, period_end, data::text, total_websites, total_bandwidth_mb, total_duration_minutes, unique_devices, unique_users, blocked_attempts, generated_at FROM report_cache WHERE org_id = $1 AND report_type = $2 ORDER BY generated_at DESC LIMIT $3`,
		orgID, reportType, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []models.ReportCache
	for rows.Next() {
		var rc models.ReportCache
		if err := rows.Scan(&rc.ID, &rc.OrganizationID, &rc.ReportType, &rc.PeriodStart, &rc.PeriodEnd, &rc.Data, &rc.TotalWebsites, &rc.TotalBandwidthMB, &rc.TotalDurationMinutes, &rc.UniqueDevices, &rc.UniqueUsers, &rc.BlockedAttempts, &rc.GeneratedAt); err != nil {
			return nil, err
		}
		reports = append(reports, rc)
	}
	return reports, nil
}

type ReportExportRepository struct {
	db *database.DB
}

func NewReportExportRepository(db *database.DB) *ReportExportRepository {
	return &ReportExportRepository{db: db}
}

func (r *ReportExportRepository) CreateExport(ctx context.Context, e *models.ReportExport) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO report_exports (id, org_id, report_type, period_start, period_end, format, file_path, file_size_bytes, status, generated_by, generated_at, expires_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12)`,
		e.ID, e.OrganizationID, e.ReportType, e.PeriodStart, e.PeriodEnd, e.Format, e.FilePath, e.FileSizeBytes, e.Status, e.GeneratedBy, e.GeneratedAt, e.ExpiresAt)
	return err
}

func (r *ReportExportRepository) UpdateExportStatus(ctx context.Context, id uuid.UUID, status string, filePath *string, fileSizeBytes int) error {
	_, err := r.db.Exec(ctx,
		`UPDATE report_exports SET status=$1, file_path=$2, file_size_bytes=$3 WHERE id=$4`,
		status, filePath, fileSizeBytes, id)
	return err
}

type ExportFilter struct {
	ReportType *string
	Format     *string
	Status     *string
	Page       int
	Limit      int
}

func (r *ReportExportRepository) GetExports(ctx context.Context, orgID uuid.UUID, filter ExportFilter) ([]models.ReportExport, error) {
	query := `SELECT id, org_id, report_type, period_start, period_end, format, file_path, file_size_bytes, status, generated_by, generated_at, expires_at FROM report_exports WHERE org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if filter.ReportType != nil {
		query += fmt.Sprintf(` AND report_type = $%d`, argIdx)
		args = append(args, *filter.ReportType)
		argIdx++
	}
	if filter.Format != nil {
		query += fmt.Sprintf(` AND format = $%d`, argIdx)
		args = append(args, *filter.Format)
		argIdx++
	}
	if filter.Status != nil {
		query += fmt.Sprintf(` AND status = $%d`, argIdx)
		args = append(args, *filter.Status)
		argIdx++
	}

	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	query += ` ORDER BY generated_at DESC`
	query += fmt.Sprintf(` LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var exports []models.ReportExport
	for rows.Next() {
		var e models.ReportExport
		if err := rows.Scan(&e.ID, &e.OrganizationID, &e.ReportType, &e.PeriodStart, &e.PeriodEnd, &e.Format, &e.FilePath, &e.FileSizeBytes, &e.Status, &e.GeneratedBy, &e.GeneratedAt, &e.ExpiresAt); err != nil {
			return nil, err
		}
		exports = append(exports, e)
	}
	return exports, nil
}

func (r *ReportExportRepository) GetExportByID(ctx context.Context, id uuid.UUID) (*models.ReportExport, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, report_type, period_start, period_end, format, file_path, file_size_bytes, status, generated_by, generated_at, expires_at FROM report_exports WHERE id = $1`, id)
	var e models.ReportExport
	err := row.Scan(&e.ID, &e.OrganizationID, &e.ReportType, &e.PeriodStart, &e.PeriodEnd, &e.Format, &e.FilePath, &e.FileSizeBytes, &e.Status, &e.GeneratedBy, &e.GeneratedAt, &e.ExpiresAt)
	if err != nil {
		return nil, err
	}
	return &e, nil
}

func (r *ReportExportRepository) DeleteOldExports(ctx context.Context, before time.Time) error {
	return r.db.Exec(ctx, `DELETE FROM report_exports WHERE generated_at < $1`, before)
}

type AlertRuleRepository struct {
	db *database.DB
}

func NewAlertRuleRepository(db *database.DB) *AlertRuleRepository {
	return &AlertRuleRepository{db: db}
}

func (r *AlertRuleRepository) CreateAlertRule(ctx context.Context, a *models.AlertRule) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO alert_rules (id, org_id, name, description, metric, condition, threshold, duration_minutes, severity, channels, is_active, notify_roles, cooldown_minutes, last_triggered_at, created_by, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17)`,
		a.ID, a.OrganizationID, a.Name, a.Description, a.Metric, a.Condition, a.Threshold, a.DurationMinutes, a.Severity, a.Channels, a.IsActive, a.NotifyRoles, a.CooldownMinutes, a.LastTriggeredAt, a.CreatedBy, a.CreatedAt, a.UpdatedAt)
	return err
}

func (r *AlertRuleRepository) UpdateAlertRule(ctx context.Context, a *models.AlertRule) error {
	_, err := r.db.Exec(ctx,
		`UPDATE alert_rules SET name=$1, description=$2, metric=$3, condition=$4, threshold=$5, duration_minutes=$6, severity=$7, channels=$8, is_active=$9, notify_roles=$10, cooldown_minutes=$11, updated_at=NOW() WHERE id=$12 AND org_id=$13`,
		a.Name, a.Description, a.Metric, a.Condition, a.Threshold, a.DurationMinutes, a.Severity, a.Channels, a.IsActive, a.NotifyRoles, a.CooldownMinutes, a.ID, a.OrganizationID)
	return err
}

func (r *AlertRuleRepository) DeleteAlertRule(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `DELETE FROM alert_rules WHERE id = $1`, id)
}

func (r *AlertRuleRepository) GetAlertRules(ctx context.Context, orgID uuid.UUID) ([]models.AlertRule, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, name, description, metric, condition, threshold, duration_minutes, severity, channels, is_active, notify_roles, cooldown_minutes, last_triggered_at, created_by, created_at, updated_at FROM alert_rules WHERE org_id = $1 ORDER BY created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []models.AlertRule
	for rows.Next() {
		var a models.AlertRule
		if err := rows.Scan(&a.ID, &a.OrganizationID, &a.Name, &a.Description, &a.Metric, &a.Condition, &a.Threshold, &a.DurationMinutes, &a.Severity, &a.Channels, &a.IsActive, &a.NotifyRoles, &a.CooldownMinutes, &a.LastTriggeredAt, &a.CreatedBy, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, a)
	}
	return rules, nil
}

func (r *AlertRuleRepository) GetAlertRuleByID(ctx context.Context, id uuid.UUID) (*models.AlertRule, error) {
	row := r.db.QueryRow(ctx,
		`SELECT id, org_id, name, description, metric, condition, threshold, duration_minutes, severity, channels, is_active, notify_roles, cooldown_minutes, last_triggered_at, created_by, created_at, updated_at FROM alert_rules WHERE id = $1`, id)
	var a models.AlertRule
	err := row.Scan(&a.ID, &a.OrganizationID, &a.Name, &a.Description, &a.Metric, &a.Condition, &a.Threshold, &a.DurationMinutes, &a.Severity, &a.Channels, &a.IsActive, &a.NotifyRoles, &a.CooldownMinutes, &a.LastTriggeredAt, &a.CreatedBy, &a.CreatedAt, &a.UpdatedAt)
	if err != nil {
		return nil, err
	}
	return &a, nil
}

func (r *AlertRuleRepository) GetActiveAlertRules(ctx context.Context, orgID uuid.UUID) ([]models.AlertRule, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, name, description, metric, condition, threshold, duration_minutes, severity, channels, is_active, notify_roles, cooldown_minutes, last_triggered_at, created_by, created_at, updated_at FROM alert_rules WHERE org_id = $1 AND is_active = true ORDER BY created_at DESC`, orgID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var rules []models.AlertRule
	for rows.Next() {
		var a models.AlertRule
		if err := rows.Scan(&a.ID, &a.OrganizationID, &a.Name, &a.Description, &a.Metric, &a.Condition, &a.Threshold, &a.DurationMinutes, &a.Severity, &a.Channels, &a.IsActive, &a.NotifyRoles, &a.CooldownMinutes, &a.LastTriggeredAt, &a.CreatedBy, &a.CreatedAt, &a.UpdatedAt); err != nil {
			return nil, err
		}
		rules = append(rules, a)
	}
	return rules, nil
}

func (r *AlertRuleRepository) UpdateLastTriggered(ctx context.Context, id uuid.UUID, t time.Time) error {
	_, err := r.db.Exec(ctx, `UPDATE alert_rules SET last_triggered_at = $1 WHERE id = $2`, t, id)
	return err
}

type AlertNotificationRepository struct {
	db *database.DB
}

func NewAlertNotificationRepository(db *database.DB) *AlertNotificationRepository {
	return &AlertNotificationRepository{db: db}
}

func (r *AlertNotificationRepository) CreateNotification(ctx context.Context, n *models.AlertNotification) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO alert_notifications (id, org_id, rule_id, title, message, severity, metric_name, metric_value, threshold, triggered_at, acknowledged_at, acknowledged_by, is_read, channel) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14)`,
		n.ID, n.OrganizationID, n.RuleID, n.Title, n.Message, n.Severity, n.MetricName, n.MetricValue, n.Threshold, n.TriggeredAt, n.AcknowledgedAt, n.AcknowledgedBy, n.IsRead, n.Channel)
	return err
}

type NotificationFilter struct {
	Severity  *string
	IsRead    *bool
	Channel   *string
	FromTime  *time.Time
	ToTime    *time.Time
	Page      int
	Limit     int
}

func (r *AlertNotificationRepository) GetNotifications(ctx context.Context, orgID uuid.UUID, filter NotificationFilter) ([]models.AlertNotification, error) {
	query := `SELECT id, org_id, rule_id, title, message, severity, metric_name, metric_value, threshold, triggered_at, acknowledged_at, acknowledged_by, is_read, channel FROM alert_notifications WHERE org_id = $1`
	args := []interface{}{orgID}
	argIdx := 2

	if filter.Severity != nil {
		query += fmt.Sprintf(` AND severity = $%d`, argIdx)
		args = append(args, *filter.Severity)
		argIdx++
	}
	if filter.IsRead != nil {
		query += fmt.Sprintf(` AND is_read = $%d`, argIdx)
		args = append(args, *filter.IsRead)
		argIdx++
	}
	if filter.Channel != nil {
		query += fmt.Sprintf(` AND channel = $%d`, argIdx)
		args = append(args, *filter.Channel)
		argIdx++
	}
	if filter.FromTime != nil {
		query += fmt.Sprintf(` AND triggered_at >= $%d`, argIdx)
		args = append(args, *filter.FromTime)
		argIdx++
	}
	if filter.ToTime != nil {
		query += fmt.Sprintf(` AND triggered_at <= $%d`, argIdx)
		args = append(args, *filter.ToTime)
		argIdx++
	}

	page := filter.Page
	if page < 1 {
		page = 1
	}
	limit := filter.Limit
	if limit < 1 {
		limit = 20
	}
	offset := (page - 1) * limit

	query += ` ORDER BY triggered_at DESC`
	query += fmt.Sprintf(` LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	args = append(args, limit, offset)

	rows, err := r.db.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.AlertNotification
	for rows.Next() {
		var n models.AlertNotification
		if err := rows.Scan(&n.ID, &n.OrganizationID, &n.RuleID, &n.Title, &n.Message, &n.Severity, &n.MetricName, &n.MetricValue, &n.Threshold, &n.TriggeredAt, &n.AcknowledgedAt, &n.AcknowledgedBy, &n.IsRead, &n.Channel); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, nil
}

func (r *AlertNotificationRepository) GetUnreadCount(ctx context.Context, orgID uuid.UUID) (int, error) {
	var count int
	err := r.db.QueryRow(ctx, `SELECT COUNT(*) FROM alert_notifications WHERE org_id = $1 AND is_read = false`, orgID).Scan(&count)
	return count, err
}

func (r *AlertNotificationRepository) MarkAsRead(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `UPDATE alert_notifications SET is_read = true WHERE id = $1`, id)
}

func (r *AlertNotificationRepository) AcknowledgeNotification(ctx context.Context, id, userID uuid.UUID) error {
	return r.db.Exec(ctx, `UPDATE alert_notifications SET acknowledged_at = NOW(), acknowledged_by = $1, is_read = true WHERE id = $2`, userID, id)
}

func (r *AlertNotificationRepository) DeleteNotification(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `DELETE FROM alert_notifications WHERE id = $1`, id)
}

func (r *AlertNotificationRepository) GetRecentNotifications(ctx context.Context, orgID uuid.UUID, limit int) ([]models.AlertNotification, error) {
	if limit < 1 {
		limit = 10
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, rule_id, title, message, severity, metric_name, metric_value, threshold, triggered_at, acknowledged_at, acknowledged_by, is_read, channel FROM alert_notifications WHERE org_id = $1 ORDER BY triggered_at DESC LIMIT $2`,
		orgID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var notifications []models.AlertNotification
	for rows.Next() {
		var n models.AlertNotification
		if err := rows.Scan(&n.ID, &n.OrganizationID, &n.RuleID, &n.Title, &n.Message, &n.Severity, &n.MetricName, &n.MetricValue, &n.Threshold, &n.TriggeredAt, &n.AcknowledgedAt, &n.AcknowledgedBy, &n.IsRead, &n.Channel); err != nil {
			return nil, err
		}
		notifications = append(notifications, n)
	}
	return notifications, nil
}

type DashboardWidgetRepository struct {
	db *database.DB
}

func NewDashboardWidgetRepository(db *database.DB) *DashboardWidgetRepository {
	return &DashboardWidgetRepository{db: db}
}

func (r *DashboardWidgetRepository) CreateWidget(ctx context.Context, w *models.DashboardWidget) error {
	_, err := r.db.Exec(ctx,
		`INSERT INTO dashboard_widgets (id, org_id, user_id, widget_type, title, config, position, width, height, is_visible, created_at, updated_at) VALUES ($1,$2,$3,$4,$5,$6::jsonb,$7,$8,$9,$10,$11,$12)`,
		w.ID, w.OrganizationID, w.UserID, w.WidgetType, w.Title, w.Config, w.Position, w.Width, w.Height, w.IsVisible, w.CreatedAt, w.UpdatedAt)
	return err
}

func (r *DashboardWidgetRepository) UpdateWidget(ctx context.Context, w *models.DashboardWidget) error {
	_, err := r.db.Exec(ctx,
		`UPDATE dashboard_widgets SET widget_type=$1, title=$2, config=$3::jsonb, position=$4, width=$5, height=$6, is_visible=$7, updated_at=NOW() WHERE id=$8 AND org_id=$9`,
		w.WidgetType, w.Title, w.Config, w.Position, w.Width, w.Height, w.IsVisible, w.ID, w.OrganizationID)
	return err
}

func (r *DashboardWidgetRepository) DeleteWidget(ctx context.Context, id uuid.UUID) error {
	return r.db.Exec(ctx, `DELETE FROM dashboard_widgets WHERE id = $1`, id)
}

func (r *DashboardWidgetRepository) GetUserWidgets(ctx context.Context, orgID, userID uuid.UUID) ([]models.DashboardWidget, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, org_id, user_id, widget_type, title, config::text, position, width, height, is_visible, created_at, updated_at FROM dashboard_widgets WHERE org_id = $1 AND (user_id = $2 OR user_id IS NULL) ORDER BY position ASC`,
		orgID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var widgets []models.DashboardWidget
	for rows.Next() {
		var w models.DashboardWidget
		if err := rows.Scan(&w.ID, &w.OrganizationID, &w.UserID, &w.WidgetType, &w.Title, &w.Config, &w.Position, &w.Width, &w.Height, &w.IsVisible, &w.CreatedAt, &w.UpdatedAt); err != nil {
			return nil, err
		}
		widgets = append(widgets, w)
	}
	return widgets, nil
}

type WidgetPosition struct {
	ID       uuid.UUID `json:"id"`
	Position int       `json:"position"`
}

func (r *DashboardWidgetRepository) ReorderWidgets(ctx context.Context, orgID, userID uuid.UUID, positions []WidgetPosition) error {
	for _, p := range positions {
		if err := r.db.Exec(ctx,
			`UPDATE dashboard_widgets SET position = $1, updated_at = NOW() WHERE id = $2 AND org_id = $3 AND (user_id = $4 OR user_id IS NULL)`,
			p.Position, p.ID, orgID, userID); err != nil {
			return err
		}
	}
	return nil
}
