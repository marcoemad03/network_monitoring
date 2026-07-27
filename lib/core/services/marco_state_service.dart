import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/connected_device.dart';

class MarcoGroup {
  final String id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final List<String> macAddresses;
  final Map<String, dynamic> policy;
  final DateTime createdAt;

  const MarcoGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.macAddresses,
    required this.policy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'color': color,
    'icon': icon,
    'mac_addresses': macAddresses,
    'policy': policy,
    'created_at': createdAt.toIso8601String(),
  };

  factory MarcoGroup.fromJson(Map<String, dynamic> json) => MarcoGroup(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    color: json['color'] as String? ?? 'blue',
    icon: json['icon'] as String? ?? 'group',
    macAddresses: List<String>.from(json['mac_addresses'] ?? const []),
    policy: Map<String, dynamic>.from(json['policy'] ?? const {}),
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}

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

  final List<MarcoGroup> _groups = [];
  final Map<String, MarcoDeviceProfile> _profiles = {};
  final List<MarcoNotification> _notifications = [];
  final Set<String> _lastSnapshot = <String>{};

  List<MarcoGroup> get groups => List.unmodifiable(_groups);
  List<MarcoNotification> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  Future<void> load() async => _load();

  Future<void> _load() async {
    final groupsJson = _prefs.getStringList(_groupsKey) ?? <String>[];
    _groups
      ..clear()
      ..addAll(groupsJson.map((entry) => MarcoGroup.fromJson(jsonDecode(entry))));

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

  Future<void> saveGroup(MarcoGroup group) async {
    final existingIndex = _groups.indexWhere((entry) => entry.id == group.id);
    if (existingIndex >= 0) {
      _groups[existingIndex] = group;
    } else {
      _groups.add(group);
    }
    await _persistGroups();
  }

  Future<void> deleteGroup(String id) async {
    _groups.removeWhere((entry) => entry.id == id);
    await _persistGroups();
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

  Future<void> _persistGroups() async {
    final encoded = _groups.map((group) => jsonEncode(group.toJson())).toList();
    await _prefs.setStringList(_groupsKey, encoded);
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
