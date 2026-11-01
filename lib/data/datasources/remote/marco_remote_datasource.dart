import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../models/marco_models.dart';

/// Error carrying the backend's human readable message.
class MarcoApiException implements Exception {
  final String message;
  const MarcoApiException(this.message);

  @override
  String toString() => message;
}

class MarcoRemoteDataSource {
  final DioClient _client;

  MarcoRemoteDataSource(this._client);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw MarcoApiException(data['message'] as String);
      }
      throw MarcoApiException(e.message ?? 'Network error');
    }
  }

  Map<String, dynamic> _body(Response<dynamic> response) =>
      Map<String, dynamic>.from(response.data as Map);

  MarcoActionResult _result(Response<dynamic> response) {
    final body = _body(response);
    return MarcoActionResult(
      dryRun: body['dry_run'] as bool? ?? false,
      message: body['message'] as String? ?? '',
    );
  }

  Future<MarcoGroupsResult> listGroups() => _guard(() async {
        final body = _body(await _client.get('/marco/groups'));
        final groups = ((body['data'] as List?) ?? const [])
            .map((e) => MarcoGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return MarcoGroupsResult(groups: groups, dryRun: body['dry_run'] as bool? ?? true);
      });

  Future<List<MarcoPlatform>> listPlatforms() => _guard(() async {
        final body = _body(await _client.get('/marco/platforms'));
        return ((body['data'] as List?) ?? const [])
            .map((e) => MarcoPlatform.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  Future<MarcoGroup> createGroup({
    required String name,
    String? description,
    required String color,
    required String icon,
    Map<String, dynamic>? policy,
  }) =>
      _guard(() async {
        final body = _body(await _client.post('/marco/groups', data: {
          'name': name,
          if (description != null && description.isNotEmpty) 'description': description,
          'color': color,
          'icon': icon,
          if (policy != null) 'policy': policy,
        }));
        return MarcoGroup.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      });

  Future<void> updateGroup(
    String id, {
    required String name,
    required String description,
    required String color,
    required String icon,
  }) =>
      _guard(() async {
        await _client.put('/marco/groups/$id', data: {
          'name': name,
          'description': description,
          'color': color,
          'icon': icon,
        });
      });

  Future<MarcoActionResult> deleteGroup(String id) =>
      _guard(() async => _result(await _client.delete('/marco/groups/$id')));

  Future<MarcoActionResult> addMembers(String groupId, List<String> macAddresses) =>
      _guard(() async => _result(
            await _client.post('/marco/groups/$groupId/members', data: {'mac_addresses': macAddresses}),
          ));

  Future<MarcoActionResult> removeMember(String groupId, String deviceId) =>
      _guard(() async => _result(await _client.delete('/marco/groups/$groupId/members/$deviceId')));

  Future<MarcoActionResult> updatePolicy(String groupId, Map<String, dynamic> policy) =>
      _guard(() async => _result(await _client.put('/marco/groups/$groupId/policy', data: policy)));

  /// Recomputes the router plan. While the backend is in dry-run this never
  /// changes the router.
  Future<MarcoSyncPreview> sync() => _guard(() async {
        final body = _body(await _client.post('/marco/sync'));
        final data = Map<String, dynamic>.from(body['data'] as Map? ?? const {});
        return MarcoSyncPreview(
          dryRun: data['dry_run'] as bool? ?? true,
          plannedChanges: List<String>.from(data['planned_changes'] as List? ?? const []),
          warnings: List<String>.from(data['warnings'] as List? ?? const []),
          message: body['message'] as String? ?? '',
        );
      });

  Future<List<MarcoPolicyLog>> logs() => _guard(() async {
        final body = _body(await _client.get('/marco/logs'));
        return ((body['data'] as List?) ?? const [])
            .map((e) => MarcoPolicyLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });
}
