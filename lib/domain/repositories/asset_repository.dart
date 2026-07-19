import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/asset/device_group.dart';
import '../entities/asset/floor_map.dart';
import '../entities/asset/floor_map_device.dart';
import '../entities/asset/asset_detail.dart';
import '../entities/asset/policy.dart';
import '../entities/asset/sync_log.dart';

abstract class AssetRepository {
  Future<Either<Failure, List<DeviceGroup>>> getGroups();
  Future<Either<Failure, DeviceGroup>> getGroup(String id);
  Future<Either<Failure, DeviceGroup>> createGroup(Map<String, dynamic> data);
  Future<Either<Failure, DeviceGroup>> updateGroup(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deleteGroup(String id);
  Future<Either<Failure, void>> assignDevicesToGroup(String groupId, List<String> deviceIds);
  Future<Either<Failure, void>> removeDeviceFromGroup(String groupId, String deviceId);
  Future<Either<Failure, List<String>>> getGroupDeviceIds(String groupId);
  Future<Either<Failure, List<DeviceGroup>>> getDeviceGroups(String deviceId);

  Future<Either<Failure, List<FloorMap>>> getFloorMaps();
  Future<Either<Failure, FloorMap>> getFloorMap(String id);
  Future<Either<Failure, FloorMap>> createFloorMap(Map<String, dynamic> data);
  Future<Either<Failure, FloorMap>> updateFloorMap(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deleteFloorMap(String id);
  Future<Either<Failure, FloorMapDevice>> placeDeviceOnMap(Map<String, dynamic> data);
  Future<Either<Failure, void>> removeDeviceFromMap(String floorMapId, String deviceId);
  Future<Either<Failure, List<FloorMapDevice>>> getFloorMapDevices(String floorMapId);

  Future<Either<Failure, AssetDetail>> getAssetDetail(String deviceId);
  Future<Either<Failure, AssetDetail>> upsertAssetDetail(Map<String, dynamic> data);
  Future<Either<Failure, List<AssetDetail>>> getAssetDetails();

  Future<Either<Failure, List<Policy>>> getPolicies();
  Future<Either<Failure, Policy>> getPolicy(String id);
  Future<Either<Failure, Policy>> createPolicy(Map<String, dynamic> data);
  Future<Either<Failure, Policy>> updatePolicy(String id, Map<String, dynamic> data);
  Future<Either<Failure, void>> deletePolicy(String id);
  Future<Either<Failure, void>> assignPolicyToGroup(String policyId, String groupId);
  Future<Either<Failure, void>> removePolicyFromGroup(String policyId, String groupId);
  Future<Either<Failure, List<Policy>>> getPoliciesForGroup(String groupId);
  Future<Either<Failure, void>> syncPolicies();
  Future<Either<Failure, List<SyncLog>>> getSyncLogs();
}
