class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.name,
    required this.ip,
    required this.mac,
    required this.kind,
    this.kindSource = 'detected',
    this.reason = '',
    this.confidence = '',
    this.brand = '',
    this.vendor = '',
    this.model = '',
    this.serial = '',
    this.pageCount,
    this.tonerPercent,
    this.place = '',
    this.note = '',
    this.online = false,
    this.lastSeen,
  });

  final String id;
  final String name;
  final String ip;
  final String mac;
  final String kind;
  final String kindSource; // manual | scan | detected
  final String reason;
  final String confidence;
  final String brand;
  final String vendor;
  final String model;
  final String serial;
  final int? pageCount;
  final int? tonerPercent;
  final String place;
  final String note;
  final bool online;
  final DateTime? lastSeen;

  bool get unsure => kindSource != 'manual' && (kind == 'unknown' || confidence == 'low' || confidence == 'none');

  factory InventoryItem.fromJson(Map<String, dynamic> j) => InventoryItem(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    ip: j['ip'] as String? ?? '',
    mac: j['mac'] as String? ?? '',
    kind: j['kind'] as String? ?? 'unknown',
    kindSource: j['kind_source'] as String? ?? 'detected',
    reason: j['reason'] as String? ?? '',
    confidence: j['confidence'] as String? ?? '',
    brand: j['brand'] as String? ?? '',
    vendor: j['vendor'] as String? ?? '',
    model: j['model'] as String? ?? '',
    serial: j['serial'] as String? ?? '',
    pageCount: (j['page_count'] as num?)?.toInt(),
    tonerPercent: (j['toner_percent'] as num?)?.toInt(),
    place: j['place'] as String? ?? '',
    note: j['note'] as String? ?? '',
    online: j['online'] as bool? ?? false,
    lastSeen: DateTime.tryParse(j['last_seen'] as String? ?? '')?.toLocal(),
  );
}

class InventoryCount {
  const InventoryCount(this.kind, this.total, this.online);
  final String kind;
  final int total;
  final int online;
}

class InventoryScanState {
  const InventoryScanState({this.running = false, this.done = 0, this.total = 0, this.finishedAt});
  final bool running;
  final int done;
  final int total;
  final DateTime? finishedAt;

  factory InventoryScanState.fromJson(Map<String, dynamic> j) => InventoryScanState(
    running: j['running'] as bool? ?? false,
    done: (j['done'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    finishedAt: DateTime.tryParse(j['finished_at'] as String? ?? '')?.toLocal(),
  );
}

class AssetInventory {
  const AssetInventory({
    this.items = const [],
    this.excluded = const [],
    this.counts = const [],
    this.total = 0,
    this.online = 0,
    this.needsReview = 0,
    this.scan = const InventoryScanState(),
  });

  final List<InventoryItem> items;
  final List<InventoryItem> excluded;
  final List<InventoryCount> counts;
  final int total;
  final int online;
  final int needsReview;
  final InventoryScanState scan;

  factory AssetInventory.fromJson(Map<String, dynamic> j) {
    List<InventoryItem> list(String key) => [for (final e in (j[key] as List? ?? const [])) InventoryItem.fromJson(Map<String, dynamic>.from(e as Map))];
    return AssetInventory(
      items: list('items'),
      excluded: list('excluded'),
      counts: [
        for (final e in (j['counts'] as List? ?? const []))
          InventoryCount((e as Map)['kind'] as String? ?? 'unknown', (e['total'] as num?)?.toInt() ?? 0, (e['online'] as num?)?.toInt() ?? 0),
      ],
      total: (j['total'] as num?)?.toInt() ?? 0,
      online: (j['online'] as num?)?.toInt() ?? 0,
      needsReview: (j['needs_review'] as num?)?.toInt() ?? 0,
      scan: InventoryScanState.fromJson(Map<String, dynamic>.from(j['scan'] as Map? ?? const {})),
    );
  }
}
