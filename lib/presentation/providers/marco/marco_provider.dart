import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../data/datasources/remote/marco_remote_datasource.dart';
import '../../../data/models/marco_models.dart';
import '../device/device_provider.dart';

final marcoRemoteProvider = Provider<MarcoRemoteDataSource>(
  (ref) => MarcoRemoteDataSource(ref.watch(dioProvider)),
);

final marcoPlatformsProvider = FutureProvider<List<MarcoPlatform>>(
  (ref) => ref.watch(marcoRemoteProvider).listPlatforms(),
);

final marcoLogsProvider = FutureProvider.autoDispose<List<MarcoPolicyLog>>(
  (ref) => ref.watch(marcoRemoteProvider).logs(),
);

final marcoGroupsProvider =
    AsyncNotifierProvider<MarcoGroupsController, MarcoGroupsResult>(
  MarcoGroupsController.new,
);

/// Looks up the Marco group a device (by MAC address) belongs to.
final marcoGroupByMacProvider = Provider.family<MarcoGroup?, String>((ref, mac) {
  if (mac.isEmpty) return null;
  final groups = ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const [];
  for (final group in groups) {
    if (group.hasMac(mac)) return group;
  }
  return null;
});

class MarcoGroupsController extends AsyncNotifier<MarcoGroupsResult> {
  MarcoRemoteDataSource get _remote => ref.read(marcoRemoteProvider);

  @override
  Future<MarcoGroupsResult> build() async {
    var result = await _remote.listGroups();
    if (await _importLegacyGroups(result.groups)) {
      result = await _remote.listGroups();
    }
    return result;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_remote.listGroups);
  }

  Future<void> _reload() async {
    state = AsyncData(await _remote.listGroups());
  }

  Future<MarcoActionResult> createGroup({
    required String name,
    String? description,
    required String color,
    required String icon,
    Map<String, dynamic>? policy,
  }) async {
    await _remote.createGroup(name: name, description: description, color: color, icon: icon, policy: policy);
    await _reload();
    return MarcoActionResult(dryRun: state.valueOrNull?.dryRun ?? true, message: 'Group created');
  }

  Future<void> updateGroup(
    String id, {
    required String name,
    required String description,
    required String color,
    required String icon,
  }) async {
    await _remote.updateGroup(id, name: name, description: description, color: color, icon: icon);
    await _reload();
  }

  Future<MarcoActionResult> deleteGroup(String id) async {
    try {
      return await _remote.deleteGroup(id);
    } finally {
      await _reload();
    }
  }

  Future<MarcoActionResult> addMembers(String groupId, List<String> macs) async {
    try {
      return await _remote.addMembers(groupId, macs);
    } finally {
      await _reload();
    }
  }

  Future<MarcoActionResult> removeMember(String groupId, String deviceId) async {
    try {
      return await _remote.removeMember(groupId, deviceId);
    } finally {
      await _reload();
    }
  }

  Future<MarcoActionResult> updatePolicy(String groupId, Map<String, dynamic> policy) async {
    try {
      return await _remote.updatePolicy(groupId, policy);
    } finally {
      await _reload();
    }
  }

  /// Moves a device (by MAC) into [groupId]; the backend removes it from its
  /// previous group in the same step.
  Future<MarcoActionResult> assignDevice(String groupId, String mac) =>
      addMembers(groupId, [mac]);

  // ---------------------------------------------------------------------
  // One-time import of groups that were stored only in this app's local storage.

  Future<bool> _importLegacyGroups(List<MarcoGroup> existing) async {
    final local = ref.read(marcoStateServiceProvider);
    final legacy = local.pendingLegacyGroups();
    if (legacy.isEmpty) return false;

    final names = existing.map((g) => g.name.toLowerCase()).toSet();
    var imported = false;
    for (final entry in legacy) {
      final name = (entry['name'] as String? ?? '').trim();
      if (name.isEmpty || names.contains(name.toLowerCase())) continue;
      try {
        final group = await _remote.createGroup(
          name: name,
          description: entry['description'] as String?,
          color: entry['color'] as String? ?? 'blue',
          icon: entry['icon'] as String? ?? 'group',
          policy: _translateLegacyPolicy(Map<String, dynamic>.from(entry['policy'] as Map? ?? const {})),
        );
        imported = true;
        final macs = List<String>.from(entry['mac_addresses'] as List? ?? const []);
        if (macs.isNotEmpty) {
          try {
            await _remote.addMembers(group.id, macs);
          } catch (_) {
            // Membership is saved even if the router sync fails; keep going.
          }
        }
      } catch (_) {
        return imported;
      }
    }
    await local.markLegacyGroupsImported();
    return imported;
  }

  static const _legacyPlatformKeys = {
    'youtube': 'youtube',
    'facebook': 'facebook',
    'instagram': 'instagram',
    'tiktok': 'tiktok',
    'x': 'twitter',
    'netflix': 'netflix',
    'chatgpt': 'chatgpt',
    'gemini': 'gemini',
    'claude': 'claude',
    'copilot': 'copilot',
    'steam': 'steam',
    'epic games': 'epicgames',
  };

  /// Only unambiguous keys are carried over. The old free-text "working hours"
  /// field is dropped: it was never enforced and the backend schedule means
  /// "internet blocked between start and end".
  Map<String, dynamic> _translateLegacyPolicy(Map<String, dynamic> old) {
    final out = <String, dynamic>{};
    for (final key in ['internet_enabled', 'unlimited_speed', 'download_limit_mbps', 'upload_limit_mbps', 'daily_quota_gb', 'monthly_quota_gb']) {
      if (old[key] != null) out[key] = old[key];
    }
    final qos = int.tryParse('${old['qos_priority'] ?? ''}');
    if (qos != null) out['qos_priority'] = qos;
    final categories = (old['website_categories'] as List?)?.whereType<String>() ?? const <String>[];
    final blocked = categories
        .map((c) => _legacyPlatformKeys[c.toLowerCase()])
        .whereType<String>()
        .toSet()
        .toList();
    if (blocked.isNotEmpty) out['blocked_websites'] = blocked;
    return out;
  }
}
