import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/network_map_models.dart';
import 'client_remote_datasource.dart';

class NetworkMapRemoteDataSource {
  final DioClient _client;
  NetworkMapRemoteDataSource(this._client);

  static const _base = '${ApiConstants.basePath}/monitoring/network-map';

  /// [refresh] asks the server to read the router's wiring again (the server still
  /// limits that to once per 15 seconds).
  Future<NetworkMapData> fetch({bool refresh = false}) async {
    final response = await _client.get(
      _base,
      queryParameters: {if (refresh) 'refresh': 1},
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return NetworkMapData.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<T> _write<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) throw ClientApiException(data['message'] as String);
      throw const ClientApiException('Could not save. Check the connection to the NMS server.');
    }
  }

  /// Names a router port. An empty [label] removes the name.
  Future<void> savePortLabel(String port, String label) => _write(
    () => _client.put(
      '$_base/places/${Uri.encodeComponent(port)}',
      data: {'label': label},
      options: Options(extra: {'retryCount': 99}),
    ),
  );

  /// Says where several devices are. An empty [place] clears it. Returns how many were saved.
  Future<int> saveDevicePlaces(List<String> macs, String place) => _write(() async {
    final r = await _client.put(
      '$_base/device-places',
      data: {'macs': macs, 'place': place},
      options: Options(extra: {'retryCount': 99}),
    );
    final data = (r.data as Map)['data'];
    return data is Map ? (data['updated'] as num?)?.toInt() ?? macs.length : macs.length;
  });
}
