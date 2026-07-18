import '../../models/network_scan_model.dart';
import '../../models/device_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class ScanRemoteDataSource {
  Future<NetworkScanModel> startScan({
    required String targetSubnet,
    String? name,
    String? portRange,
    List<int>? ports,
  });
  Future<NetworkScanModel> getScanStatus(String scanId);
  Future<List<DeviceModel>> getScanResults(String scanId);
  Future<List<NetworkScanModel>> getScanHistory({
    int page = 1,
    int limit = 20,
  });
  Future<void> cancelScan(String scanId);
}

class ScanRemoteDataSourceImpl implements ScanRemoteDataSource {
  final DioClient _client;

  ScanRemoteDataSourceImpl(this._client);

  @override
  Future<NetworkScanModel> startScan({
    required String targetSubnet,
    String? name,
    String? portRange,
    List<int>? ports,
  }) async {
    final response = await _client.post(
      ApiConstants.scans,
      data: {
        'target_subnet': targetSubnet,
        if (name != null) 'name': name,
        if (portRange != null) 'port_range': portRange,
        if (ports != null) 'ports': ports,
      },
    );
    return NetworkScanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<NetworkScanModel> getScanStatus(String scanId) async {
    final response = await _client.get(ApiConstants.scanResult(scanId));
    return NetworkScanModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  @override
  Future<List<DeviceModel>> getScanResults(String scanId) async {
    final response = await _client.get(
      '${ApiConstants.scanResult(scanId)}/devices',
    );
    final data = response.data['data'] as List;
    return data.map((e) => DeviceModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<NetworkScanModel>> getScanHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      ApiConstants.scans,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data['data'] as List;
    return data
        .map((e) => NetworkScanModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> cancelScan(String scanId) async {
    await _client.post(
      ApiConstants.scanResult(scanId),
      data: {'action': 'cancel'},
    );
  }
}
