int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    ((v as List?) ?? const []).map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();

enum Severity {
  high('High'),
  medium('Medium'),
  low('Low'),
  info('Info');

  const Severity(this.label);
  final String label;

  static Severity parse(String? v) => Severity.values.firstWhere((s) => s.name == v, orElse: () => Severity.info);
}

/// What a destination is: a platform the router identified, a provider, an
/// application recognised by its port, another device, or an unknown host.
enum LabelKind {
  platform,
  provider,
  app,
  internal,
  other;

  static LabelKind parse(String? v) => LabelKind.values.firstWhere((k) => k.name == v, orElse: () => LabelKind.other);
}

class SecurityFinding {
  final Severity severity;
  final String code;
  final String title;
  final String detail;
  final String action;
  final String mac;
  final String ip;
  final String device;

  const SecurityFinding({
    required this.severity,
    required this.code,
    required this.title,
    this.detail = '',
    this.action = '',
    this.mac = '',
    this.ip = '',
    this.device = '',
  });

  /// The key the device can be opened with: its MAC, else its address.
  String get deviceKey => mac.isNotEmpty ? mac : ip;

  factory SecurityFinding.fromJson(Map<String, dynamic> j) => SecurityFinding(
        severity: Severity.parse(j['severity'] as String?),
        code: j['code'] as String? ?? '',
        title: j['title'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        action: j['action'] as String? ?? '',
        mac: j['mac'] as String? ?? '',
        ip: j['ip'] as String? ?? '',
        device: j['device'] as String? ?? '',
      );
}

class DestinationUse {
  final String name;
  final LabelKind kind;
  final int connections;
  final int devices;
  final int downloadBytes;
  final int uploadBytes;

  const DestinationUse({
    required this.name,
    this.kind = LabelKind.other,
    this.connections = 0,
    this.devices = 0,
    this.downloadBytes = 0,
    this.uploadBytes = 0,
  });

  int get totalBytes => downloadBytes + uploadBytes;

  factory DestinationUse.fromJson(Map<String, dynamic> j) => DestinationUse(
        name: j['name'] as String? ?? '',
        kind: LabelKind.parse(j['kind'] as String?),
        connections: _int(j['connections']),
        devices: _int(j['devices']),
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
      );
}

class FlowLine {
  final String protocol;
  final String destination;
  final int port;
  final String label;
  final LabelKind kind;
  final String app;
  final int downloadBytes;
  final int uploadBytes;

  const FlowLine({
    required this.protocol,
    required this.destination,
    required this.port,
    required this.label,
    this.kind = LabelKind.other,
    this.app = '',
    this.downloadBytes = 0,
    this.uploadBytes = 0,
  });

  factory FlowLine.fromJson(Map<String, dynamic> j) => FlowLine(
        protocol: j['protocol'] as String? ?? '',
        destination: j['destination'] as String? ?? '',
        port: _int(j['port']),
        label: j['label'] as String? ?? '',
        kind: LabelKind.parse(j['kind'] as String?),
        app: j['app'] as String? ?? '',
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
      );
}

class DeviceActivity {
  final String mac;
  final String ip;
  final String name;
  final String kind;
  final int connections;
  final int downloadBytes;
  final int uploadBytes;
  final int destinations;
  final List<DestinationUse> top;
  final List<FlowLine> flows;
  final int high;
  final int medium;

  const DeviceActivity({
    this.mac = '',
    required this.ip,
    required this.name,
    this.kind = 'unknown',
    this.connections = 0,
    this.downloadBytes = 0,
    this.uploadBytes = 0,
    this.destinations = 0,
    this.top = const [],
    this.flows = const [],
    this.high = 0,
    this.medium = 0,
  });

  String get key => mac.isNotEmpty ? mac : ip;
  int get totalBytes => downloadBytes + uploadBytes;
  bool get flagged => high + medium > 0;

  factory DeviceActivity.fromJson(Map<String, dynamic> j) => DeviceActivity(
        mac: j['mac'] as String? ?? '',
        ip: j['ip'] as String? ?? '',
        name: j['name'] as String? ?? (j['ip'] as String? ?? ''),
        kind: j['kind'] as String? ?? 'unknown',
        connections: _int(j['connections']),
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
        destinations: _int(j['destinations']),
        top: _list(j['top'], DestinationUse.fromJson),
        flows: _list(j['flows'], FlowLine.fromJson),
        high: _int(j['findings_high']),
        medium: _int(j['findings_medium']),
      );
}

class PopularDestination {
  final String label;
  final LabelKind kind;
  final int devices;
  final int scans;
  final int connections;
  final int bytes;

  const PopularDestination({required this.label, this.kind = LabelKind.other, this.devices = 0, this.scans = 0, this.connections = 0, this.bytes = 0});

  factory PopularDestination.fromJson(Map<String, dynamic> j) => PopularDestination(
        label: j['label'] as String? ?? '',
        kind: LabelKind.parse(j['kind'] as String?),
        devices: _int(j['devices']),
        scans: _int(j['scans']),
        connections: _int(j['connections']),
        bytes: _int(j['bytes']),
      );
}

class NewDevice {
  final String mac;
  final String ip;
  final String name;
  final String kind;
  final String vendor;
  final bool online;
  final DateTime? firstSeen;

  const NewDevice({required this.mac, this.ip = '', required this.name, this.kind = 'unknown', this.vendor = '', this.online = false, this.firstSeen});

  factory NewDevice.fromJson(Map<String, dynamic> j) => NewDevice(
        mac: j['mac'] as String? ?? '',
        ip: j['ip'] as String? ?? '',
        name: j['name'] as String? ?? '',
        kind: j['kind'] as String? ?? 'unknown',
        vendor: j['vendor'] as String? ?? '',
        online: j['online'] as bool? ?? false,
        firstSeen: _date(j['first_seen']),
      );
}

class ScanMeta {
  final DateTime takenAt;
  final int durationMs;
  final int connections;
  final int routerCpuBefore;
  final int routerCpuAfter;
  final bool restored;

  const ScanMeta({required this.takenAt, this.durationMs = 0, this.connections = 0, this.routerCpuBefore = 0, this.routerCpuAfter = 0, this.restored = false});

  factory ScanMeta.fromJson(Map<String, dynamic> j) => ScanMeta(
        takenAt: _date(j['taken_at']) ?? DateTime.now(),
        durationMs: _int(j['duration_ms']),
        connections: _int(j['connections']),
        routerCpuBefore: _int(j['router_cpu_before']),
        routerCpuAfter: _int(j['router_cpu_after']),
        restored: j['restored'] as bool? ?? false,
      );
}

class ScanSettings {
  final bool scanning;
  final String? lastError;
  final int cooldownSeconds;
  final int autoIntervalSeconds;
  final int maxRouterCpu;
  final int retentionDays;
  final List<String> platformsFromRouter;

  const ScanSettings({
    this.scanning = false,
    this.lastError,
    this.cooldownSeconds = 0,
    this.autoIntervalSeconds = 0,
    this.maxRouterCpu = 85,
    this.retentionDays = 30,
    this.platformsFromRouter = const [],
  });

  factory ScanSettings.fromJson(Map<String, dynamic> j) {
    final error = j['last_error'] as String?;
    return ScanSettings(
      scanning: j['scanning'] as bool? ?? false,
      lastError: (error == null || error.isEmpty) ? null : error,
      cooldownSeconds: _int(j['cooldown_seconds']),
      autoIntervalSeconds: _int(j['auto_interval_seconds']),
      maxRouterCpu: _int(j['max_router_cpu']),
      retentionDays: _int(j['retention_days']),
      platformsFromRouter: ((j['platforms_from_router'] as List?) ?? const []).cast<String>(),
    );
  }
}

class SecurityOverview {
  final bool scanned;
  final ScanMeta? scan;
  final ScanSettings settings;
  final int devices;
  final int connections;
  final int high;
  final int medium;
  final int newDeviceCount;
  final List<SecurityFinding> findings;
  final List<DeviceActivity> deviceList;
  final List<DestinationUse> topByData;
  final List<DestinationUse> topByDevices;
  final List<PopularDestination> popular;
  final List<NewDevice> newDevices;
  final DateTime? monitoringSince;

  const SecurityOverview({
    required this.scanned,
    this.scan,
    this.settings = const ScanSettings(),
    this.devices = 0,
    this.connections = 0,
    this.high = 0,
    this.medium = 0,
    this.newDeviceCount = 0,
    this.findings = const [],
    this.deviceList = const [],
    this.topByData = const [],
    this.topByDevices = const [],
    this.popular = const [],
    this.newDevices = const [],
    this.monitoringSince,
  });

  /// "New" means little before devices have been recorded for a full day.
  bool get newDevicesMeaningful => monitoringSince != null && DateTime.now().difference(monitoringSince!) > const Duration(hours: 24);

  factory SecurityOverview.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] is Map ? Map<String, dynamic>.from(j['summary'] as Map) : const <String, dynamic>{};
    return SecurityOverview(
      scanned: j['scanned'] as bool? ?? false,
      scan: j['scan'] is Map ? ScanMeta.fromJson(Map<String, dynamic>.from(j['scan'] as Map)) : null,
      settings: j['settings'] is Map ? ScanSettings.fromJson(Map<String, dynamic>.from(j['settings'] as Map)) : const ScanSettings(),
      devices: _int(summary['devices']),
      connections: _int(summary['connections']),
      high: _int(summary['findings_high']),
      medium: _int(summary['findings_medium']),
      newDeviceCount: _int(summary['new_devices']),
      findings: _list(j['findings'], SecurityFinding.fromJson),
      deviceList: _list(j['devices'], DeviceActivity.fromJson),
      topByData: _list(j['top_by_data'], DestinationUse.fromJson),
      topByDevices: _list(j['top_by_devices'], DestinationUse.fromJson),
      popular: _list(j['popular_7d'], PopularDestination.fromJson),
      newDevices: _list(j['new_devices'], NewDevice.fromJson),
      monitoringSince: _date(j['monitoring_since']),
    );
  }
}

class DeviceDetail {
  final DeviceActivity device;
  final List<PopularDestination> history;
  final ScanMeta scan;

  const DeviceDetail({required this.device, required this.history, required this.scan});

  factory DeviceDetail.fromJson(Map<String, dynamic> j) => DeviceDetail(
        device: DeviceActivity.fromJson(Map<String, dynamic>.from(j['device'] as Map)),
        history: _list(j['history_7d'], PopularDestination.fromJson),
        scan: ScanMeta.fromJson(Map<String, dynamic>.from(j['scan'] as Map)),
      );
}
