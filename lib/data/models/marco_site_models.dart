import 'marco_models.dart';

// Website blocking, device controls and group details.

int _i(Object? v) => (v as num?)?.toInt() ?? 0;
double? _d(Object? v) => (v as num?)?.toDouble();
String _s(Object? v) => v is String ? v : '';
DateTime? _t(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<Map<String, dynamic>> _list(Object? v) =>
    ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// A ready-made set of sites (games, social media...) a group can block in one tick.
class MarcoPack {
  final String key;
  final String label;
  final String description;
  final String icon;
  final List<String> platforms;
  final List<String> domains;

  const MarcoPack({required this.key, required this.label, this.description = '', this.icon = '', this.platforms = const [], this.domains = const []});

  int get siteCount => domains.length + platforms.length;

  factory MarcoPack.fromJson(Map<String, dynamic> j) => MarcoPack(
    key: _s(j['key']),
    label: _s(j['label']),
    description: _s(j['description']),
    icon: _s(j['icon']),
    platforms: ((j['platforms'] as List?) ?? const []).map((e) => '$e').toList(),
    domains: ((j['domains'] as List?) ?? const []).map((e) => '$e').toList(),
  );
}

class MarcoCatalog {
  final List<MarcoPlatform> platforms;
  final List<MarcoPack> packs;
  final List<String> allowedDefaults;
  final List<String> allowedCustom;

  const MarcoCatalog({this.platforms = const [], this.packs = const [], this.allowedDefaults = const [], this.allowedCustom = const []});

  factory MarcoCatalog.fromJson(Map<String, dynamic> j) {
    final allowed = Map<String, dynamic>.from((j['allowed'] as Map?) ?? const {});
    return MarcoCatalog(
      platforms: _list(j['platforms']).map(MarcoPlatform.fromJson).toList(),
      packs: _list(j['packs']).map(MarcoPack.fromJson).toList(),
      allowedDefaults: ((allowed['defaults'] as List?) ?? const []).map((e) => '$e').toList(),
      allowedCustom: ((allowed['custom'] as List?) ?? const []).map((e) => '$e').toList(),
    );
  }
}

/// What blocking one typed site would do.
class MarcoSiteCheck {
  final String target;
  final String kind;
  final List<String> ips;
  final List<String> shared;
  final String sharedProvider;
  final bool many;
  final String error;

  const MarcoSiteCheck({required this.target, this.kind = '', this.ips = const [], this.shared = const [], this.sharedProvider = '', this.many = false, this.error = ''});

  bool get blockable => ips.isNotEmpty;

  factory MarcoSiteCheck.fromJson(Map<String, dynamic> j) => MarcoSiteCheck(
    target: _s(j['target']),
    kind: _s(j['kind']),
    ips: ((j['ips'] as List?) ?? const []).map((e) => '$e').toList(),
    shared: ((j['shared'] as List?) ?? const []).map((e) => '$e').toList(),
    sharedProvider: _s(j['shared_provider']),
    many: j['many_addresses'] as bool? ?? false,
    error: _s(j['error']),
  );
}

/// A block or speed limit set on one device, whatever group it is in.
class MarcoDeviceControl {
  final String mac;
  final bool blocked;
  final double? downloadMbps;
  final double? uploadMbps;
  final String reason;

  const MarcoDeviceControl({required this.mac, this.blocked = false, this.downloadMbps, this.uploadMbps, this.reason = ''});

  bool get limited => downloadMbps != null || uploadMbps != null;

  factory MarcoDeviceControl.fromJson(Map<String, dynamic> j) => MarcoDeviceControl(
    mac: _s(j['mac']),
    blocked: j['blocked'] as bool? ?? false,
    downloadMbps: _d(j['download_limit_mbps']),
    uploadMbps: _d(j['upload_limit_mbps']),
    reason: _s(j['reason']),
  );
}

/// A device in a group with what the NMS knows about it.
class MarcoMemberDetail {
  final String deviceId;
  final String mac;
  final String name;
  final String kind;
  final String ip;
  final bool online;
  final String vendor;
  final int todayBytes;
  final int monthBytes;
  final int downloadBps;
  final int uploadBps;
  final String place;
  final DateTime? lastSeen;
  final MarcoDeviceControl? control;
  final bool enforced;
  final String notEnforcedReason;
  final DateTime? addedAt;

  const MarcoMemberDetail({
    required this.deviceId,
    required this.mac,
    required this.name,
    this.kind = 'unknown',
    this.ip = '',
    this.online = false,
    this.vendor = '',
    this.todayBytes = 0,
    this.monthBytes = 0,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.place = '',
    this.lastSeen,
    this.control,
    this.enforced = true,
    this.notEnforcedReason = '',
    this.addedAt,
  });

  factory MarcoMemberDetail.fromJson(Map<String, dynamic> j) => MarcoMemberDetail(
    deviceId: _s(j['device_id']),
    mac: _s(j['mac']),
    name: _s(j['name']),
    kind: _s(j['kind']).isEmpty ? 'unknown' : _s(j['kind']),
    ip: _s(j['ip']),
    online: j['online'] as bool? ?? false,
    vendor: _s(j['vendor']),
    todayBytes: _i(j['today_bytes']),
    monthBytes: _i(j['month_bytes']),
    downloadBps: _i(j['download_bps']),
    uploadBps: _i(j['upload_bps']),
    place: _s(j['place']),
    lastSeen: _t(j['last_seen']),
    control: j['control'] is Map ? MarcoDeviceControl.fromJson(Map<String, dynamic>.from(j['control'] as Map)) : null,
    enforced: j['enforced'] as bool? ?? true,
    notEnforcedReason: _s(j['not_enforced_reason']),
    addedAt: _t(j['added_at']),
  );
}

/// One blocked site, pack or platform and how well it can be blocked.
class MarcoSiteLine {
  final String target;
  final String kind; // platform | pack | domain | ip | cidr
  final String label;
  final String status; // blocked | partial | cannot | pending
  final String detail;
  final int addresses;

  const MarcoSiteLine({required this.target, required this.kind, required this.label, required this.status, this.detail = '', this.addresses = 0});

  factory MarcoSiteLine.fromJson(Map<String, dynamic> j) => MarcoSiteLine(
    target: _s(j['target']),
    kind: _s(j['kind']),
    label: _s(j['label']),
    status: _s(j['status']),
    detail: _s(j['detail']),
    addresses: _i(j['addresses']),
  );
}

/// Everything the group page shows.
class MarcoGroupDetails {
  final MarcoGroup group;
  final List<MarcoMemberDetail> members;
  final List<String> summary;
  final List<MarcoSiteLine> sites;
  final List<MarcoPolicyLog> logs;
  final bool dryRun;
  final int todayBytes;
  final int onlineCount;

  const MarcoGroupDetails({
    required this.group,
    this.members = const [],
    this.summary = const [],
    this.sites = const [],
    this.logs = const [],
    this.dryRun = false,
    this.todayBytes = 0,
    this.onlineCount = 0,
  });

  factory MarcoGroupDetails.fromJson(Map<String, dynamic> j) => MarcoGroupDetails(
    group: MarcoGroup.fromJson(Map<String, dynamic>.from(j['group'] as Map)),
    members: _list(j['members']).map(MarcoMemberDetail.fromJson).toList(),
    summary: ((j['summary'] as List?) ?? const []).map((e) => '$e').toList(),
    sites: _list(j['sites']).map(MarcoSiteLine.fromJson).toList(),
    logs: _list(j['logs']).map(MarcoPolicyLog.fromJson).toList(),
    dryRun: j['dry_run'] as bool? ?? false,
    todayBytes: _i(j['today_bytes']),
    onlineCount: _i(j['online_count']),
  );
}
