import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/marco_models.dart';
import '../../models/marco_site_models.dart';

/// Error carrying the backend's human readable message.
class MarcoApiException implements Exception {
  final String message;
  const MarcoApiException(this.message);

  @override
  String toString() => message;
}

const _base = '${ApiConstants.basePath}/marco';

// Writes must never be replayed by the retry interceptor (a retried member change
// would queue another router sync); the preview reads big router tables, so it
// gets a long receive timeout.
final _noRetry = Options(extra: {'retryCount': 99});
final _slow = Options(receiveTimeout: const Duration(seconds: 90), extra: {'retryCount': 99});

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
        final body = _body(await _client.get('$_base/groups'));
        final groups = ((body['data'] as List?) ?? const [])
            .map((e) => MarcoGroup.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return MarcoGroupsResult(groups: groups, dryRun: body['dry_run'] as bool? ?? true);
      });

  Future<List<MarcoPlatform>> listPlatforms() => _guard(() async {
        final body = _body(await _client.get('$_base/platforms'));
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
        final body = _body(await _client.post('$_base/groups', options: _noRetry, data: {
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
        await _client.put('$_base/groups/$id', options: _noRetry, data: {
          'name': name,
          'description': description,
          'color': color,
          'icon': icon,
        });
      });

  Future<MarcoActionResult> deleteGroup(String id) =>
      _guard(() async => _result(await _client.delete('$_base/groups/$id', options: _noRetry)));

  Future<MarcoActionResult> addMembers(String groupId, List<String> macAddresses) =>
      _guard(() async => _result(
            await _client.post('$_base/groups/$groupId/members', options: _noRetry, data: {'mac_addresses': macAddresses}),
          ));

  Future<MarcoActionResult> removeMember(String groupId, String deviceId) =>
      _guard(() async => _result(await _client.delete('$_base/groups/$groupId/members/$deviceId', options: _noRetry)));

  Future<MarcoActionResult> updatePolicy(String groupId, Map<String, dynamic> policy) =>
      _guard(() async => _result(await _client.put('$_base/groups/$groupId/policy', options: _noRetry, data: policy)));

  /// Recomputes the router plan. While the backend is in dry-run this never
  /// changes the router.
  Future<MarcoSyncPreview> sync() => _guard(() async {
        final body = _body(await _client.post('$_base/sync', options: _slow));
        final data = Map<String, dynamic>.from(body['data'] as Map? ?? const {});
        return MarcoSyncPreview(
          dryRun: data['dry_run'] as bool? ?? true,
          plannedChanges: List<String>.from(data['planned_changes'] as List? ?? const []),
          warnings: List<String>.from(data['warnings'] as List? ?? const []),
          message: body['message'] as String? ?? '',
        );
      });

  Future<List<MarcoPolicyLog>> logs() => _guard(() async {
        final body = _body(await _client.get('$_base/logs'));
        return ((body['data'] as List?) ?? const [])
            .map((e) => MarcoPolicyLog.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  // -------------------------------------------------------------------------
  // Group details, website blocking and per-device controls

  Future<MarcoGroupDetails> details(String groupId) => _guard(() async {
        final body = _body(await _client.get('$_base/groups/$groupId/details'));
        return MarcoGroupDetails.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      });

  Future<MarcoCatalog> catalog() => _guard(() async {
        final body = _body(await _client.get('$_base/sites/catalog'));
        return MarcoCatalog.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      });

  /// Looks the site up and says what blocking it would do, before it is added.
  Future<MarcoSiteCheck> checkSite(String site) => _guard(() async {
        final body = _body(await _client.post('$_base/sites/check', data: {'site': site}, options: Options(receiveTimeout: const Duration(seconds: 30))));
        return MarcoSiteCheck.fromJson(Map<String, dynamic>.from(body['data'] as Map));
      });

  Future<void> addAllowedSite(String site) =>
      _guard(() async => _client.post('$_base/sites/allowed', options: _noRetry, data: {'site': site}));

  Future<void> removeAllowedSite(String domain) =>
      _guard(() async => _client.delete('$_base/sites/allowed/${Uri.encodeComponent(domain)}', options: _noRetry));

  Future<List<MarcoDeviceControl>> overrides() => _guard(() async {
        final body = _body(await _client.get('$_base/overrides'));
        return ((body['data'] as List?) ?? const [])
            .map((e) => MarcoDeviceControl.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      });

  /// Blocks a device or limits its speed. No block and no limit removes the control.
  Future<MarcoActionResult> setDeviceControl(String mac, {required bool blocked, double? downloadMbps, double? uploadMbps, String reason = ''}) =>
      _guard(() async => _result(await _client.put(
            '$_base/overrides/${Uri.encodeComponent(mac)}',
            options: _noRetry,
            data: {'blocked': blocked, 'download_limit_mbps': downloadMbps, 'upload_limit_mbps': uploadMbps, 'reason': reason},
          )));

  Future<MarcoActionResult> clearDeviceControl(String mac) =>
      _guard(() async => _result(await _client.delete('$_base/overrides/${Uri.encodeComponent(mac)}', options: _noRetry)));
}
