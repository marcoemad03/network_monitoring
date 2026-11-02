class MarcoMember {
  final String deviceId;
  final String name;
  final String? hostname;
  final String? macAddress;
  final String? ipAddress;
  final bool isOnline;

  const MarcoMember({
    required this.deviceId,
    required this.name,
    this.hostname,
    this.macAddress,
    this.ipAddress,
    this.isOnline = false,
  });

  factory MarcoMember.fromJson(Map<String, dynamic> json) => MarcoMember(
        deviceId: json['device_id'] as String? ?? '',
        name: json['device_name'] as String? ?? '',
        hostname: json['hostname'] as String?,
        macAddress: json['mac_address'] as String?,
        ipAddress: json['ip_address'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
      );

  String get label {
    if (name.isNotEmpty && name != macAddress) return name;
    if (hostname != null && hostname!.isNotEmpty) return hostname!;
    return macAddress ?? deviceId;
  }
}

/// A Marco group as stored on the backend. [policy] uses the backend keys:
/// internet_enabled, unlimited_speed, download_limit_mbps, upload_limit_mbps,
/// daily_quota_gb, monthly_quota_gb, schedule_start_time, schedule_end_time,
/// schedule_days, blocked_websites, qos_priority.
class MarcoGroup {
  final String id;
  final String name;
  final String description;
  final String color;
  final String icon;
  final Map<String, dynamic> policy;
  final List<MarcoMember> members;
  final DateTime createdAt;

  const MarcoGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.icon,
    required this.policy,
    required this.members,
    required this.createdAt,
  });

  List<String> get macAddresses => members
      .map((m) => m.macAddress ?? '')
      .where((mac) => mac.isNotEmpty)
      .toList();

  bool hasMac(String mac) {
    final wanted = mac.toUpperCase();
    return members.any((m) => (m.macAddress ?? '').toUpperCase() == wanted);
  }

  factory MarcoGroup.fromJson(Map<String, dynamic> json) => MarcoGroup(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        color: json['color'] as String? ?? 'blue',
        icon: json['icon'] as String? ?? 'group',
        policy: Map<String, dynamic>.from(json['policy'] as Map? ?? const {}),
        members: ((json['members'] as List?) ?? const [])
            .map((e) => MarcoMember.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

class MarcoPlatform {
  final String key;
  final String label;

  const MarcoPlatform({required this.key, required this.label});

  factory MarcoPlatform.fromJson(Map<String, dynamic> json) => MarcoPlatform(
        key: json['key'] as String,
        label: json['label'] as String? ?? json['key'] as String,
      );
}

class MarcoGroupsResult {
  final List<MarcoGroup> groups;

  /// True while the backend has router writes disabled (policies are saved and
  /// planned but never applied to the MikroTik).
  final bool dryRun;

  const MarcoGroupsResult({required this.groups, required this.dryRun});
}

class MarcoActionResult {
  final bool dryRun;
  final String message;

  const MarcoActionResult({required this.dryRun, required this.message});
}

class MarcoSyncPreview {
  final bool dryRun;
  final List<String> plannedChanges;
  final List<String> warnings;
  final String message;

  /// Old rules still on the router that were not removed because there are many.
  final int prunePending;

  const MarcoSyncPreview({
    required this.dryRun,
    required this.plannedChanges,
    required this.warnings,
    required this.message,
    this.prunePending = 0,
  });
}

class MarcoPolicyLog {
  final String action;
  final String message;
  final String status;
  final DateTime createdAt;

  const MarcoPolicyLog({
    required this.action,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory MarcoPolicyLog.fromJson(Map<String, dynamic> json) => MarcoPolicyLog(
        action: json['action'] as String? ?? '',
        message: json['message'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
