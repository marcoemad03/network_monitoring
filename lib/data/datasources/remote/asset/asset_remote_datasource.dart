import '../../../models/asset/device_group_model.dart';
import '../../../models/asset/floor_map_model.dart';
import '../../../models/asset/floor_map_device_model.dart';
import '../../../models/asset/asset_detail_model.dart';
import '../../../models/asset/policy_model.dart';
import '../../../models/asset/sync_log_model.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';

class AssetRemoteDataSource {
  final DioClient _client;

  AssetRemoteDataSource(this._client);

  Future<List<DeviceGroupModel>> getGroups() async {
    final response = await _client.get(ApiConstants.groups);
    final data = response.data['data'] as List;
    return data.map((e) => DeviceGroupModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DeviceGroupModel> getGroup(String id) async {
    final response = await _client.get(ApiConstants.groupDetail(id));
    return DeviceGroupModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<DeviceGroupModel> createGroup(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.groups, data: data);
    return DeviceGroupModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<DeviceGroupModel> updateGroup(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConstants.groupDetail(id), data: data);
    return DeviceGroupModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteGroup(String id) async {
    await _client.delete(ApiConstants.groupDetail(id));
  }

  Future<void> assignDevicesToGroup(String groupId, List<String> deviceIds) async {
    await _client.post(ApiConstants.groupDevices(groupId), data: {'device_ids': deviceIds});
  }

  Future<void> removeDeviceFromGroup(String groupId, String deviceId) async {
    await _client.delete(ApiConstants.groupDeviceItem(groupId, deviceId));
  }

  Future<List<String>> getGroupDeviceIds(String groupId) async {
    final response = await _client.get(ApiConstants.groupDevices(groupId));
    final data = response.data['data'] as List;
    return data.map((e) => e as String).toList();
  }

  Future<List<DeviceGroupModel>> getDeviceGroups(String deviceId) async {
    final response = await _client.get(ApiConstants.deviceGroups(deviceId));
    final data = response.data['data'] as List;
    return data.map((e) => DeviceGroupModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<FloorMapModel>> getFloorMaps() async {
    final response = await _client.get(ApiConstants.floorMaps);
    final data = response.data['data'] as List;
    return data.map((e) => FloorMapModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<FloorMapModel> getFloorMap(String id) async {
    final response = await _client.get(ApiConstants.floorMapDetail(id));
    return FloorMapModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<FloorMapModel> createFloorMap(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.floorMaps, data: data);
    return FloorMapModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<FloorMapModel> updateFloorMap(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConstants.floorMapDetail(id), data: data);
    return FloorMapModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteFloorMap(String id) async {
    await _client.delete(ApiConstants.floorMapDetail(id));
  }

  Future<FloorMapDeviceModel> placeDeviceOnMap(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.floorMapDevices, data: data);
    return FloorMapDeviceModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> removeDeviceFromMap(String floorMapId, String deviceId) async {
    await _client.delete(ApiConstants.floorMapDeviceItem(floorMapId, deviceId));
  }

  Future<List<FloorMapDeviceModel>> getFloorMapDevices(String floorMapId) async {
    final response = await _client.get(ApiConstants.floorMapDevicesList(floorMapId));
    final data = response.data['data'] as List;
    return data.map((e) => FloorMapDeviceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AssetDetailModel> getAssetDetail(String deviceId) async {
    final response = await _client.get(ApiConstants.deviceAssetDetail(deviceId));
    return AssetDetailModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<AssetDetailModel> upsertAssetDetail(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.assets, data: data);
    return AssetDetailModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<AssetDetailModel>> getAssetDetails() async {
    final response = await _client.get(ApiConstants.assets);
    final data = response.data['data'] as List;
    return data.map((e) => AssetDetailModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<PolicyModel>> getPolicies() async {
    final response = await _client.get(ApiConstants.policies);
    final data = response.data['data'] as List;
    return data.map((e) => PolicyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PolicyModel> getPolicy(String id) async {
    final response = await _client.get(ApiConstants.policyDetail(id));
    return PolicyModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<PolicyModel> createPolicy(Map<String, dynamic> data) async {
    final response = await _client.post(ApiConstants.policies, data: data);
    return PolicyModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<PolicyModel> updatePolicy(String id, Map<String, dynamic> data) async {
    final response = await _client.put(ApiConstants.policyDetail(id), data: data);
    return PolicyModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deletePolicy(String id) async {
    await _client.delete(ApiConstants.policyDetail(id));
  }

  Future<void> assignPolicyToGroup(String policyId, String groupId) async {
    await _client.post(ApiConstants.policyGroups(policyId), data: {'group_id': groupId});
  }

  Future<void> removePolicyFromGroup(String policyId, String groupId) async {
    await _client.delete(ApiConstants.policyGroupItem(policyId, groupId));
  }

  Future<List<PolicyModel>> getPoliciesForGroup(String groupId) async {
    final response = await _client.get(ApiConstants.groupPolicies(groupId));
    final data = response.data['data'] as List;
    return data.map((e) => PolicyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> syncPolicies() async {
    await _client.post(ApiConstants.policySync);
  }

  Future<List<SyncLogModel>> getSyncLogs() async {
    final response = await _client.get(ApiConstants.policySyncLogs);
    final data = response.data['data'] as List;
    return data.map((e) => SyncLogModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
}
