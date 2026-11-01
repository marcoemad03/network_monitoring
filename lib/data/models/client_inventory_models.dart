int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// The kinds of device the inventory distinguishes, with the labels the UI uses.
enum ClientKind {
  phone('Phone'),
  tablet('Tablet'),
  computer('Computer'),
  printer('Printer'),
  camera('Camera'),
  tv('TV'),
  network('Network equipment'),
  server('Server'),
  iot('Smart device'),
  medical('Medical device'),
  unknown('Unknown');

  const ClientKind(this.label);
  final String label;

  static ClientKind parse(String? value) =>
      ClientKind.values.firstWhere((k) => k.name == value, orElse: () => ClientKind.unknown);
}

/// A device on the network as measured by the router, plus what people noted.
class ClientDevice {
  final String mac;
  final String ip;
  final String hostname;
  final String displayName;
  final String nameSource; // custom | hostname | guess | ip
  final ClientKind kind;
  final bool kindIsCustom;
  final String brand;
  final String vendor; // company the MAC address block is registered to
  final String confidence; // high | medium | low | none
  final String kindReason;
  final bool privateMac;
  final bool online;
  final String network;
  final bool authorized;
  final bool hasCounters;
  final String note;
  final String routerComment;
  final DateTime? firstSeen;
  final DateTime? lastSeen;
  final int uptimeSeconds;
  final int idleSeconds;
  final int downloadBps;
  final int uploadBps;
  final int sessionDownload;
  final int sessionUpload;
  final int todayDownload;
  final int todayUpload;
  final int monthDownload;
  final int monthUpload;

  const ClientDevice({
    required this.mac,
    this.ip = '',
    this.hostname = '',
    required this.displayName,
    this.nameSource = 'ip',
    this.kind = ClientKind.unknown,
    this.kindIsCustom = false,
    this.brand = '',
    this.vendor = '',
    this.confidence = 'none',
    this.kindReason = '',
    this.privateMac = false,
    this.online = false,
    this.network = '',
    this.authorized = false,
    this.hasCounters = false,
    this.note = '',
    this.routerComment = '',
    this.firstSeen,
    this.lastSeen,
    this.uptimeSeconds = 0,
    this.idleSeconds = 0,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.sessionDownload = 0,
    this.sessionUpload = 0,
    this.todayDownload = 0,
    this.todayUpload = 0,
    this.monthDownload = 0,
    this.monthUpload = 0,
  });

  int get todayTotal => todayDownload + todayUpload;
  int get monthTotal => monthDownload + monthUpload;
  int get currentBps => downloadBps + uploadBps;

  /// The comment to show: what was typed here, else what the router carries.
  String get comment => note.isNotEmpty ? note : routerComment;
  bool get commentIsFromRouter => note.isEmpty && routerComment.isNotEmpty;

  factory ClientDevice.fromJson(Map<String, dynamic> j) => ClientDevice(
        mac: j['mac'] as String? ?? '',
        ip: j['ip'] as String? ?? '',
        hostname: j['hostname'] as String? ?? '',
        displayName: j['display_name'] as String? ?? (j['ip'] as String? ?? ''),
        nameSource: j['name_source'] as String? ?? 'ip',
        kind: ClientKind.parse(j['kind'] as String?),
        kindIsCustom: j['kind_source'] == 'custom',
        brand: j['brand'] as String? ?? '',
        vendor: j['vendor'] as String? ?? '',
        confidence: j['confidence'] as String? ?? 'none',
        kindReason: j['kind_reason'] as String? ?? '',
        privateMac: j['private_mac'] as bool? ?? false,
        online: j['online'] as bool? ?? false,
        network: j['network'] as String? ?? '',
        authorized: j['authorized'] as bool? ?? false,
        hasCounters: j['has_counters'] as bool? ?? false,
        note: j['note'] as String? ?? '',
        routerComment: j['router_comment'] as String? ?? '',
        firstSeen: _date(j['first_seen']),
        lastSeen: _date(j['last_seen']),
        uptimeSeconds: _int(j['uptime_seconds']),
        idleSeconds: _int(j['idle_seconds']),
        downloadBps: _int(j['download_bps']),
        uploadBps: _int(j['upload_bps']),
        sessionDownload: _int(j['session_download_bytes']),
        sessionUpload: _int(j['session_upload_bytes']),
        todayDownload: _int(j['today_download_bytes']),
        todayUpload: _int(j['today_upload_bytes']),
        monthDownload: _int(j['month_download_bytes']),
        monthUpload: _int(j['month_upload_bytes']),
      );

  ClientDevice withNote({String? displayName, String? note, ClientKind? kind, bool? kindIsCustom}) => ClientDevice(
        mac: mac,
        ip: ip,
        hostname: hostname,
        displayName: displayName ?? this.displayName,
        nameSource: displayName != null ? 'custom' : nameSource,
        kind: kind ?? this.kind,
        kindIsCustom: kindIsCustom ?? this.kindIsCustom,
        brand: brand,
        vendor: vendor,
        confidence: confidence,
        kindReason: kindReason,
        privateMac: privateMac,
        online: online,
        network: network,
        authorized: authorized,
        hasCounters: hasCounters,
        note: note ?? this.note,
        routerComment: routerComment,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
        uptimeSeconds: uptimeSeconds,
        idleSeconds: idleSeconds,
        downloadBps: downloadBps,
        uploadBps: uploadBps,
        sessionDownload: sessionDownload,
        sessionUpload: sessionUpload,
        todayDownload: todayDownload,
        todayUpload: todayUpload,
        monthDownload: monthDownload,
        monthUpload: monthUpload,
      );
}

class ClientSummary {
  final int online;
  final int known;
  final Map<ClientKind, int> onlineByKind;
  final int downloadBps;
  final int uploadBps;
  final int todayDownload;
  final int todayUpload;

  const ClientSummary({
    this.online = 0,
    this.known = 0,
    this.onlineByKind = const {},
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.todayDownload = 0,
    this.todayUpload = 0,
  });

  factory ClientSummary.fromJson(Map<String, dynamic> j) => ClientSummary(
        online: _int(j['online']),
        known: _int(j['known']),
        onlineByKind: {
          for (final e in ((j['online_by_kind'] as Map?) ?? const {}).entries) ClientKind.parse(e.key as String): _int(e.value),
        },
        downloadBps: _int(j['download_bps']),
        uploadBps: _int(j['upload_bps']),
        todayDownload: _int(j['today_download_bytes']),
        todayUpload: _int(j['today_upload_bytes']),
      );
}

class ClientList {
  final bool available;
  final String? error;
  final bool stale;
  final DateTime? updatedAt;
  final ClientSummary summary;
  final List<ClientDevice> clients;

  const ClientList({
    required this.available,
    this.error,
    this.stale = false,
    this.updatedAt,
    this.summary = const ClientSummary(),
    this.clients = const [],
  });

  factory ClientList.fromJson(Map<String, dynamic> j) {
    final error = j['error'] as String?;
    return ClientList(
      available: j['available'] as bool? ?? false,
      error: (error == null || error.isEmpty) ? null : error,
      stale: j['stale'] as bool? ?? false,
      updatedAt: _date(j['updated_at']),
      summary: j['summary'] is Map ? ClientSummary.fromJson(Map<String, dynamic>.from(j['summary'] as Map)) : const ClientSummary(),
      clients: ((j['clients'] as List?) ?? const []).map((e) => ClientDevice.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

/// One day of a device's usage.
class ClientDay {
  final DateTime day;
  final int downloadBytes;
  final int uploadBytes;
  const ClientDay({required this.day, required this.downloadBytes, required this.uploadBytes});

  int get total => downloadBytes + uploadBytes;

  factory ClientDay.fromJson(Map<String, dynamic> j) => ClientDay(
        day: _date(j['day']) ?? DateTime.now(),
        downloadBytes: _int(j['download_bytes']),
        uploadBytes: _int(j['upload_bytes']),
      );
}
