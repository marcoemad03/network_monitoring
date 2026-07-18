import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/network_scan.dart';
import '../entities/device.dart';

abstract class ScanRepository {
  Future<Either<Failure, NetworkScan>> startScan({
    required String targetSubnet,
    String? name,
    String? portRange,
    List<int>? ports,
  });
  Future<Either<Failure, NetworkScan>> getScanStatus(String scanId);
  Future<Either<Failure, List<Device>>> getScanResults(String scanId);
  Future<Either<Failure, List<NetworkScan>>> getScanHistory({
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, void>> cancelScan(String scanId);
  Stream<NetworkScan> get scanProgressStream;
}
