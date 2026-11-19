/// A device that is part of a network problem.
class IssueDevice {
  final String mac;
  final String ip;
  final String name;
  final String kind;
  final String seen;
  final bool online;

  const IssueDevice({
    required this.mac,
    required this.ip,
    required this.name,
    required this.kind,
    required this.seen,
    required this.online,
  });

  factory IssueDevice.fromJson(Map<String, dynamic> j) => IssueDevice(
    mac: (j['mac'] as String?) ?? '',
    ip: (j['ip'] as String?) ?? '',
    name: (j['name'] as String?) ?? '',
    kind: (j['kind'] as String?) ?? '',
    seen: (j['seen'] as String?) ?? '',
    online: j['online'] == true,
  );

  String get label => name.isNotEmpty ? name : mac;
}

enum IssueSeverity { error, warning, info }

/// One problem the router check found.
class NetworkIssue {
  final String kind;
  final IssueSeverity severity;
  final String title;
  final String detail;
  final String fix;
  final String address;
  final List<IssueDevice> devices;

  const NetworkIssue({
    required this.kind,
    required this.severity,
    required this.title,
    required this.detail,
    required this.fix,
    required this.address,
    required this.devices,
  });

  factory NetworkIssue.fromJson(Map<String, dynamic> j) => NetworkIssue(
    kind: (j['kind'] as String?) ?? '',
    severity: switch (j['severity']) {
      'error' => IssueSeverity.error,
      'warning' => IssueSeverity.warning,
      _ => IssueSeverity.info,
    },
    title: (j['title'] as String?) ?? '',
    detail: (j['detail'] as String?) ?? '',
    fix: (j['fix'] as String?) ?? '',
    address: (j['address'] as String?) ?? '',
    devices: [
      for (final d in (j['devices'] as List?) ?? const [])
        IssueDevice.fromJson(Map<String, dynamic>.from(d as Map)),
    ],
  );

  /// Problems where two devices fight over one address.
  bool get isConflict => kind == 'ip_conflict' || kind == 'reserved_taken';
}

/// The answer of the network check.
class NetworkProblems {
  final bool available;
  final String error;
  final DateTime? checkedAt;
  final int devicesSeen;
  final List<NetworkIssue> issues;

  const NetworkProblems({
    required this.available,
    required this.error,
    required this.checkedAt,
    required this.devicesSeen,
    required this.issues,
  });

  factory NetworkProblems.fromJson(Map<String, dynamic> j) => NetworkProblems(
    available: j['available'] == true,
    error: (j['error'] as String?) ?? '',
    checkedAt: DateTime.tryParse((j['checked_at'] as String?) ?? '')?.toLocal(),
    devicesSeen: (j['devices_seen'] as num?)?.toInt() ?? 0,
    issues: [
      for (final i in (j['issues'] as List?) ?? const [])
        NetworkIssue.fromJson(Map<String, dynamic>.from(i as Map)),
    ],
  );
}
