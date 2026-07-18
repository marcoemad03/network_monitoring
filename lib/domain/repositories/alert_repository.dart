import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/alert.dart';

abstract class AlertRepository {
  Future<Either<Failure, List<Alert>>> getAlerts({
    int page = 1,
    int limit = 20,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool ascending = false,
  });
  Future<Either<Failure, Alert>> getAlertById(String id);
  Future<Either<Failure, Alert>> acknowledgeAlert(
    String id, {
    String? notes,
  });
  Future<Either<Failure, Alert>> resolveAlert(
    String id, {
    required String resolutionNotes,
  });
  Future<Either<Failure, void>> suppressAlert(
    String id, {
    required DateTime until,
  });
  Future<Either<Failure, Map<String, int>>> getAlertSeveritySummary();
  Future<Either<Failure, Map<String, int>>> getAlertStatusSummary();
  Stream<Alert> get alertStream;
}
