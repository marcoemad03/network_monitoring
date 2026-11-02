int _int(Object? v) => (v as num?)?.toInt() ?? 0;
double? _dbl(Object? v) => (v as num?)?.toDouble();
String _str(Object? v) => v is String ? v : '';
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<Map<String, dynamic>> _rows(Object? v) =>
    ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

class ReportPeriod {
  final DateTime from;
  final DateTime to; // last day included
  final int days;
  const ReportPeriod({required this.from, required this.to, required this.days});

  factory ReportPeriod.fromJson(Map<String, dynamic> j) => ReportPeriod(
    from: DateTime.tryParse(_str(j['from'])) ?? DateTime.now(),
    to: DateTime.tryParse(_str(j['to'])) ?? DateTime.now(),
    days: _int(j['days']),
  );
}

class ReportCoverage {
  final bool noData;
  final bool partial;
  final DateTime? wanSince;
  final DateTime? devicesSince;
  final String note;
  const ReportCoverage({this.noData = false, this.partial = false, this.wanSince, this.devicesSince, this.note = ''});

  factory ReportCoverage.fromJson(Map<String, dynamic> j) => ReportCoverage(
    noData: j['no_data'] as bool? ?? false,
    partial: j['partial'] as bool? ?? false,
    wanSince: _date(j['wan_since']),
    devicesSince: _date(j['devices_since']),
    note: _str(j['note']),
  );
}

class ReportTotals {
  final int wanDown, wanUp, wanTotal;
  final int deviceDown, deviceUp, deviceTotal;
  final int activeDevices, newDevices, seenDevices;
  final int peakDownBps, peakUpBps;
  final int avgPerDay;
  final double? coveragePct;

  const ReportTotals({
    this.wanDown = 0,
    this.wanUp = 0,
    this.wanTotal = 0,
    this.deviceDown = 0,
    this.deviceUp = 0,
    this.deviceTotal = 0,
    this.activeDevices = 0,
    this.newDevices = 0,
    this.seenDevices = 0,
    this.peakDownBps = 0,
    this.peakUpBps = 0,
    this.avgPerDay = 0,
    this.coveragePct,
  });

  factory ReportTotals.fromJson(Map<String, dynamic> j) => ReportTotals(
    wanDown: _int(j['wan_download_bytes']),
    wanUp: _int(j['wan_upload_bytes']),
    wanTotal: _int(j['wan_total_bytes']),
    deviceDown: _int(j['device_download_bytes']),
    deviceUp: _int(j['device_upload_bytes']),
    deviceTotal: _int(j['device_total_bytes']),
    activeDevices: _int(j['active_devices']),
    newDevices: _int(j['new_devices']),
    seenDevices: _int(j['seen_devices']),
    peakDownBps: _int(j['peak_download_bps']),
    peakUpBps: _int(j['peak_upload_bps']),
    avgPerDay: _int(j['avg_bytes_per_day']),
    coveragePct: _dbl(j['device_coverage_pct']),
  );
}

class ReportCompare {
  final ReportPeriod previous;
  final int wanTotalPrev;
  final int deviceTotalPrev;
  final double? wanChangePct;
  final double? deviceChangePct;
  const ReportCompare({required this.previous, this.wanTotalPrev = 0, this.deviceTotalPrev = 0, this.wanChangePct, this.deviceChangePct});

  factory ReportCompare.fromJson(Map<String, dynamic> j) => ReportCompare(
    previous: ReportPeriod.fromJson(Map<String, dynamic>.from((j['previous'] as Map?) ?? const {})),
    wanTotalPrev: _int(j['wan_total_bytes']),
    deviceTotalPrev: _int(j['device_total_bytes']),
    wanChangePct: _dbl(j['wan_change_pct']),
    deviceChangePct: _dbl(j['device_change_pct']),
  );
}

class DayPoint {
  final DateTime day;
  final int wanDown, wanUp, deviceDown, deviceUp, activeDevices;
  const DayPoint({required this.day, this.wanDown = 0, this.wanUp = 0, this.deviceDown = 0, this.deviceUp = 0, this.activeDevices = 0});

  int get wanTotal => wanDown + wanUp;

  factory DayPoint.fromJson(Map<String, dynamic> j) => DayPoint(
    day: DateTime.tryParse(_str(j['day'])) ?? DateTime.now(),
    wanDown: _int(j['wan_download_bytes']),
    wanUp: _int(j['wan_upload_bytes']),
    deviceDown: _int(j['device_download_bytes']),
    deviceUp: _int(j['device_upload_bytes']),
    activeDevices: _int(j['active_devices']),
  );
}

class HourPoint {
  final int hour;
  final int down, up, avgBps;
  const HourPoint({required this.hour, this.down = 0, this.up = 0, this.avgBps = 0});

  int get total => down + up;

  factory HourPoint.fromJson(Map<String, dynamic> j) =>
      HourPoint(hour: _int(j['hour']), down: _int(j['download_bytes']), up: _int(j['upload_bytes']), avgBps: _int(j['avg_bps']));
}

class ReportDevice {
  final int rank;
  final String mac, name, nameSource, ip, kind, place;
  final int down, up, total, activeDays;
  final double sharePct;
  final bool online;

  const ReportDevice({
    required this.rank,
    required this.mac,
    required this.name,
    this.nameSource = '',
    this.ip = '',
    this.kind = 'unknown',
    this.place = '',
    this.down = 0,
    this.up = 0,
    this.total = 0,
    this.activeDays = 0,
    this.sharePct = 0,
    this.online = false,
  });

  bool get unnamed => nameSource == 'ip' || nameSource == 'guess' || name == ip || name == mac;

  factory ReportDevice.fromJson(Map<String, dynamic> j) => ReportDevice(
    rank: _int(j['rank']),
    mac: _str(j['mac']),
    name: _str(j['name']),
    nameSource: _str(j['name_source']),
    ip: _str(j['ip']),
    kind: _str(j['kind']).isEmpty ? 'unknown' : _str(j['kind']),
    place: _str(j['place']),
    down: _int(j['download_bytes']),
    up: _int(j['upload_bytes']),
    total: _int(j['total_bytes']),
    activeDays: _int(j['active_days']),
    sharePct: _dbl(j['share_pct']) ?? 0,
    online: j['online'] as bool? ?? false,
  );
}

class ReportGroup {
  final String key;
  final int down, up, total, devices;
  final double sharePct;
  const ReportGroup({required this.key, this.down = 0, this.up = 0, this.total = 0, this.devices = 0, this.sharePct = 0});

  factory ReportGroup.fromJson(Map<String, dynamic> j) => ReportGroup(
    key: _str(j['key']),
    down: _int(j['download_bytes']),
    up: _int(j['upload_bytes']),
    total: _int(j['total_bytes']),
    devices: _int(j['devices']),
    sharePct: _dbl(j['share_pct']) ?? 0,
  );
}

class ReportAlerts {
  final int total, open;
  final Map<String, int> bySeverity;
  const ReportAlerts({this.total = 0, this.open = 0, this.bySeverity = const {}});

  factory ReportAlerts.fromJson(Map<String, dynamic> j) => ReportAlerts(
    total: _int(j['total']),
    open: _int(j['open']),
    bySeverity: {for (final e in ((j['by_severity'] as Map?) ?? const {}).entries) e.key as String: _int(e.value)},
  );
}

class ReportEvent {
  final String type;
  final int count;
  const ReportEvent({required this.type, required this.count});
}

class ReportSecurity {
  final DateTime takenAt;
  final int findings;
  final Map<String, int> bySeverity;
  const ReportSecurity({required this.takenAt, this.findings = 0, this.bySeverity = const {}});

  factory ReportSecurity.fromJson(Map<String, dynamic> j) => ReportSecurity(
    takenAt: _date(j['taken_at']) ?? DateTime.now(),
    findings: _int(j['findings']),
    bySeverity: {for (final e in ((j['by_severity'] as Map?) ?? const {}).entries) e.key as String: _int(e.value)},
  );
}

class ReportProjection {
  final int usedBytes, projectedBytes, daysElapsed, daysInMonth;
  const ReportProjection({this.usedBytes = 0, this.projectedBytes = 0, this.daysElapsed = 0, this.daysInMonth = 0});

  factory ReportProjection.fromJson(Map<String, dynamic> j) => ReportProjection(
    usedBytes: _int(j['used_bytes']),
    projectedBytes: _int(j['projected_bytes']),
    daysElapsed: _int(j['days_elapsed']),
    daysInMonth: _int(j['days_in_month']),
  );
}

class ReportInsight {
  final bool warning;
  final String text;
  const ReportInsight({required this.warning, required this.text});
}

/// The usage report of one period, as the server built it.
class UsageReport {
  final DateTime generatedAt;
  final ReportPeriod period;
  final ReportCoverage coverage;
  final ReportTotals totals;
  final ReportCompare compare;
  final List<DayPoint> daily;
  final List<HourPoint> hourly;
  final List<ReportDevice> topDevices;
  final int deviceCount;
  final List<ReportGroup> byKind;
  final List<ReportGroup> byPlace;
  final ReportAlerts alerts;
  final List<ReportEvent> events;
  final ReportSecurity? security;
  final ReportProjection? projection;
  final List<ReportInsight> insights;

  const UsageReport({
    required this.generatedAt,
    required this.period,
    required this.coverage,
    required this.totals,
    required this.compare,
    this.daily = const [],
    this.hourly = const [],
    this.topDevices = const [],
    this.deviceCount = 0,
    this.byKind = const [],
    this.byPlace = const [],
    this.alerts = const ReportAlerts(),
    this.events = const [],
    this.security,
    this.projection,
    this.insights = const [],
  });

  factory UsageReport.fromJson(Map<String, dynamic> j) => UsageReport(
    generatedAt: _date(j['generated_at']) ?? DateTime.now(),
    period: ReportPeriod.fromJson(Map<String, dynamic>.from((j['period'] as Map?) ?? const {})),
    coverage: ReportCoverage.fromJson(Map<String, dynamic>.from((j['coverage'] as Map?) ?? const {})),
    totals: ReportTotals.fromJson(Map<String, dynamic>.from((j['totals'] as Map?) ?? const {})),
    compare: ReportCompare.fromJson(Map<String, dynamic>.from((j['compare'] as Map?) ?? const {})),
    daily: _rows(j['daily']).map(DayPoint.fromJson).toList(),
    hourly: _rows(j['hourly']).map(HourPoint.fromJson).toList(),
    topDevices: _rows(j['top_devices']).map(ReportDevice.fromJson).toList(),
    deviceCount: _int(j['device_count']),
    byKind: _rows(j['by_kind']).map(ReportGroup.fromJson).toList(),
    byPlace: _rows(j['by_place']).map(ReportGroup.fromJson).toList(),
    alerts: ReportAlerts.fromJson(Map<String, dynamic>.from((j['alerts'] as Map?) ?? const {})),
    events: _rows(j['events']).map((e) => ReportEvent(type: _str(e['type']), count: _int(e['count']))).toList(),
    security: j['security'] is Map ? ReportSecurity.fromJson(Map<String, dynamic>.from(j['security'] as Map)) : null,
    projection: j['projection'] is Map ? ReportProjection.fromJson(Map<String, dynamic>.from(j['projection'] as Map)) : null,
    insights: _rows(j['insights']).map((e) => ReportInsight(warning: _str(e['level']) == 'warning', text: _str(e['text']))).toList(),
  );
}

/// A file the server produced for download.
class ReportFile {
  final String name;
  final List<int> bytes;
  const ReportFile(this.name, this.bytes);
}
