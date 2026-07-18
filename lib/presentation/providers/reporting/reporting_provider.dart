import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/reporting/web_log_entity.dart';
import '../../../domain/entities/reporting/connection_log_entity.dart';
import '../../../domain/entities/reporting/download_log_entity.dart';
import '../../../domain/entities/reporting/report_entity.dart';
import '../../../domain/entities/reporting/report_export_entity.dart';
import '../../../domain/entities/reporting/alert_rule_entity.dart';
import '../../../domain/entities/reporting/alert_notification_entity.dart';
import '../../../domain/entities/reporting/dashboard_widget_entity.dart';
import '../../../domain/entities/reporting/analytics_entities.dart';
import '../../../data/repositories/reporting_repository_impl.dart';
import '../../../data/datasources/remote/reporting_remote_datasource.dart';
import '../../../core/di/injection_container.dart';

final reportingRemoteDataSourceProvider =
    Provider<ReportingRemoteDataSource>((ref) {
  return ReportingRemoteDataSourceImpl(ref.watch(dioProvider));
});

final reportingRepositoryProvider = Provider<ReportingRepositoryImpl>((ref) {
  return ReportingRepositoryImpl(
    remoteDataSource: ref.watch(reportingRemoteDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

// Web Logs
final webLogsProvider = FutureProvider<List<WebLog>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getWebLogs();
  return result.fold((_) => <WebLog>[], (list) => list);
});

final webLogStatsProvider = FutureProvider<WebLogStats?>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getWebLogStats();
  return result.fold((_) => null, (stats) => stats);
});

final topWebsitesProvider = FutureProvider<List<TopWebsite>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getTopWebsites();
  return result.fold((_) => <TopWebsite>[], (list) => list);
});

final topUsersProvider = FutureProvider<List<TopUser>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getTopUsers();
  return result.fold((_) => <TopUser>[], (list) => list);
});

final departmentReportsProvider =
    FutureProvider<List<DepartmentReport>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getDepartmentReports();
  return result.fold((_) => <DepartmentReport>[], (list) => list);
});

// Connection Logs
final connectionLogsProvider = FutureProvider<List<ConnectionLog>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getConnectionLogs();
  return result.fold((_) => <ConnectionLog>[], (list) => list);
});

final activeConnectionsProvider =
    FutureProvider<List<ConnectionLog>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getActiveConnections();
  return result.fold((_) => <ConnectionLog>[], (list) => list);
});

final activeConnectionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getActiveConnectionCount();
  return result.fold((_) => 0, (count) => count);
});

// Download Logs
final downloadLogsProvider = FutureProvider<List<DownloadLog>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getDownloadLogs();
  return result.fold((_) => <DownloadLog>[], (list) => list);
});

// Reports
final reportsListProvider = FutureProvider<List<Report>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getReportsList();
  return result.fold((_) => <Report>[], (list) => list);
});

final reportDetailProvider =
    FutureProvider.family<Report?, Map<String, dynamic>>(
  (ref, params) async {
    final repo = ref.watch(reportingRepositoryProvider);
    final result = await repo.getReportDetail(
      reportType: params['reportType'] as String,
      periodStart: params['periodStart'] as DateTime,
      periodEnd: params['periodEnd'] as DateTime,
    );
    return result.fold((_) => null, (report) => report);
  },
);

final topBandwidthConsumersProvider =
    FutureProvider<List<TopBandwidthConsumer>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getTopBandwidthConsumers();
  return result.fold((_) => <TopBandwidthConsumer>[], (list) => list);
});

// Exports
final exportsListProvider = FutureProvider<List<ReportExport>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getExportsList();
  return result.fold((_) => <ReportExport>[], (list) => list);
});

// Analytics
final bandwidthOverTimeProvider =
    FutureProvider<List<BandwidthDataPoint>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getBandwidthOverTime();
  return result.fold((_) => <BandwidthDataPoint>[], (list) => list);
});

final analyticsSummaryProvider = FutureProvider<AnalyticsSummary?>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getAnalyticsSummary();
  return result.fold((_) => null, (summary) => summary);
});

final deviceAnalyticsProvider =
    FutureProvider.family<Map<String, dynamic>, String>(
  (ref, deviceId) async {
    final repo = ref.watch(reportingRepositoryProvider);
    final result = await repo.getDeviceAnalytics(deviceId);
    return result.fold((_) => <String, dynamic>{}, (data) => data);
  },
);

// Alert Rules
final alertRulesProvider = FutureProvider<List<AlertRule>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getAlertRules();
  return result.fold((_) => <AlertRule>[], (list) => list);
});

final alertRuleDetailProvider = FutureProvider.family<AlertRule?, String>(
  (ref, id) async {
    final repo = ref.watch(reportingRepositoryProvider);
    final result = await repo.getAlertRuleById(id);
    return result.fold((_) => null, (rule) => rule);
  },
);

// Alert Notifications
final notificationsProvider = FutureProvider<List<AlertNotification>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getNotifications();
  return result.fold((_) => <AlertNotification>[], (list) => list);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getUnreadCount();
  return result.fold((_) => 0, (count) => count);
});

final recentNotificationsProvider =
    FutureProvider<List<AlertNotification>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getRecentNotifications();
  return result.fold((_) => <AlertNotification>[], (list) => list);
});

// Dashboard Widgets
final dashboardWidgetsProvider =
    FutureProvider<List<DashboardWidget>>((ref) async {
  final repo = ref.watch(reportingRepositoryProvider);
  final result = await repo.getUserWidgets();
  return result.fold((_) => <DashboardWidget>[], (list) => list);
});
