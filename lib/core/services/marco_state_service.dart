import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/connected_device.dart';

class MarcoDeviceProfile {
  final String deviceId;
  final String? displayName;
  final String? comment;
  final String? groupId;
  final bool pinned;
  final DateTime updatedAt;

  const MarcoDeviceProfile({
    required this.deviceId,
    this.displayName,
    this.comment,
    this.groupId,
    this.pinned = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'device_id': deviceId,
    'display_name': displayName,
    'comment': comment,
    'group_id': groupId,
    'pinned': pinned,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory MarcoDeviceProfile.fromJson(Map<String, dynamic> json) =>
      MarcoDeviceProfile(
        deviceId: json['device_id'] as String,
        displayName: json['display_name'] as String?,
        comment: json['comment'] as String?,
        groupId: json['group_id'] as String?,
        pinned: json['pinned'] as bool? ?? false,
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class MarcoNotification {
  final String id;
  final String title;
  final String message;
  final String type;
  final String? deviceId;
  final DateTime createdAt;
  final bool isRead;

  const MarcoNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.deviceId,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'type': type,
    'device_id': deviceId,
    'created_at': createdAt.toIso8601String(),
    'is_read': isRead,
  };

  factory MarcoNotification.fromJson(Map<String, dynamic> json) =>
      MarcoNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        type: json['type'] as String,
        deviceId: json['device_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        isRead: json['is_read'] as bool? ?? false,
      );
}

class MarcoStateService {
  MarcoStateService(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _groupsKey = 'marco_groups';
  static const _profilesKey = 'marco_device_profiles';
  static const _notificationsKey = 'marco_notifications';
  static const _snapshotKey = 'marco_last_snapshot';

  static const _legacyImportedKey = 'marco_legacy_groups_imported';

  final Map<String, MarcoDeviceProfile> _profiles = {};
  final List<MarcoNotification> _notifications = [];
  final Set<String> _lastSnapshot = <String>{};

  List<MarcoNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Groups used to live only in this device's SharedPreferences. They are now
  /// stored on the backend; this returns the old local ones once so they can be
  /// imported (see marcoGroupsProvider).
  List<Map<String, dynamic>> pendingLegacyGroups() {
    if (_prefs.getBool(_legacyImportedKey) ?? false) return const [];
    final raw = _prefs.getStringList(_groupsKey) ?? const <String>[];
    final out = <Map<String, dynamic>>[];
    for (final entry in raw) {
      try {
        out.add(Map<String, dynamic>.from(jsonDecode(entry) as Map));
      } catch (_) {}
    }
    return out;
  }

  Future<void> markLegacyGroupsImported() => _prefs.setBool(_legacyImportedKey, true);

  Future<void> load() async => _load();

  Future<void> _load() async {
    final profilesJson = _prefs.getStringList(_profilesKey) ?? <String>[];
    _profiles.clear();
    for (final entry in profilesJson) {
      final decoded = jsonDecode(entry) as Map<String, dynamic>;
      final profile = MarcoDeviceProfile.fromJson(decoded);
      _profiles[profile.deviceId] = profile;
    }

    final notificationsJson = _prefs.getStringList(_notificationsKey) ?? <String>[];
    _notifications
      ..clear()
      ..addAll(
        notificationsJson.map(
          (entry) => MarcoNotification.fromJson(jsonDecode(entry)),
        ),
      );

    final snapshotJson = _prefs.getStringList(_snapshotKey) ?? <String>[];
    _lastSnapshot
      ..clear()
      ..addAll(snapshotJson);
  }

  Future<void> saveProfile(MarcoDeviceProfile profile) async {
    _profiles[profile.deviceId] = profile;
    await _persistProfiles();
  }

  Future<void> togglePin(String deviceId) async {
    final existing = _profiles[deviceId];
    if (existing == null) {
      await saveProfile(
        MarcoDeviceProfile(
          deviceId: deviceId,
          pinned: true,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    await saveProfile(
      MarcoDeviceProfile(
        deviceId: existing.deviceId,
        displayName: existing.displayName,
        comment: existing.comment,
        groupId: existing.groupId,
        pinned: !existing.pinned,
        updatedAt: DateTime.now(),
      ),
    );
  }

  MarcoDeviceProfile? profileFor(String deviceId) => _profiles[deviceId];

  Future<void> addNotification({
    required String title,
    required String message,
    required String type,
    String? deviceId,
  }) async {
    _notifications.insert(
      0,
      MarcoNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        message: message,
        type: type,
        deviceId: deviceId,
        createdAt: DateTime.now(),
      ),
    );
    if (_notifications.length > 50) {
      _notifications.removeRange(50, _notifications.length);
    }
    await _persistNotifications();
  }

  Future<void> markAllNotificationsRead() async {
    for (final notification in _notifications) {
      if (!notification.isRead) {
        _notifications[_notifications.indexOf(notification)] = MarcoNotification(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          deviceId: notification.deviceId,
          createdAt: notification.createdAt,
          isRead: true,
        );
      }
    }
    await _persistNotifications();
  }

  Future<void> updateDeviceSnapshot(List<ConnectedDevice> devices) async {
    final current = devices
        .map((device) => device.macAddress.isNotEmpty ? device.macAddress : device.id)
        .toSet();

    final newConnections = current.difference(_lastSnapshot);
    final droppedConnections = _lastSnapshot.difference(current);

    if (newConnections.isNotEmpty) {
      await addNotification(
        title: 'Device connected',
        message: 'New device activity detected on the network.',
        type: 'device_connected',
      );
    }

    if (droppedConnections.isNotEmpty) {
      await addNotification(
        title: 'Device disconnected',
        message: 'A previously active device disappeared from the live list.',
        type: 'device_disconnected',
      );
    }

    _lastSnapshot
      ..clear()
      ..addAll(current);
    await _persistSnapshot();
  }

  Future<void> _persistProfiles() async {
    final encoded = _profiles.values
        .map((profile) => jsonEncode(profile.toJson()))
        .toList();
    await _prefs.setStringList(_profilesKey, encoded);
  }

  Future<void> _persistNotifications() async {
    final encoded = _notifications
        .map((notification) => jsonEncode(notification.toJson()))
        .toList();
    await _prefs.setStringList(_notificationsKey, encoded);
  }

  Future<void> _persistSnapshot() async {
    await _prefs.setStringList(_snapshotKey, _lastSnapshot.toList());
  }
}
