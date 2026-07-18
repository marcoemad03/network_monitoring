import 'package:dartz/dartz.dart';
import '../../repositories/alert_repository.dart';
import '../../entities/alert.dart';
import '../../../core/errors/failures.dart';

class ResolveAlertUseCase {
  final AlertRepository _repository;

  ResolveAlertUseCase(this._repository);

  Future<Either<Failure, Alert>> call(
    String id, {
    required String resolutionNotes,
  }) {
    return _repository.resolveAlert(id, resolutionNotes: resolutionNotes);
  }
}
