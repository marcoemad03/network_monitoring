import 'package:dartz/dartz.dart';
import '../../repositories/scan_repository.dart';
import '../../entities/device.dart';
import '../../../core/errors/failures.dart';

class GetScanResultsUseCase {
  final ScanRepository _repository;

  GetScanResultsUseCase(this._repository);

  Future<Either<Failure, List<Device>>> call(String scanId) {
    return _repository.getScanResults(scanId);
  }
}
