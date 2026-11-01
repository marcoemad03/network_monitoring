import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/datasources/remote/sites_remote_datasource.dart';
import 'package:network_monitorong/data/models/sites_models.dart';
import 'package:network_monitorong/presentation/providers/sites/sites_provider.dart';
import 'package:network_monitorong/presentation/screens/sites/sites_screen.dart';
import 'package:network_monitorong/presentation/screens/sites/widgets/device_sites.dart';

// A 1x1 PNG.
final Uint8List _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

DnsSource _source({DateTime? last, String error = ''}) =>
    DnsSource(name: 'pihole', enabled: true, lastEventAt: last, events: last == null ? 0 : 500, error: error);

SiteUse _insurer(String name, {int devices = 12, int queries = 340, bool logo = true, String domain = 'misr-insurance.com.eg'}) => SiteUse(
      key: domain,
      name: name,
      category: 'insurance',
      domains: [domain, 'portal.$domain'.replaceFirst('portal.', '')],
      named: true,
      catalogId: 'id-$domain',
      hasLogo: logo,
      queries: queries,
      devices: devices,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 4)),
    );

SitesOverview _overview({
  bool recording = true,
  List<DnsSource>? sources,
  List<SiteUse>? sites,
  int unnamed = 1,
}) {
  final list = sites ??
      [
        _insurer('Misr Insurance'),
        _insurer('Allianz Egypt', devices: 5, queries: 80, logo: false, domain: 'allianz.com.eg'),
        SiteUse(key: 'youtube.com', name: 'YouTube', category: 'video', domains: const ['youtube.com', 'ytimg.com'], builtIn: true, queries: 2400, devices: 30, blocked: 3, lastSeen: DateTime.now().subtract(const Duration(minutes: 1))),
        SiteUse(key: 'mystery-clinic.example', name: 'mystery-clinic.example', category: 'other', domains: const ['mystery-clinic.example'], queries: 9, devices: 1, lastSeen: DateTime.now().subtract(const Duration(hours: 2))),
      ];
  final byCategory = <String, int>{};
  for (final s in list) {
    byCategory[s.category] = (byCategory[s.category] ?? 0) + 1;
  }
  return SitesOverview(
    recording: recording,
    sources: sources ?? [_source(last: DateTime.now().subtract(const Duration(seconds: 20)))],
    hours: 24,
    firstRecordedAt: DateTime.now().subtract(const Duration(days: 3)),
    lastRecordedAt: DateTime.now(),
    queries: recording ? 3000 : 0,
    devices: recording ? 41 : 0,
    retentionDays: 30,
    sites: recording ? list : const [],
    byCategory: byCategory,
    unnamed: unnamed,
    hiddenBackground: recording ? 5200 : 0,
    catalog: const [CatalogEntry(id: 'id-misr-insurance.com.eg', name: 'Misr Insurance', category: 'insurance', domains: ['misr-insurance.com.eg'], hasLogo: true)],
  );
}

class _FakeSites extends SitesController {
  _FakeSites(this._initial);

  final SitesState _initial;
  final List<String> calls = [];
  bool lastBackground = false;

  @override
  SitesState build() => _initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> setHours(int hours) async {
    calls.add('hours:$hours');
    state = state.copyWith(hours: hours);
  }

  @override
  Future<void> setBackground(bool value) async {
    calls.add('background:$value');
    state = state.copyWith(background: value);
  }

  @override
  Future<CatalogResult> create({required String name, required String category, required List<String> domains, bool fetchLogo = true}) async {
    calls.add('create:$name|$category|${domains.join(",")}|$fetchLogo');
    if (name == 'Duplicate') throw const SitesRequestFailed('ALREADY_EXISTS', 'this domain is already in the catalog: x is listed under "Other"');
    return CatalogResult(CatalogEntry(id: 'new', name: name, category: category, domains: domains), name == 'NoIcon' ? 'the site does not publish a usable icon' : '');
  }

  @override
  Future<CatalogResult> adopt(String domain, {String name = '', String category = ''}) async {
    calls.add('adopt:$domain');
    return const CatalogResult(CatalogEntry(id: 'adopted', name: 'YouTube', category: 'video', domains: ['youtube.com']), '');
  }
}

SiteDetail _detail() => SiteDetail(
      site: _insurer('Misr Insurance'),
      hours: 24,
      devices: [
        SiteDevice(mac: 'AA:BB:CC:00:00:01', ip: '172.16.0.21', name: 'Billing PC 2', kind: 'computer', queries: 80, lastSeen: DateTime.now().subtract(const Duration(minutes: 4))),
        SiteDevice(mac: 'AA:BB:CC:00:00:02', ip: '172.16.0.34', name: 'Dr Sara phone', kind: 'phone', queries: 12, lastSeen: DateTime.now().subtract(const Duration(minutes: 30))),
      ],
    );

DeviceSites _deviceSites() => DeviceSites(
      name: 'Billing PC 2',
      kind: 'computer',
      ip: '172.16.0.21',
      mac: 'AA:BB:CC:00:00:01',
      recording: true,
      hiddenBackground: 120,
      sites: [_insurer('Misr Insurance', devices: 1, queries: 80), const SiteUse(key: 'youtube.com', name: 'YouTube', category: 'video', domains: ['youtube.com'], builtIn: true, queries: 4, devices: 1)],
    );

Future<_FakeSites> _pump(WidgetTester tester, SitesState state, {Size size = const Size(1400, 2000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late _FakeSites fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sitesProvider.overrideWith(() => fake = _FakeSites(state)),
        siteLogoProvider.overrideWith((ref, domain) async => domain.contains('allianz') ? null : _png),
        siteDetailProvider.overrideWith((ref, q) async => _detail()),
        deviceSitesProvider.overrideWith((ref, key) async => _deviceSites()),
      ],
      child: const MaterialApp(home: SitesScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return fake;
}

void main() {
  testWidgets('without a DNS source it explains what to set up', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview(recording: false, sources: const [DnsSource(name: 'pihole')])));
    expect(find.text('No DNS source is set up'), findsOneWidget);
    expect(find.text('Websites need the hospital\'s own DNS'), findsOneWidget);
    expect(find.textContaining('PIHOLE_URL'), findsOneWidget);
    expect(find.textContaining('DNS_SYSLOG_LISTEN'), findsOneWidget);
    expect(find.textContaining('docs/OPERATIONS.md'), findsOneWidget);
    expect(find.text('Misr Insurance'), findsNothing);
  });

  testWidgets('a source that has delivered nothing yet says it is waiting', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview(recording: false, sources: [_source()])));
    expect(find.text('Waiting for the first lookups'), findsOneWidget);
    expect(find.textContaining('Pi-hole: waiting for lookups'), findsOneWidget);
  });

  testWidgets('a source that fails shows why', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview(recording: false, sources: [_source(error: 'Pi-hole refused the password')])));
    expect(find.textContaining('Pi-hole refused the password'), findsOneWidget);
  });

  testWidgets('shows sites by name with their category, devices and naming state', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()));
    expect(find.text('Misr Insurance'), findsOneWidget);
    expect(find.text('Allianz Egypt'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.text('mystery-clinic.example'), findsOneWidget);
    expect(find.text('12 devices'), findsOneWidget);
    expect(find.text('1 device'), findsOneWidget);
    expect(find.text('Named'), findsNWidgets(2));
    expect(find.text('Common site'), findsOneWidget);
    expect(find.text('Not named yet'), findsOneWidget);
    expect(find.textContaining('3 blocked'), findsOneWidget);
    expect(find.textContaining('1 not named yet'), findsOneWidget);
  });

  testWidgets('draws the logo when the site has one and a fallback when not', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()));
    // Misr Insurance has a logo and gets an image; Allianz is marked without one.
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('insurance filter narrows the list and comes first', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()));
    final chips = tester.widgetList<ChoiceChip>(find.byType(ChoiceChip)).map((c) => (c.label as Text).data).toList();
    expect(chips.first, 'All (4)');
    expect(chips[1], 'Insurance (2)');

    await tester.tap(find.text('Insurance (2)'));
    await tester.pump();
    expect(find.text('Misr Insurance'), findsOneWidget);
    expect(find.text('YouTube'), findsNothing);

    await tester.tap(find.text('Insurance (2)')); // again clears it
    await tester.pump();
    expect(find.text('YouTube'), findsOneWidget);
  });

  testWidgets('search finds a site by name or domain', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.enterText(find.byType(TextField), 'allianz.com');
    await tester.pump();
    expect(find.text('Allianz Egypt'), findsOneWidget);
    expect(find.text('Misr Insurance'), findsNothing);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await tester.pump();
    expect(find.text('No site matches'), findsOneWidget);
  });

  testWidgets('background switch and period are passed on', (tester) async {
    final fake = await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(fake.calls, contains('background:true'));

    await tester.tap(find.text('Last 24 hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 7 days'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('hours:168'));
  });

  testWidgets('opening a site lists the devices with phone or computer', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.tap(find.text('Misr Insurance'));
    await tester.pumpAndSettle();
    expect(find.text('Billing PC 2'), findsOneWidget);
    expect(find.text('Dr Sara phone'), findsOneWidget);
    expect(find.text('Computer'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
    expect(find.text('Edit name, category, domains'), findsOneWidget);
    expect(find.text('Get the logo again'), findsOneWidget);

    // From a device to everything it opened.
    await tester.tap(find.text('Billing PC 2'));
    await tester.pumpAndSettle();
    expect(find.text('Sites in the last 24 hours'), findsOneWidget);
    expect(find.textContaining('120 lookups of background services'), findsOneWidget);
  });

  testWidgets('a built-in site can be added to the catalog with one tap', (tester) async {
    final fake = await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.tap(find.text('YouTube'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to the catalog with its logo'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('adopt:youtube.com'));
    expect(find.text('Added to the catalog with its logo.'), findsOneWidget);
  });

  testWidgets('naming an unknown site asks for a name and domain', (tester) async {
    final fake = await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.tap(find.text('mystery-clinic.example'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Name this site'));
    await tester.pumpAndSettle();
    expect(find.text('Name a site'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.textContaining('Write the name'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('create')), isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Mystery Clinic');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('create:Mystery Clinic|insurance|mystery-clinic.example|true'));
  });

  testWidgets('add a site: the server refusing is shown, and a missing logo does not lose the save', (tester) async {
    final fake = await _pump(tester, SitesState(loading: false, overview: _overview()));
    await tester.tap(find.text('Add a site'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Duplicate');
    await tester.enterText(find.widgetWithText(TextField, 'Domains'), 'https://www.dup.com.eg/login');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already in the catalog'), findsOneWidget);
    expect(find.text('Name a site'), findsOneWidget); // still open, nothing lost

    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'NoIcon');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Saved. The logo could not be downloaded'), findsOneWidget);
    expect(fake.calls.where((c) => c.startsWith('create:NoIcon')), hasLength(1));
  });

  testWidgets('fits a narrow window without overflow', (tester) async {
    await _pump(tester, SitesState(loading: false, overview: _overview()), size: const Size(420, 1800));
    expect(tester.takeException(), isNull);
    expect(find.text('Misr Insurance'), findsOneWidget);
  });

  testWidgets('shows the server being unreachable', (tester) async {
    await _pump(tester, const SitesState(loading: false, fetchError: 'The NMS server is not reachable.'));
    expect(find.text('The recorded sites could not be loaded'), findsOneWidget);
    expect(find.text('The NMS server is not reachable.'), findsOneWidget);
  });

  testWidgets('device section names the sites a device opened', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        siteLogoProvider.overrideWith((ref, domain) async => _png),
        deviceSitesProvider.overrideWith((ref, key) async => _deviceSites()),
      ],
      child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: DeviceSitesSection(deviceKey: 'AA:BB:CC:00:00:01')))),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Misr Insurance'), findsOneWidget);
    expect(find.text('YouTube'), findsOneWidget);
    expect(find.textContaining('120 lookups of background services'), findsOneWidget);
  });
}

