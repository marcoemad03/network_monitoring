int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double _double(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// The internet link measured on the router's WAN interface.
class WanUsage {
  final bool available;
  final String? error;
  final bool stale;
  final String? interfaceName;
  final bool linkRunning;
  final WanSpeed? current;
  final WanRouter? router;
  final WanSinceBoot? sinceBoot;
  final WanPeriod today;
  final WanPeriod month;
  final DateTime? trackingSince;
  final List<WanPoint> live;
  final List<WanPoint> lastHour;
  final List<WanDay> daily;

  const WanUsage({
    required this.available,
    this.error,
    this.stale = false,
    this.interfaceName,
    this.linkRunning = false,
    this.current,
    this.router,
    this.sinceBoot,
    this.today = const WanPeriod(),
    this.month = const WanPeriod(),
    this.trackingSince,
    this.live = const [],
    this.lastHour = const [],
    this.daily = const [],
  });

  factory WanUsage.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) =>
        ((j[key] as List?) ?? const []).map((e) => parse(Map<String, dynamic>.from(e as Map))).toList();
    Map<String, dynamic>? map(Map<String, dynamic> source, String key) =>
        source[key] is Map ? Map<String, dynamic>.from(source[key] as Map) : null;

    final usage = map(j, 'usage') ?? const <String, dynamic>{};
    final current = map(j, 'current');
    final router = map(j, 'router');
    final sinceBoot = map(j, 'since_boot');
    final today = map(usage, 'today');
    final month = map(usage, 'month');
    final error = j['error'] as String?;

    return WanUsage(
      available: j['available'] as bool? ?? false,
      error: (error == null || error.isEmpty) ? null : error,
      stale: j['stale'] as bool? ?? false,
      interfaceName: j['interface'] as String?,
      linkRunning: j['link_running'] as bool? ?? false,
      current: current == null ? null : WanSpeed.fromJson(current),
      router: router == null ? null : WanRouter.fromJson(router),
      sinceBoot: sinceBoot == null ? null : WanSinceBoot.fromJson(sinceBoot),
      today: today == null ? const WanPeriod() : WanPeriod.fromJson(today),
      month: month == null ? const WanPeriod() : WanPeriod.fromJson(month),
      trackingSince: _date(j['tracking_since']),
      live: list('live', WanPoint.fromJson),
      lastHour: list('last_hour', WanPoint.fromJson),
      daily: list('daily', WanDay.fromJson),
    );
  }
}

class WanSpeed {
  final int downloadBps;
  final int uploadBps;
  final DateTime? updatedAt;
  const WanSpeed({required this.downloadBps, required this.uploadBps, this.updatedAt});

  factory WanSpeed.fromJson(Map<String, dynamic> j) => WanSpeed(
        downloadBps: _int(j['download_bps']),
        uploadBps: _int(j['upload_bps']),
        updatedAt: _date(j['updated_at']),
      );
}

class WanPeriod {
  final int downloadBytes;
  final int uploadBytes;
  final int peakDownloadBps;
  final int peakUploadBps;
  const WanPeriod({this.downloadBytes = 0, this.uploadBytes = 0, this.peakDownloadBps = 0, this.peakUploadBps = 0});

  int get totalBytes => downloadBytes + uploadBytes;

  factory WanPeriod.fromJson(Map<String, dynamic> j) => WanPeriod(
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
        peakDownloadBps: _int(j['peak_download_bps']),
        peakUploadBps: _int(j['peak_upload_bps']),
      );
}

class WanSinceBoot {
  final int downloadBytes;
  final int uploadBytes;
  final int uptimeSeconds;
  const WanSinceBoot({required this.downloadBytes, required this.uploadBytes, required this.uptimeSeconds});

  int get totalBytes => downloadBytes + uploadBytes;

  factory WanSinceBoot.fromJson(Map<String, dynamic> j) => WanSinceBoot(
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
        uptimeSeconds: _int(j['uptime_seconds']),
      );
}

class WanRouter {
  final String board;
  final String version;
  final int cpuLoadPercent;
  final double memoryUsedPercent;
  final int uptimeSeconds;
  const WanRouter({
    required this.board,
    required this.version,
    required this.cpuLoadPercent,
    required this.memoryUsedPercent,
    required this.uptimeSeconds,
  });

  factory WanRouter.fromJson(Map<String, dynamic> j) => WanRouter(
        board: j['board'] as String? ?? '',
        version: j['version'] as String? ?? '',
        cpuLoadPercent: _int(j['cpu_load_percent']),
        memoryUsedPercent: _double(j['memory_used_percent']),
        uptimeSeconds: _int(j['uptime_seconds']),
      );
}

class WanPoint {
  final DateTime at;
  final int downloadBps;
  final int uploadBps;
  const WanPoint({required this.at, required this.downloadBps, required this.uploadBps});

  factory WanPoint.fromJson(Map<String, dynamic> j) => WanPoint(
        at: _date(j['at']) ?? DateTime.now(),
        downloadBps: _int(j['download_bps']),
        uploadBps: _int(j['upload_bps']),
      );
}

class WanDay {
  final DateTime day;
  final int downloadBytes;
  final int uploadBytes;
  const WanDay({required this.day, required this.downloadBytes, required this.uploadBytes});

  int get totalBytes => downloadBytes + uploadBytes;

  factory WanDay.fromJson(Map<String, dynamic> j) => WanDay(
        day: _date(j['day']) ?? DateTime.now(),
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
      );
}
