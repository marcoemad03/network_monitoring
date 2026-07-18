import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../domain/repositories/alert_repository.dart';
import '../../domain/entities/alert.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../../core/network/network_info.dart';
import '../datasources/remote/alert_remote_datasource.dart';

class AlertRepositoryImpl implements AlertRepository {
  final AlertRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final StreamController<Alert> _alertStreamController =
      StreamController<Alert>.broadcast();

  AlertRepositoryImpl({
    required AlertRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Stream<Alert> get alertStream => _alertStreamController.stream;

  @override
  Future<Either<Failure, List<Alert>>> getAlerts({
    int page = 1,
    int limit = 20,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool ascending = false,
  }) async {
    try {
      final models = await _remoteDataSource.getAlerts(
        page: page,
        limit: limit,
        status: status,
        severity: severity,
        category: category,
        deviceId: deviceId,
        sortBy: sortBy,
        ascending: ascending,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Alert>> getAlertById(String id) async {
    try {
      final model = await _remoteDataSource.getAlertById(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Alert>> acknowledgeAlert(
    String id, {
    String? notes,
  }) async {
    try {
      final model = await _remoteDataSource.acknowledgeAlert(id, notes: notes);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Alert>> resolveAlert(
    String id, {
    required String resolutionNotes,
  }) async {
    try {
      final model = await _remoteDataSource.resolveAlert(
        id,
        resolutionNotes: resolutionNotes,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> suppressAlert(
    String id, {
    required DateTime until,
  }) async {
    try {
      await _remoteDataSource.suppressAlert(id, until: until);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getAlertSeveritySummary() async {
    try {
      final alerts = await _remoteDataSource.getAlerts(limit: 10000);
      final summary = <String, int>{};
      for (final alert in alerts) {
        summary[alert.severity] = (summary[alert.severity] ?? 0) + 1;
      }
      return Right(summary);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getAlertStatusSummary() async {
    try {
      final alerts = await _remoteDataSource.getAlerts(limit: 10000);
      final summary = <String, int>{};
      for (final alert in alerts) {
        summary[alert.status] = (summary[alert.status] ?? 0) + 1;
      }
      return Right(summary);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  void addAlertToStream(Alert alert) {
    _alertStreamController.add(alert);
  }

  void dispose() {
    _alertStreamController.close();
  }
}
