import 'package:dartz/dartz.dart';
import '../../domain/repositories/reporting_repository.dart';
import '../../domain/entities/reporting/web_log_entity.dart';
import '../../domain/entities/reporting/connection_log_entity.dart';
import '../../domain/entities/reporting/download_log_entity.dart';
import '../../domain/entities/reporting/report_entity.dart';
import '../../domain/entities/reporting/report_export_entity.dart';
import '../../domain/entities/reporting/alert_rule_entity.dart';
import '../../domain/entities/reporting/alert_notification_entity.dart';
import '../../domain/entities/reporting/dashboard_widget_entity.dart';
import '../../domain/entities/reporting/analytics_entities.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../datasources/remote/reporting_remote_datasource.dart';
import '../../core/network/network_info.dart';

class ReportingRepositoryImpl implements ReportingRepository {
  final ReportingRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  ReportingRepositoryImpl({
    required ReportingRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
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
  }) async {
    try {
      final models = await _remoteDataSource.getWebLogs(
        page: page,
        limit: limit,
        deviceId: deviceId,
        domain: domain,
        category: category,
        isBlocked: isBlocked,
        from: from,
        to: to,
        search: search,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, WebLogStats>> getWebLogStats({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final model = await _remoteDataSource.getWebLogStats(from: from, to: to);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<TopWebsite>>> getTopWebsites({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      final models = await _remoteDataSource.getTopWebsites(
        from: from,
        to: to,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<TopUser>>> getTopUsers({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      final models = await _remoteDataSource.getTopUsers(
        from: from,
        to: to,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<DepartmentReport>>> getDepartmentReports({
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final models =
          await _remoteDataSource.getDepartmentReports(from: from, to: to);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<ConnectionLog>>> getConnectionLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    bool? isActive,
    String? deviceId,
  }) async {
    try {
      final models = await _remoteDataSource.getConnectionLogs(
        page: page,
        limit: limit,
        from: from,
        to: to,
        isActive: isActive,
        deviceId: deviceId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<ConnectionLog>>> getActiveConnections() async {
    try {
      final models = await _remoteDataSource.getActiveConnections();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getActiveConnectionCount() async {
    try {
      final count = await _remoteDataSource.getActiveConnectionCount();
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<DownloadLog>>> getDownloadLogs({
    int page = 1,
    int limit = 20,
    DateTime? from,
    DateTime? to,
    String? status,
    String? deviceId,
  }) async {
    try {
      final models = await _remoteDataSource.getDownloadLogs(
        page: page,
        limit: limit,
        from: from,
        to: to,
        status: status,
        deviceId: deviceId,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, Report>> generateReport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final model = await _remoteDataSource.generateReport(
        reportType: reportType,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<Report>>> getReportsList({
    String? reportType,
    int? limit,
  }) async {
    try {
      final models = await _remoteDataSource.getReportsList(
        reportType: reportType,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, Report>> getReportDetail({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      final model = await _remoteDataSource.getReportDetail(
        reportType: reportType,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<TopBandwidthConsumer>>> getTopBandwidthConsumers({
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    try {
      final models = await _remoteDataSource.getTopBandwidthConsumers(
        from: from,
        to: to,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, ReportExport>> generateExport({
    required String reportType,
    required DateTime periodStart,
    required DateTime periodEnd,
    required String format,
  }) async {
    try {
      final model = await _remoteDataSource.generateExport(
        reportType: reportType,
        periodStart: periodStart,
        periodEnd: periodEnd,
        format: format,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<ReportExport>>> getExportsList() async {
    try {
      final models = await _remoteDataSource.getExportsList();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, String>> downloadExport(String id) async {
    try {
      final url = await _remoteDataSource.downloadExport(id);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteExport(String id) async {
    try {
      await _remoteDataSource.deleteExport(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<BandwidthDataPoint>>> getBandwidthOverTime({
    DateTime? from,
    DateTime? to,
    String? interval,
  }) async {
    try {
      final models = await _remoteDataSource.getBandwidthOverTime(
        from: from,
        to: to,
        interval: interval,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, AnalyticsSummary>> getAnalyticsSummary() async {
    try {
      final model = await _remoteDataSource.getAnalyticsSummary();
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDeviceAnalytics(
    String deviceId, {
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      final data = await _remoteDataSource.getDeviceAnalytics(
        deviceId,
        from: from,
        to: to,
      );
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<AlertRule>>> getAlertRules() async {
    try {
      final models = await _remoteDataSource.getAlertRules();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, AlertRule>> getAlertRuleById(String id) async {
    try {
      final model = await _remoteDataSource.getAlertRuleById(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, AlertRule>> createAlertRule(AlertRule rule) async {
    try {
      final model = await _remoteDataSource.createAlertRule(rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, AlertRule>> updateAlertRule(AlertRule rule) async {
    try {
      final model = await _remoteDataSource.updateAlertRule(rule);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAlertRule(String id) async {
    try {
      await _remoteDataSource.deleteAlertRule(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<AlertNotification>>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final models = await _remoteDataSource.getNotifications(
        page: page,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await _remoteDataSource.getUnreadCount();
      return Right(count);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String id) async {
    try {
      await _remoteDataSource.markAsRead(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> acknowledgeNotification(String id) async {
    try {
      await _remoteDataSource.acknowledgeNotification(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<AlertNotification>>> getRecentNotifications({
    int? limit,
  }) async {
    try {
      final models =
          await _remoteDataSource.getRecentNotifications(limit: limit);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, List<DashboardWidget>>> getUserWidgets() async {
    try {
      final models = await _remoteDataSource.getUserWidgets();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, DashboardWidget>> createWidget(
      DashboardWidget widget) async {
    try {
      final model = await _remoteDataSource.createWidget(widget);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, DashboardWidget>> updateWidget(
      DashboardWidget widget) async {
    try {
      final model = await _remoteDataSource.updateWidget(widget);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> deleteWidget(String id) async {
    try {
      await _remoteDataSource.deleteWidget(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }

  @override
  Future<Either<Failure, void>> reorderWidgets(
      List<Map<String, dynamic>> items) async {
    try {
      await _remoteDataSource.reorderWidgets(items);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    }
  }
}
