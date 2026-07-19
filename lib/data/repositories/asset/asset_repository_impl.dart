import 'package:dartz/dartz.dart';
import '../../../domain/repositories/asset_repository.dart';
import '../../../domain/entities/asset/device_group.dart';
import '../../../domain/entities/asset/floor_map.dart';
import '../../../domain/entities/asset/floor_map_device.dart';
import '../../../domain/entities/asset/asset_detail.dart';
import '../../../domain/entities/asset/policy.dart';
import '../../../domain/entities/asset/sync_log.dart';
import '../../../core/errors/failures.dart';
import '../../../core/errors/error_handler.dart';
import '../../datasources/remote/asset/asset_remote_datasource.dart';

class AssetRepositoryImpl implements AssetRepository {
  final AssetRemoteDataSource _remoteDataSource;

  AssetRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<DeviceGroup>>> getGroups() async {
    try {
      final models = await _remoteDataSource.getGroups();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceGroup>> getGroup(String id) async {
    try {
      final model = await _remoteDataSource.getGroup(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceGroup>> createGroup(Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.createGroup(data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceGroup>> updateGroup(String id, Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.updateGroup(id, data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteGroup(String id) async {
    try {
      await _remoteDataSource.deleteGroup(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> assignDevicesToGroup(String groupId, List<String> deviceIds) async {
    try {
      await _remoteDataSource.assignDevicesToGroup(groupId, deviceIds);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> removeDeviceFromGroup(String groupId, String deviceId) async {
    try {
      await _remoteDataSource.removeDeviceFromGroup(groupId, deviceId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getGroupDeviceIds(String groupId) async {
    try {
      final ids = await _remoteDataSource.getGroupDeviceIds(groupId);
      return Right(ids);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceGroup>>> getDeviceGroups(String deviceId) async {
    try {
      final models = await _remoteDataSource.getDeviceGroups(deviceId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<FloorMap>>> getFloorMaps() async {
    try {
      final models = await _remoteDataSource.getFloorMaps();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, FloorMap>> getFloorMap(String id) async {
    try {
      final model = await _remoteDataSource.getFloorMap(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, FloorMap>> createFloorMap(Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.createFloorMap(data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, FloorMap>> updateFloorMap(String id, Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.updateFloorMap(id, data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteFloorMap(String id) async {
    try {
      await _remoteDataSource.deleteFloorMap(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, FloorMapDevice>> placeDeviceOnMap(Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.placeDeviceOnMap(data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> removeDeviceFromMap(String floorMapId, String deviceId) async {
    try {
      await _remoteDataSource.removeDeviceFromMap(floorMapId, deviceId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<FloorMapDevice>>> getFloorMapDevices(String floorMapId) async {
    try {
      final models = await _remoteDataSource.getFloorMapDevices(floorMapId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, AssetDetail>> getAssetDetail(String deviceId) async {
    try {
      final model = await _remoteDataSource.getAssetDetail(deviceId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, AssetDetail>> upsertAssetDetail(Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.upsertAssetDetail(data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<AssetDetail>>> getAssetDetails() async {
    try {
      final models = await _remoteDataSource.getAssetDetails();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Policy>>> getPolicies() async {
    try {
      final models = await _remoteDataSource.getPolicies();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Policy>> getPolicy(String id) async {
    try {
      final model = await _remoteDataSource.getPolicy(id);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Policy>> createPolicy(Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.createPolicy(data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Policy>> updatePolicy(String id, Map<String, dynamic> data) async {
    try {
      final model = await _remoteDataSource.updatePolicy(id, data);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deletePolicy(String id) async {
    try {
      await _remoteDataSource.deletePolicy(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> assignPolicyToGroup(String policyId, String groupId) async {
    try {
      await _remoteDataSource.assignPolicyToGroup(policyId, groupId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> removePolicyFromGroup(String policyId, String groupId) async {
    try {
      await _remoteDataSource.removePolicyFromGroup(policyId, groupId);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Policy>>> getPoliciesForGroup(String groupId) async {
    try {
      final models = await _remoteDataSource.getPoliciesForGroup(groupId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> syncPolicies() async {
    try {
      await _remoteDataSource.syncPolicies();
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<SyncLog>>> getSyncLogs() async {
    try {
      final models = await _remoteDataSource.getSyncLogs();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }
}
