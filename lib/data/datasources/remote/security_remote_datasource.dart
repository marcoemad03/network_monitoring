import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/security_models.dart';

/// Why a scan did not run, in words the page can show.
class ScanRefused implements Exception {
  final String code; // COOLDOWN, SCAN_RUNNING, ROUTER_BUSY, ROUTER_ERROR, NETWORK
  final String message;
  final int retryAfterSeconds;
  const ScanRefused(this.code, this.message, {this.retryAfterSeconds = 0});

  @override
  String toString() => message;
}

class SecurityRemoteDataSource {
  final DioClient _client;
  SecurityRemoteDataSource(this._client);

  static const _base = '${ApiConstants.basePath}/security';

  Future<SecurityOverview> overview() async {
    final response = await _client.get('$_base/overview', options: Options(receiveTimeout: const Duration(seconds: 20)));
    final body = Map<String, dynamic>.from(response.data as Map);
    return SecurityOverview.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Reads the router's connection table. It takes several seconds, and the
  /// router is busy for part of that time, so there is no automatic retry.
  Future<SecurityOverview> scan() async {
    try {
      final response = await _client.post(
        '$_base/scan',
        options: Options(receiveTimeout: const Duration(seconds: 120), extra: {'retryCount': 99}),
      );
      final body = Map<String, dynamic>.from(response.data as Map);
      return SecurityOverview.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        throw ScanRefused(
          data['error_code'] as String? ?? 'ROUTER_ERROR',
          data['message'] as String? ?? 'The scan failed.',
          retryAfterSeconds: (data['retry_after_seconds'] as num?)?.toInt() ?? 0,
        );
      }
      throw const ScanRefused('NETWORK', 'Could not reach the NMS server.');
    }
  }

  Future<DeviceDetail> device(String key) async {
    final response = await _client.get('$_base/devices/${Uri.encodeComponent(key)}');
    final body = Map<String, dynamic>.from(response.data as Map);
    return DeviceDetail.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }
}
