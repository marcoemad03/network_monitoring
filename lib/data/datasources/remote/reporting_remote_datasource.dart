import '../../models/reporting/web_log_model.dart';
import '../../models/reporting/connection_log_model.dart';
import '../../models/reporting/download_log_model.dart';
import '../../models/reporting/report_model.dart';
import '../../models/reporting/report_export_model.dart';
import '../../models/reporting/alert_rule_model.dart';
import '../../models/reporting/alert_notification_model.dart';
import '../../models/reporting/dashboard_widget_model.dart';
import '../../models/reporting/analytics_models.dart';
import '../../../domain/entities/reporting/alert_rule_entity.dart';
import '../../../domain/entities/reporting/dashboard_widget_entity.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class ReportingRemoteDataSource {
  // Web Logs
  Future<List<WebLogModel>> getWebLogs({
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
  Future<WebLogStatsModel> getWebLogStats({DateTime? from, DateTime? to});
  Future<List<TopWebsiteModel>> getTopWebsites({
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<List<TopUserModel>> getTopUsers({
    DateTime? from,
    DateTime? to,
    int? limit,
  });
  Future<List<DepartmentReportModel>> getDepartmentReports({
    DateTime? from,
    DateTime? to,
  });

  // Connection Logs
  Future<List<ConnectionLogModel>> getConnectionLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    String? deviceId,
  });
  Future<List<ConnectionLogModel>> getActiveConnections();
  Future<int> getActiveConnectionCount();

  // Download Logs
  Future<List<DownloadLogModel>> getDownloadLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? status,
    String? deviceId,
  });

  // Reports
  Future<ReportModel> generateReport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  });
  Future<List<ReportModel>> getReportsList({String? reportType, int? limit});
  Future<ReportModel> getReportDetail({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  });
  Future<List<TopBandwidthConsumerModel>> getTopBandwidthConsumers({
    DateTime? from,
    DateTime? to,
    int? limit,
  });

  // Exports
  Future<ReportExportModel> generateExport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String format,
  });
  Future<List<ReportExportModel>> getExportsList();
  Future<String> downloadExport(String id);
  Future<void> deleteExport(String id);

  // Analytics
  Future<List<BandwidthDataPointModel>> getBandwidthOverTime({
    DateTime? from,
    DateTime? to,
    String? interval,
  });
  Future<AnalyticsSummaryModel> getAnalyticsSummary();
  Future<Map<String, dynamic>> getDeviceAnalytics(
    String deviceId, {
    DateTime? from,
    DateTime? to,
  });

  // Alert Rules
  Future<List<AlertRuleModel>> getAlertRules();
  Future<AlertRuleModel> getAlertRuleById(String id);
  Future<AlertRuleModel> createAlertRule(AlertRule rule);
  Future<AlertRuleModel> updateAlertRule(AlertRule rule);
  Future<void> deleteAlertRule(String id);

  // Alert Notifications
  Future<List<AlertNotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
  });
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<void> acknowledgeNotification(String id);
  Future<List<AlertNotificationModel>> getRecentNotifications({int? limit});

  // Dashboard Widgets
  Future<List<DashboardWidgetModel>> getUserWidgets();
  Future<DashboardWidgetModel> createWidget(DashboardWidget widget);
  Future<DashboardWidgetModel> updateWidget(DashboardWidget widget);
  Future<void> deleteWidget(String id);
  Future<void> reorderWidgets(List<Map<String, dynamic>> items);
}

class ReportingRemoteDataSourceImpl implements ReportingRemoteDataSource {
  final DioClient _client;

  ReportingRemoteDataSourceImpl(this._client);

  @override
  Future<List<WebLogModel>> getWebLogs({
    int page = 1,
    int limit = 20,
    String? deviceId,
    String? domain,
    String? category,
    bool? isBlocked,
    DateTime? from,
    DateTime? to,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (deviceId != null) 'device_id': deviceId,
      if (domain != null) 'domain': domain,
      if (category != null) 'category': category,
      if (isBlocked != null) 'is_blocked': isBlocked,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (search != null) 'search': search,
    };
    final response = await _client.get(
      ApiConstants.webLogs,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => WebLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WebLogStatsModel> getWebLogStats({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _client.get(
      ApiConstants.webLogStats,
      queryParameters: queryParams,
    );
    return WebLogStatsModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<TopWebsiteModel>> getTopWebsites({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (limit != null) 'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.topWebsites,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => TopWebsiteModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<TopUserModel>> getTopUsers({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (limit != null) 'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.topUsers,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => TopUserModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DepartmentReportModel>> getDepartmentReports({
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _client.get(
      ApiConstants.departmentReports,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => DepartmentReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ConnectionLogModel>> getConnectionLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    String? deviceId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (isActive != null) 'is_active': isActive,
      if (deviceId != null) 'device_id': deviceId,
    };
    final response = await _client.get(
      ApiConstants.connectionLogs,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map(
            (e) => ConnectionLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ConnectionLogModel>> getActiveConnections() async {
    final response = await _client.get(ApiConstants.activeConnections);
    final data = response.data['data'] as List;
    return data
        .map(
            (e) => ConnectionLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getActiveConnectionCount() async {
    final response = await _client.get(ApiConstants.activeConnections);
    final data = response.data['data'] as List;
    return data.length;
  }

  @override
  Future<List<DownloadLogModel>> getDownloadLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? status,
    String? deviceId,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (status != null) 'status': status,
      if (deviceId != null) 'device_id': deviceId,
    };
    final response = await _client.get(
      ApiConstants.downloadLogs,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => DownloadLogModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReportModel> generateReport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final response = await _client.post(
      ApiConstants.reportGenerate,
      data: {
        'report_type': reportType,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
      },
    );
    return ReportModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ReportModel>> getReportsList({
    String? reportType,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{
      if (reportType != null) 'report_type': reportType,
      if (limit != null) 'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.reports,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => ReportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReportModel> getReportDetail({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final queryParams = <String, dynamic>{
      'report_type': reportType,
      'period_start': periodStart.toIso8601String(),
      'period_end': periodEnd.toIso8601String(),
    };
    final response = await _client.get(
      ApiConstants.reportDetail,
      queryParameters: queryParams,
    );
    return ReportModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<TopBandwidthConsumerModel>> getTopBandwidthConsumers({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (limit != null) 'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.topBandwidth,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) =>
            TopBandwidthConsumerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ReportExportModel> generateExport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String format,
  }) async {
    final response = await _client.post(
      ApiConstants.exportGenerate,
      data: {
        'report_type': reportType,
        'period_start': periodStart.toIso8601String(),
        'period_end': periodEnd.toIso8601String(),
        'format': format,
      },
    );
    return ReportExportModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<ReportExportModel>> getExportsList() async {
    final response = await _client.get(ApiConstants.exports);
    final data = response.data['data'] as List;
    return data
        .map((e) => ReportExportModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<String> downloadExport(String id) async {
    final response = await _client.get(ApiConstants.exportDownload(id));
    final data = response.data['data'] as Map<String, dynamic>;
    return data['url'] as String;
  }

  @override
  Future<void> deleteExport(String id) async {
    await _client.delete(ApiConstants.exportDetail(id));
  }

  @override
  Future<List<BandwidthDataPointModel>> getBandwidthOverTime({
    DateTime? from,
    DateTime? to,
    String? interval,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      if (interval != null) 'interval': interval,
    };
    final response = await _client.get(
      ApiConstants.analyticsBandwidth,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) =>
            BandwidthDataPointModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AnalyticsSummaryModel> getAnalyticsSummary() async {
    final response = await _client.get(ApiConstants.analyticsSummary);
    return AnalyticsSummaryModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<Map<String, dynamic>> getDeviceAnalytics(
    String deviceId, {
    DateTime? from,
    DateTime? to,
  }) async {
    final queryParams = <String, dynamic>{
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
    };
    final response = await _client.get(
      ApiConstants.deviceAnalytics(deviceId),
      queryParameters: queryParams,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<List<AlertRuleModel>> getAlertRules() async {
    final response = await _client.get(ApiConstants.alertRules);
    final data = response.data['data'] as List;
    return data
        .map((e) => AlertRuleModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AlertRuleModel> getAlertRuleById(String id) async {
    final response = await _client.get(ApiConstants.alertRuleDetail(id));
    return AlertRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AlertRuleModel> createAlertRule(AlertRule rule) async {
    final data = AlertRuleModel.fromEntity(rule).toJson();
    final response =
        await _client.post(ApiConstants.alertRules, data: data);
    return AlertRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<AlertRuleModel> updateAlertRule(AlertRule rule) async {
    final data = AlertRuleModel.fromEntity(rule).toJson();
    final response = await _client.put(
      ApiConstants.alertRuleDetail(rule.id),
      data: data,
    );
    return AlertRuleModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAlertRule(String id) async {
    await _client.delete(ApiConstants.alertRuleDetail(id));
  }

  @override
  Future<List<AlertNotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.notifications,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) =>
            AlertNotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await _client.get(ApiConstants.unreadCount);
    return response.data['data']['count'] as int;
  }

  @override
  Future<void> markAsRead(String id) async {
    await _client.put(ApiConstants.markNotificationRead(id));
  }

  @override
  Future<void> acknowledgeNotification(String id) async {
    await _client.put(ApiConstants.acknowledgeNotification(id));
  }

  @override
  Future<List<AlertNotificationModel>> getRecentNotifications({
    int? limit,
  }) async {
    final queryParams = <String, dynamic>{
      if (limit != null) 'limit': limit,
    };
    final response = await _client.get(
      ApiConstants.notifications,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data
        .map((e) =>
            AlertNotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<DashboardWidgetModel>> getUserWidgets() async {
    final response = await _client.get(ApiConstants.dashboardWidgets);
    final data = response.data['data'] as List;
    return data
        .map((e) =>
            DashboardWidgetModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DashboardWidgetModel> createWidget(DashboardWidget widget) async {
    final data = DashboardWidgetModel.fromEntity(widget).toJson();
    final response =
        await _client.post(ApiConstants.dashboardWidgets, data: data);
    return DashboardWidgetModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<DashboardWidgetModel> updateWidget(DashboardWidget widget) async {
    final data = DashboardWidgetModel.fromEntity(widget).toJson();
    final response = await _client.put(
      ApiConstants.dashboardWidgetDetail(widget.id),
      data: data,
    );
    return DashboardWidgetModel.fromJson(
        response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteWidget(String id) async {
    await _client.delete(ApiConstants.dashboardWidgetDetail(id));
  }

  @override
  Future<void> reorderWidgets(List<Map<String, dynamic>> items) async {
    await _client.put(
      ApiConstants.dashboardWidgetReorder,
      data: {'items': items},
    );
  }
}
