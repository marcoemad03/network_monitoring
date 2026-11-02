int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
String _str(Object? v) => v is String ? v : '';

/// Where a device is: a name the user gave, the router's port label, or just the port.
enum PlaceSource { custom, portLabel, portComment, port, registered, none }

PlaceSource _placeSource(String v) => switch (v) {
  'custom' => PlaceSource.custom,
  'port_label' => PlaceSource.portLabel,
  'port_comment' => PlaceSource.portComment,
  'port' => PlaceSource.port,
  'registered' => PlaceSource.registered,
  _ => PlaceSource.none,
};

class MapWifi {
  final String interfaceName;
  final String signal;
  final String ssid;
  const MapWifi({required this.interfaceName, this.signal = '', this.ssid = ''});

  factory MapWifi.fromJson(Map<String, dynamic> j) => MapWifi(
    interfaceName: _str(j['interface']),
    signal: _str(j['signal']),
    ssid: _str(j['ssid']),
  );
}

/// One device on the map: a phone, a computer, a switch...
class MapDevice {
  final String id;
  final String source; // router | client | equipment | neighbor
  final String name;
  final String nameSource; // custom | hostname | guess | ip
  final String ip;
  final String mac;
  final String hostname;
  final String kind;
  final bool kindCustom;
  final String brand;
  final String vendor;
  final String model;
  final String confidence;
  final String kindReason;
  final bool online;
  final String status; // online | offline | degraded
  final String port;
  final String portSource;
  final String place;
  final PlaceSource placeSource;
  final MapWifi? wifi;
  final String network;
  final String note;
  final bool critical;
  final DateTime? lastSeen;
  final double? pingMs;
  final int downloadBps;
  final int uploadBps;
  final int todayBytes;
  final String registeredId;

  const MapDevice({
    required this.id,
    this.source = 'client',
    required this.name,
    this.nameSource = 'ip',
    this.ip = '',
    this.mac = '',
    this.hostname = '',
    this.kind = 'unknown',
    this.kindCustom = false,
    this.brand = '',
    this.vendor = '',
    this.model = '',
    this.confidence = 'none',
    this.kindReason = '',
    this.online = false,
    this.status = 'offline',
    this.port = '',
    this.portSource = 'none',
    this.place = '',
    this.placeSource = PlaceSource.none,
    this.wifi,
    this.network = '',
    this.note = '',
    this.critical = false,
    this.lastSeen,
    this.pingMs,
    this.downloadBps = 0,
    this.uploadBps = 0,
    this.todayBytes = 0,
    this.registeredId = '',
  });

  /// Only devices the router has seen by MAC address can be renamed or moved here.
  bool get editable => mac.isNotEmpty && source != 'router';
  bool get hasPlace => placeSource != PlaceSource.none && place.isNotEmpty;

  factory MapDevice.fromJson(Map<String, dynamic> j) => MapDevice(
    id: _str(j['id']),
    source: _str(j['source']).isEmpty ? 'client' : _str(j['source']),
    name: _str(j['name']),
    nameSource: _str(j['name_source']),
    ip: _str(j['ip']),
    mac: _str(j['mac']),
    hostname: _str(j['hostname']),
    kind: _str(j['kind']).isEmpty ? 'unknown' : _str(j['kind']),
    kindCustom: j['kind_custom'] as bool? ?? false,
    brand: _str(j['brand']),
    vendor: _str(j['vendor']),
    model: _str(j['model']),
    confidence: _str(j['confidence']),
    kindReason: _str(j['kind_reason']),
    online: j['online'] as bool? ?? false,
    status: _str(j['status']).isEmpty ? 'offline' : _str(j['status']),
    port: _str(j['port']),
    portSource: _str(j['port_source']),
    place: _str(j['place']),
    placeSource: _placeSource(_str(j['place_source'])),
    wifi: j['wifi'] is Map ? MapWifi.fromJson(Map<String, dynamic>.from(j['wifi'] as Map)) : null,
    network: _str(j['network']),
    note: _str(j['note']),
    critical: j['critical'] as bool? ?? false,
    lastSeen: _date(j['last_seen']),
    pingMs: (j['ping_ms'] as num?)?.toDouble(),
    downloadBps: _int(j['download_bps']),
    uploadBps: _int(j['upload_bps']),
    todayBytes: _int(j['today_bytes']),
    registeredId: _str(j['registered_id']),
  );
}

/// A router port and the devices behind it.
class MapPort {
  final String name;
  final String label;
  final String labelSource; // custom | comment | none
  final String comment;
  final String type;
  final bool running;
  final bool disabled;
  final bool physical;
  final bool trunk;
  final int rxBps;
  final int txBps;
  final int devices;
  final int online;

  const MapPort({
    required this.name,
    this.label = '',
    this.labelSource = 'none',
    this.comment = '',
    this.type = '',
    this.running = false,
    this.disabled = false,
    this.physical = true,
    this.trunk = false,
    this.rxBps = 0,
    this.txBps = 0,
    this.devices = 0,
    this.online = 0,
  });

  /// "ether5 · Emergency ward", or just the port name.
  String get title => label.isEmpty ? name : '$name · $label';

  factory MapPort.fromJson(Map<String, dynamic> j) => MapPort(
    name: _str(j['name']),
    label: _str(j['label']),
    labelSource: _str(j['label_source']),
    comment: _str(j['comment']),
    type: _str(j['type']),
    running: j['running'] as bool? ?? false,
    disabled: j['disabled'] as bool? ?? false,
    physical: j['physical'] as bool? ?? false,
    trunk: j['trunk'] as bool? ?? false,
    rxBps: _int(j['rx_bps']),
    txBps: _int(j['tx_bps']),
    devices: _int(j['devices']),
    online: _int(j['online']),
  );
}

class MapRouter {
  final String name;
  final String ip;
  final bool online;
  const MapRouter({this.name = 'Router', this.ip = '', this.online = false});

  factory MapRouter.fromJson(Map<String, dynamic> j) =>
      MapRouter(name: _str(j['name']).isEmpty ? 'Router' : _str(j['name']), ip: _str(j['ip']), online: j['online'] as bool? ?? false);
}

class MapSummary {
  final int total;
  final int online;
  final int offline;
  final int located;
  final int unplaced;
  final int unnamed;
  final Map<String, int> byKind;
  final Map<String, int> onlineByKind;

  const MapSummary({
    this.total = 0,
    this.online = 0,
    this.offline = 0,
    this.located = 0,
    this.unplaced = 0,
    this.unnamed = 0,
    this.byKind = const {},
    this.onlineByKind = const {},
  });

  static Map<String, int> _counts(Object? v) => {
    for (final e in ((v as Map?) ?? const {}).entries) e.key as String: _int(e.value),
  };

  factory MapSummary.fromJson(Map<String, dynamic> j) => MapSummary(
    total: _int(j['total']),
    online: _int(j['online']),
    offline: _int(j['offline']),
    located: _int(j['located']),
    unplaced: _int(j['unplaced']),
    unnamed: _int(j['unnamed']),
    byKind: _counts(j['by_kind']),
    onlineByKind: _counts(j['online_by_kind']),
  );
}

class NetworkMapData {
  final bool available;
  final String? error;
  final bool stale;
  final DateTime? updatedAt;
  final DateTime? topologyAt;
  final String? topologyError;
  final List<String> topologyNotes;
  final MapRouter router;
  final List<MapPort> ports;
  final List<MapDevice> devices;
  final MapSummary summary;

  const NetworkMapData({
    required this.available,
    this.error,
    this.stale = false,
    this.updatedAt,
    this.topologyAt,
    this.topologyError,
    this.topologyNotes = const [],
    this.router = const MapRouter(),
    this.ports = const [],
    this.devices = const [],
    this.summary = const MapSummary(),
  });

  MapPort? port(String name) {
    for (final p in ports) {
      if (p.name == name) return p;
    }
    return null;
  }

  factory NetworkMapData.fromJson(Map<String, dynamic> j) {
    String? opt(Object? v) => v is String && v.isNotEmpty ? v : null;
    List<Map<String, dynamic>> rows(Object? v) =>
        ((v as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return NetworkMapData(
      available: j['available'] as bool? ?? false,
      error: opt(j['error']),
      stale: j['stale'] as bool? ?? false,
      updatedAt: _date(j['updated_at']),
      topologyAt: _date(j['topology_at']),
      topologyError: opt(j['topology_error']),
      topologyNotes: ((j['topology_notes'] as List?) ?? const []).map((e) => e.toString()).toList(),
      router: j['router'] is Map ? MapRouter.fromJson(Map<String, dynamic>.from(j['router'] as Map)) : const MapRouter(),
      ports: rows(j['ports']).map(MapPort.fromJson).toList(),
      devices: rows(j['devices']).map(MapDevice.fromJson).toList(),
      summary: j['summary'] is Map ? MapSummary.fromJson(Map<String, dynamic>.from(j['summary'] as Map)) : const MapSummary(),
    );
  }
}
