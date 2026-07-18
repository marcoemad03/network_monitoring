import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/reporting/web_log_entity.dart';
import '../entities/reporting/connection_log_entity.dart';
import '../entities/reporting/download_log_entity.dart';
import '../entities/reporting/report_entity.dart';
import '../entities/reporting/report_export_entity.dart';
import '../entities/reporting/alert_rule_entity.dart';
import '../entities/reporting/alert_notification_entity.dart';
import '../entities/reporting/dashboard_widget_entity.dart';
import '../entities/reporting/analytics_entities.dart';

abstract class ReportingRepository {
  // Web Logs
  Future<Either<Failure, List<WebLog>>> getWebLogs({
    int page = 1,
    int limit = 20,
    String? deviceId,
    String? domain,
    String? category,
    bool? isBlocked,
    DateTime? from,
    DateTime? to,
    String? search,
  });
  Future<Either<Failure, WebLogStats>> getWebLogStats({
    DateTime? from,
    DateTime? to,
  });
  Future<Either<Failure, List<TopWebsite>>> getTopWebsites({
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<Either<Failure, List<TopUser>>> getTopUsers({
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<Either<Failure, List<DepartmentReport>>> getDepartmentReports({
    DateTime? from,
    DateTime? to,
  });

  // Connection Logs
  Future<Either<Failure, List<ConnectionLog>>> getConnectionLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    String? deviceId,
  });
  Future<Either<Failure, List<ConnectionLog>>> getActiveConnections();
  Future<Either<Failure, int>> getActiveConnectionCount();

  // Download Logs
  Future<Either<Failure, List<DownloadLog>>> getDownloadLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? status,
    String? deviceId,
  });

  // Reports
  Future<Either<Failure, Report>> generateReport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  });
  Future<Either<Failure, List<Report>>> getReportsList({
    String? reportType,
    int? limit,
  });
  Future<Either<Failure, Report>> getReportDetail({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  });
  Future<Either<Failure, List<TopBandwidthConsumer>>> getTopBandwidthConsumers({
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  // Exports
  Future<Either<Failure, ReportExport>> generateExport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String format,
  });
  Future<Either<Failure, List<ReportExport>>> getExportsList();
  Future<Either<Failure, String>> downloadExport(String id);
  Future<Either<Failure, void>> deleteExport(String id);

  // Analytics
  Future<Either<Failure, List<BandwidthDataPoint>>> getBandwidthOverTime({
    DateTime? from,
    DateTime? to,
    String? interval,
  });
  Future<Either<Failure, AnalyticsSummary>> getAnalyticsSummary();
  Future<Either<Failure, Map<String, dynamic>>> getDeviceAnalytics(
    String deviceId, {
    DateTime? from,
    DateTime? to,
  });

  // Alert Rules
  Future<Either<Failure, List<AlertRule>>> getAlertRules();
  Future<Either<Failure, AlertRule>> getAlertRuleById(String id);
  Future<Either<Failure, AlertRule>> createAlertRule(AlertRule rule);
  Future<Either<Failure, AlertRule>> updateAlertRule(AlertRule rule);
  Future<Either<Failure, void>> deleteAlertRule(String id);

  // Alert Notifications
  Future<Either<Failure, List<AlertNotification>>> getNotifications({
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, void>> markAsRead(String id);
  Future<Either<Failure, void>> acknowledgeNotification(String id);
  Future<Either<Failure, List<AlertNotification>>> getRecentNotifications({
    int? limit,
  });

  // Dashboard Widgets
  Future<Either<Failure, List<DashboardWidget>>> getUserWidgets();
  Future<Either<Failure, DashboardWidget>> createWidget(
      DashboardWidget widget);
  Future<Either<Failure, DashboardWidget>> updateWidget(
      DashboardWidget widget);
  Future<Either<Failure, void>> deleteWidget(String id);
  Future<Either<Failure, void>> reorderWidgets(
      List<Map<String, dynamic>> items);
}
