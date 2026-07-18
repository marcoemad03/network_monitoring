import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../domain/repositories/scan_repository.dart';
import '../../domain/entities/network_scan.dart';
import '../../domain/entities/device.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../../core/network/network_info.dart';
import '../datasources/remote/scan_remote_datasource.dart';

class ScanRepositoryImpl implements ScanRepository {
  final ScanRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final StreamController<NetworkScan> _scanProgressController =
      StreamController<NetworkScan>.broadcast();

  ScanRepositoryImpl({
    required ScanRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo;

  @override
  Stream<NetworkScan> get scanProgressStream => _scanProgressController.stream;

  @override
  Future<Either<Failure, NetworkScan>> startScan({
    required String targetSubnet,
    String? name,
    String? portRange,
    List<int>? ports,
  }) async {
    try {
      final model = await _remoteDataSource.startScan(
        targetSubnet: targetSubnet,
        name: name,
        portRange: portRange,
        ports: ports,
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, NetworkScan>> getScanStatus(String scanId) async {
    try {
      final model = await _remoteDataSource.getScanStatus(scanId);
      _scanProgressController.add(model.toEntity());
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Device>>> getScanResults(String scanId) async {
    try {
      final models = await _remoteDataSource.getScanResults(scanId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<NetworkScan>>> getScanHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final models = await _remoteDataSource.getScanHistory(
        page: page,
        limit: limit,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> cancelScan(String scanId) async {
    try {
      await _remoteDataSource.cancelScan(scanId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  void updateScanProgress(NetworkScan scan) {
    _scanProgressController.add(scan);
  }

  void dispose() {
    _scanProgressController.close();
  }
}
