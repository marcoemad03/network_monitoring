import 'package:dartz/dartz.dart';
import '../../repositories/alert_repository.dart';
import '../../entities/alert.dart';
import '../../../core/errors/failures.dart';

class AcknowledgeAlertUseCase {
  final AlertRepository _repository;

  AcknowledgeAlertUseCase(this._repository);

  Future<Either<Failure, Alert>> call(
    String id, {
    String? notes,
  }) {
    return _repository.acknowledgeAlert(id, notes: notes);
  }
}
