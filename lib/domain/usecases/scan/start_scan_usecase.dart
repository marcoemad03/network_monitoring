import 'package:dartz/dartz.dart';
import '../../repositories/scan_repository.dart';
import '../../entities/network_scan.dart';
import '../../../core/errors/failures.dart';

class StartScanUseCase {
  final ScanRepository _repository;

  StartScanUseCase(this._repository);

  Future<Either<Failure, NetworkScan>> call({
    required String targetSubnet,
    String? name,
    String? portRange,
    List<int>? ports,
  }) {
    return _repository.startScan(
      targetSubnet: targetSubnet,
      name: name,
      portRange: portRange,
      ports: ports,
    );
  }
}
