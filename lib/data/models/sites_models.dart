int _int(Object? v) => (v as num?)?.toInt() ?? 0;
DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) parse) =>
    ((v as List?) ?? const [])
        .map((e) => parse(Map<String, dynamic>.from(e as Map)))
        .toList();

/// Categories a site can have. The server owns the list; this gives each a name
/// and keeps the order the server sends.
String categoryLabel(String c) => switch (c) {
  'insurance' => 'Insurance',
  'health' => 'Health',
  'government' => 'Government',
  'banking' => 'Banking',
  'social' => 'Social media',
  'video' => 'Video',
  'messaging' => 'Messaging',
  'search' => 'Search',
  'email' => 'Email',
  'work' => 'Work tools',
  'cloud' => 'Cloud storage',
  'shopping' => 'Shopping',
  'news' => 'News',
  'ai' => 'AI tools',
  'games' => 'Games',
  'background' => 'Background services',
  _ => 'Other',
};

/// One site (or one organisation with several domains) and how much it was used.
class SiteUse {
  final String key;
  final String name;
  final String category;
  final List<String> domains;
  final bool named;
  final bool builtIn;
  final String catalogId;
  final bool hasLogo;
  final int queries;
  final int blocked;
  final int devices;
  final DateTime? lastSeen;

  const SiteUse({
    required this.key,
    required this.name,
    this.category = 'other',
    this.domains = const [],
    this.named = false,
    this.builtIn = false,
    this.catalogId = '',
    this.hasLogo = false,
    this.queries = 0,
    this.blocked = 0,
    this.devices = 0,
    this.lastSeen,
  });

  /// Shown under the name: the domain(s) behind it, unless the name is the domain.
  String get domainText =>
      domains.where((d) => d != name).take(3).join('  ·  ');

  factory SiteUse.fromJson(Map<String, dynamic> j) => SiteUse(
    key: j['key'] as String? ?? '',
    name: j['name'] as String? ?? '',
    category: j['category'] as String? ?? 'other',
    domains: ((j['domains'] as List?) ?? const []).map((e) => '$e').toList(),
    named: j['named'] as bool? ?? false,
    builtIn: j['built_in'] as bool? ?? false,
    catalogId: j['catalog_id'] as String? ?? '',
    hasLogo: j['has_logo'] as bool? ?? false,
    queries: _int(j['queries']),
    blocked: _int(j['blocked']),
    devices: _int(j['devices']),
    lastSeen: _date(j['last_seen']),
  );
}

/// A site the hospital named.
class CatalogEntry {
  final String id;
  final String name;
  final String category;
  final List<String> domains;
  final bool hasLogo;
  final String logoSource;

  const CatalogEntry({
    required this.id,
    required this.name,
    required this.category,
    required this.domains,
    this.hasLogo = false,
    this.logoSource = '',
  });

  factory CatalogEntry.fromJson(Map<String, dynamic> j) => CatalogEntry(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    category: j['category'] as String? ?? 'other',
    domains: ((j['domains'] as List?) ?? const []).map((e) => '$e').toList(),
    hasLogo: j['has_logo'] as bool? ?? false,
    logoSource: j['logo_source'] as String? ?? '',
  );
}

/// Whether a source of lookups (the router's or Pi-hole's log) is delivering.
class DnsSource {
  final String name;
  final bool enabled;
  final DateTime? lastEventAt;
  final int events;
  final String error;

  const DnsSource({
    required this.name,
    this.enabled = false,
    this.lastEventAt,
    this.events = 0,
    this.error = '',
  });

  String get title => switch (name) {
    'syslog' => 'Query log sent to the NMS server (syslog)',
    'pihole' => 'Pi-hole',
    _ => name,
  };

  factory DnsSource.fromJson(Map<String, dynamic> j) => DnsSource(
    name: j['name'] as String? ?? '',
    enabled: j['enabled'] as bool? ?? false,
    lastEventAt: _date(j['last_event_at']),
    events: _int(j['events']),
    error: j['error'] as String? ?? '',
  );
}

class SitesOverview {
  final bool recording;
  final List<DnsSource> sources;
  final int hours;
  final DateTime? firstRecordedAt;
  final DateTime? lastRecordedAt;
  final int queries;
  final int devices;
  final int retentionDays;
  final List<SiteUse> sites;
  final Map<String, int> byCategory;
  final int unnamed;
  final List<String> categories;
  final List<CatalogEntry> catalog;
  final int hiddenBackground;

  const SitesOverview({
    this.recording = false,
    this.sources = const [],
    this.hours = 24,
    this.firstRecordedAt,
    this.lastRecordedAt,
    this.queries = 0,
    this.devices = 0,
    this.retentionDays = 30,
    this.sites = const [],
    this.byCategory = const {},
    this.unnamed = 0,
    this.categories = const [],
    this.catalog = const [],
    this.hiddenBackground = 0,
  });

  bool get anySourceEnabled => sources.any((s) => s.enabled);

  factory SitesOverview.fromJson(Map<String, dynamic> j) => SitesOverview(
    recording: j['recording'] as bool? ?? false,
    sources: _list(j['sources'], DnsSource.fromJson),
    hours: _int(j['hours']),
    firstRecordedAt: _date(j['first_recorded_at']),
    lastRecordedAt: _date(j['last_recorded_at']),
    queries: _int(j['queries']),
    devices: _int(j['devices']),
    retentionDays: _int(j['retention_days']),
    sites: _list(j['sites'], SiteUse.fromJson),
    byCategory: {
      for (final e in ((j['sites_by_category'] as Map?) ?? const {}).entries)
        '${e.key}': _int(e.value),
    },
    unnamed: _int(j['unnamed_in_view']),
    categories:
        ((j['categories'] as List?) ?? const []).map((e) => '$e').toList(),
    catalog: _list(j['catalog'], CatalogEntry.fromJson),
    hiddenBackground: _int(((j['hidden'] as Map?) ?? const {})['background']),
  );
}

/// What one device asked for.
class DeviceSites {
  final String name;
  final String kind;
  final String ip;
  final String mac;
  final int hours;
  final List<SiteUse> sites;
  final int hiddenBackground;
  final bool recording;

  const DeviceSites({
    required this.name,
    this.kind = 'unknown',
    this.ip = '',
    this.mac = '',
    this.hours = 24,
    this.sites = const [],
    this.hiddenBackground = 0,
    this.recording = false,
  });

  factory DeviceSites.fromJson(Map<String, dynamic> j) => DeviceSites(
    name: j['name'] as String? ?? '',
    kind: j['kind'] as String? ?? 'unknown',
    ip: j['ip'] as String? ?? '',
    mac: j['mac'] as String? ?? '',
    hours: _int(j['hours']),
    sites: _list(j['sites'], SiteUse.fromJson),
    hiddenBackground: _int(j['hidden_background_queries']),
    recording: j['recording'] as bool? ?? false,
  );
}

class SiteDevice {
  final String mac;
  final String ip;
  final String name;
  final String kind;
  final int queries;
  final int blocked;
  final DateTime? lastSeen;

  const SiteDevice({
    required this.name,
    this.mac = '',
    this.ip = '',
    this.kind = 'unknown',
    this.queries = 0,
    this.blocked = 0,
    this.lastSeen,
  });

  String get key => mac.isNotEmpty ? mac : ip;

  factory SiteDevice.fromJson(Map<String, dynamic> j) => SiteDevice(
    mac: j['mac'] as String? ?? '',
    ip: j['ip'] as String? ?? '',
    name: j['name'] as String? ?? '',
    kind: j['kind'] as String? ?? 'unknown',
    queries: _int(j['queries']),
    blocked: _int(j['blocked']),
    lastSeen: _date(j['last_seen']),
  );
}

/// A site and the devices that asked for it.
class SiteDetail {
  final SiteUse site;
  final List<SiteDevice> devices;
  final int hours;

  const SiteDetail({
    required this.site,
    this.devices = const [],
    this.hours = 24,
  });

  factory SiteDetail.fromJson(Map<String, dynamic> j) => SiteDetail(
    site: SiteUse.fromJson(Map<String, dynamic>.from(j['site'] as Map)),
    devices: _list(j['devices'], SiteDevice.fromJson),
    hours: _int(j['hours']),
  );
}
