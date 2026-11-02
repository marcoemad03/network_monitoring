import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/client_inventory_models.dart';

/// Carries the backend's own message so the UI can show why a save failed.
class ClientApiException implements Exception {
  final String message;
  const ClientApiException(this.message);

  @override
  String toString() => message;
}

class ClientRemoteDataSource {
  final DioClient _client;
  ClientRemoteDataSource(this._client);

  static const _base = '${ApiConstants.basePath}/monitoring/clients/inventory';

  Future<ClientList> fetch() async {
    final response = await _client.get(_base, options: Options(receiveTimeout: const Duration(seconds: 20)));
    final body = Map<String, dynamic>.from(response.data as Map);
    return ClientList.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  /// Saves what the user typed. Only the given fields change; pass an empty
  /// string to clear one.
  Future<void> saveNote(String mac, {String? displayName, String? note, String? kind, String? place}) async {
    try {
      await _client.put(
        '$_base/${Uri.encodeComponent(mac)}',
        options: Options(extra: {'retryCount': 99}),
        data: {
          if (displayName != null) 'display_name': displayName,
          if (note != null) 'note': note,
          if (kind != null) 'kind': kind,
          if (place != null) 'place': place,
        },
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) throw ClientApiException(data['message'] as String);
      throw const ClientApiException('Could not save. Check the connection to the NMS server.');
    }
  }

  Future<List<ClientDay>> usage(String mac, {int days = 7}) async {
    final response = await _client.get(
      '$_base/${Uri.encodeComponent(mac)}/usage',
      queryParameters: {'days': days},
    );
    final body = Map<String, dynamic>.from(response.data as Map);
    return ((body['data'] as List?) ?? const [])
        .map((e) => ClientDay.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
