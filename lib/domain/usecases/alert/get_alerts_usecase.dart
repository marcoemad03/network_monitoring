import 'package:dartz/dartz.dart';
import '../../repositories/alert_repository.dart';
import '../../entities/alert.dart';
import '../../../core/errors/failures.dart';

class GetAlertsUseCase {
  final AlertRepository _repository;

  GetAlertsUseCase(this._repository);

  Future<Either<Failure, List<Alert>>> call({
    int page = 1,
    int limit = 20,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool ascending = false,
  }) {
    return _repository.getAlerts(
      page: page,
      limit: limit,
      status: status,
      severity: severity,
      category: category,
      deviceId: deviceId,
      sortBy: sortBy,
      ascending: ascending,
    );
  }
}
