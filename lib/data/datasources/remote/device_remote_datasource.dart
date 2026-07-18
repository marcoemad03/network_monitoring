import '../../models/device_model.dart';
import '../../models/interface_model.dart';
import '../../models/device_metrics_model.dart';
import '../../models/device_client_model.dart';
import '../../models/device_traffic_model.dart';
import '../../models/device_ping_model.dart';
import '../../models/device_connection_model.dart';
import '../../models/dashboard_live_model.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class DeviceRemoteDataSource {
  Future<List<DeviceModel>> getDevices({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool ascending = true,
  });
  Future<DeviceModel> getDeviceById(String id);
  Future<DeviceModel> createDevice(Map<String, dynamic> data);
  Future<DeviceModel> updateDevice(String id, Map<String, dynamic> data);
  Future<void> deleteDevice(String id);
  Future<List<InterfaceModel>> getDeviceInterfaces(String deviceId);
  Future<DeviceMetricsModel> getDeviceMetrics(String deviceId);
  Future<List<DeviceMetricsModel>> getDeviceMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });

  // Monitoring
  Future<DashboardLiveModel> getDashboardSummary();
  Future<List<DeviceClientModel>> getDeviceClients(String deviceId);
  Future<List<DeviceClientModel>> getAllClients();
  Future<List<DeviceConnectionModel>> getConnections();
  Future<DeviceMetricsModel> getLatestMetrics(String deviceId);
  Future<List<DeviceMetricsModel>> getMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<DevicePingModel> getLatestPing(String deviceId);
  Future<List<DevicePingModel>> getPingHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<DeviceTrafficModel> getLatestTraffic(String deviceId);
  Future<List<DeviceTrafficModel>> getTrafficHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
}

class DeviceRemoteDataSourceImpl implements DeviceRemoteDataSource {
  final DioClient _client;

  DeviceRemoteDataSourceImpl(this._client);

  @override
  Future<List<DeviceModel>> getDevices({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool ascending = true,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null) 'search': search,
      if (status != null) 'status': status,
      if (type != null) 'type': type,
      if (department != null) 'department': department,
      if (sortBy != null) 'sort_by': sortBy,
      'ascending': ascending,
    };
    final response = await _client.get(
      ApiConstants.devices,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<DeviceModel> getDeviceById(String id) async {
    final response = await _client.get(ApiConstants.deviceDetail(id));
    return DeviceModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<DeviceModel> createDevice(Map<String, dynamic> data) async {
    final response = await _client.post(
      ApiConstants.devices,
      data: data,
    );
    return DeviceModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<DeviceModel> updateDevice(
    String id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.put(
      ApiConstants.deviceDetail(id),
      data: data,
    );
    return DeviceModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteDevice(String id) async {
    await _client.delete(ApiConstants.deviceDetail(id));
  }

  @override
  Future<List<InterfaceModel>> getDeviceInterfaces(String deviceId) async {
    final response = await _client.get(
      ApiConstants.deviceInterfaces(deviceId),
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => InterfaceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DeviceMetricsModel> getDeviceMetrics(String deviceId) async {
    final response = await _client.get(
      ApiConstants.deviceMetrics(deviceId),
    );
    return DeviceMetricsModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<DeviceMetricsModel>> getDeviceMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      ApiConstants.deviceMetrics(deviceId),
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => DeviceMetricsModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<DashboardLiveModel> getDashboardSummary() async {
    final response = await _client.get(ApiConstants.monitoringDashboard);
    return DashboardLiveModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<DeviceClientModel>> getDeviceClients(String deviceId) async {
    final response = await _client.get(ApiConstants.deviceClients(deviceId));
    final data = response.data['data'] as List;
    return data.map((e) => DeviceClientModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<DeviceClientModel>> getAllClients() async {
    final response = await _client.get(ApiConstants.monitoringClients);
    final data = response.data['data'] as List;
    return data.map((e) => DeviceClientModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<DeviceConnectionModel>> getConnections() async {
    final response = await _client.get(ApiConstants.monitoringConnections);
    final data = response.data['data'] as List;
    return data.map((e) => DeviceConnectionModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<DeviceMetricsModel> getLatestMetrics(String deviceId) async {
    final response = await _client.get(ApiConstants.deviceLatestMetrics(deviceId));
    return DeviceMetricsModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<DeviceMetricsModel>> getMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      ApiConstants.deviceMetricsHistory(deviceId),
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final data = response.data['data'] as List;
    return data.map((e) => DeviceMetricsModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<DevicePingModel> getLatestPing(String deviceId) async {
    final response = await _client.get(
      '${ApiConstants.devicePingHistory(deviceId)}?limit=1',
    );
    final data = response.data['data'] as List;
    if (data.isEmpty) throw const ServerException(message: 'No ping data available');
    return DevicePingModel.fromJson(data.first as Map<String, dynamic>);
  }

  @override
  Future<List<DevicePingModel>> getPingHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      ApiConstants.devicePingHistory(deviceId),
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final data = response.data['data'] as List;
    return data.map((e) => DevicePingModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<DeviceTrafficModel> getLatestTraffic(String deviceId) async {
    final response = await _client.get(
      '${ApiConstants.deviceTrafficHistory(deviceId)}?limit=1',
    );
    final data = response.data['data'] as List;
    if (data.isEmpty) throw const ServerException(message: 'No traffic data available');
    return DeviceTrafficModel.fromJson(data.first as Map<String, dynamic>);
  }

  @override
  Future<List<DeviceTrafficModel>> getTrafficHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.get(
      ApiConstants.deviceTrafficHistory(deviceId),
      queryParameters: {
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
      },
    );
    final data = response.data['data'] as List;
    return data.map((e) => DeviceTrafficModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}
