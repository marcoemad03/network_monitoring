import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/datasources/remote/security_remote_datasource.dart';
import 'package:network_monitorong/data/models/security_models.dart';
import 'package:network_monitorong/data/models/sites_models.dart';
import 'package:network_monitorong/presentation/providers/sites/sites_provider.dart';
import 'package:network_monitorong/presentation/providers/security/security_provider.dart';
import 'package:network_monitorong/presentation/screens/security/security_screen.dart';

SecurityFinding _finding(Severity s, String title, {String device = 'Reception PC', String ip = '172.16.0.9'}) => SecurityFinding(
      severity: s,
      code: 'code',
      title: title,
      detail: 'Contacting many hosts on the same sensitive port is what a scanner does.',
      action: 'Isolate the device and scan it for malware.',
      mac: 'AA:BB:CC:00:00:09',
      ip: ip,
      device: device,
    );

SecurityOverview _overview({
  bool scanned = true,
  List<SecurityFinding>? findings,
  ScanSettings settings = const ScanSettings(platformsFromRouter: ['youtube']),
  DateTime? monitoringSince,
  bool restored = false,
}) {
  final f = findings ??
      [
        _finding(Severity.high, 'Reaching 80 different internet hosts on Windows file sharing (SMB) (port 445)'),
        _finding(Severity.medium, 'WireGuard VPN tunnel to the internet', device: 'Dr Sara phone', ip: '172.16.0.6'),
      ];
  return SecurityOverview(
    scanned: scanned,
    scan: scanned ? ScanMeta(takenAt: DateTime.now().subtract(const Duration(minutes: 3)), durationMs: 8200, connections: 3009, routerCpuBefore: 57, routerCpuAfter: 100, restored: restored) : null,
    settings: settings,
    devices: 2,
    connections: scanned ? 3009 : 0,
    high: f.where((x) => x.severity == Severity.high).length,
    medium: f.where((x) => x.severity == Severity.medium).length,
    newDeviceCount: 1,
    findings: scanned ? f : const [],
    deviceList: scanned
        ? [
            const DeviceActivity(
              mac: 'AA:BB:CC:00:00:09',
              ip: '172.16.0.9',
              name: 'Reception PC',
              kind: 'computer',
              connections: 80,
              downloadBytes: 1200000,
              uploadBytes: 40000,
              destinations: 80,
              high: 1,
              top: [DestinationUse(name: 'Other hosts', kind: LabelKind.other, connections: 80)],
            ),
            const DeviceActivity(
              mac: 'AA:BB:CC:00:00:06',
              ip: '172.16.0.6',
              name: 'Dr Sara phone',
              kind: 'phone',
              connections: 120,
              downloadBytes: 98000000,
              uploadBytes: 3000000,
              destinations: 14,
              medium: 1,
              top: [
                DestinationUse(name: 'YouTube', kind: LabelKind.platform, connections: 6, downloadBytes: 90000000),
                DestinationUse(name: 'Google push notifications', kind: LabelKind.app, connections: 2),
              ],
            ),
          ]
        : const [],
    topByData: scanned
        ? const [
            DestinationUse(name: 'YouTube', kind: LabelKind.platform, connections: 40, devices: 9, downloadBytes: 500000000, uploadBytes: 4000000),
            DestinationUse(name: 'Amazon CloudFront', kind: LabelKind.provider, connections: 12, devices: 4, downloadBytes: 90000000),
          ]
        : const [],
    topByDevices: scanned ? const [DestinationUse(name: 'Meta (Facebook, Instagram, WhatsApp)', kind: LabelKind.provider, connections: 90, devices: 31, downloadBytes: 1000000)] : const [],
    popular: scanned ? const [PopularDestination(label: 'YouTube', kind: LabelKind.platform, devices: 22, scans: 5)] : const [],
    newDevices: const [NewDevice(mac: 'AA:BB:CC:00:00:77', ip: '172.16.0.77', name: 'Unknown phone', kind: 'phone', vendor: 'Samsung', online: true)],
    monitoringSince: monitoringSince ?? DateTime.now().subtract(const Duration(days: 3)),
  );
}

class _FakeSecurity extends SecurityController {
  _FakeSecurity(this._initial);

  final SecurityState _initial;
  int scans = 0;

  @override
  SecurityState build() => _initial;

  @override
  Future<void> refresh() async {}

  @override
  Future<void> scan() async {
    scans++;
  }
}

DeviceDetail _detail() => DeviceDetail(
      device: const DeviceActivity(
        mac: 'AA:BB:CC:00:00:06',
        ip: '172.16.0.6',
        name: 'Dr Sara phone',
        kind: 'phone',
        connections: 120,
        downloadBytes: 98000000,
        uploadBytes: 3000000,
        destinations: 14,
        top: [DestinationUse(name: 'YouTube', kind: LabelKind.platform, connections: 6, downloadBytes: 90000000)],
        flows: [FlowLine(protocol: 'tcp', destination: '142.250.185.78', port: 443, label: 'YouTube', kind: LabelKind.platform, downloadBytes: 90000000, uploadBytes: 100000)],
        medium: 1,
      ),
      history: const [PopularDestination(label: 'YouTube', kind: LabelKind.platform, devices: 1, scans: 4)],
      scan: ScanMeta(takenAt: DateTime.now().subtract(const Duration(minutes: 3)), connections: 3009),
    );

Future<_FakeSecurity> _pump(WidgetTester tester, SecurityState state, {Size size = const Size(1400, 2600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late _FakeSecurity fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        securityProvider.overrideWith(() => fake = _FakeSecurity(state)),
        securityDeviceProvider.overrideWith((ref, key) async => _detail()),
        deviceSitesProvider.overrideWith((ref, key) async => const DeviceSites(name: 'x')),
        siteLogoProvider.overrideWith((ref, domain) async => null),
      ],
      child: const MaterialApp(home: SecurityScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return fake;
}

void main() {
  group('before the first scan', () {
    testWidgets('explains what a scan is and what it costs, and offers to run it', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(scanned: false), loading: false));

      expect(find.text('No scan has been taken yet'), findsOneWidget);
      expect(find.textContaining('loads the router'), findsOneWidget);
      expect(find.text('Run the first scan'), findsOneWidget);
      expect(find.text('No scan yet'), findsOneWidget);
      expect(find.text('What is recorded, and who can see it'), findsOneWidget);
    });

    testWidgets('asks before touching the router, and Cancel does nothing', (tester) async {
      final fake = await _pump(tester, SecurityState(overview: _overview(scanned: false), loading: false));

      await tester.tap(find.text('Run the first scan'));
      await tester.pumpAndSettle();

      expect(find.text('Scan the network now?'), findsOneWidget);
      expect(find.textContaining('CPU can climb to 100%'), findsOneWidget);
      expect(find.textContaining('nothing on the router changes'), findsOneWidget);
      expect(find.textContaining('above 85% CPU'), findsWidgets); // the dialog and the privacy card

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(fake.scans, 0);
    });

    testWidgets('confirming starts exactly one scan', (tester) async {
      final fake = await _pump(tester, SecurityState(overview: _overview(scanned: false), loading: false));

      await tester.tap(find.text('Run the first scan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Scan now').last);
      await tester.pumpAndSettle();

      expect(fake.scans, 1);
    });
  });

  group('after a scan', () {
    testWidgets('shows findings worst first, with what to do', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false));

      expect(find.text('High'), findsWidgets);
      expect(find.textContaining('Reaching 80 different internet hosts'), findsOneWidget);
      expect(find.text('WireGuard VPN tunnel to the internet'), findsOneWidget);
      expect(find.text('Isolate the device and scan it for malware.'), findsWidgets);
      expect(find.text('High findings'), findsOneWidget);
      expect(find.text('Last scan 3m ago'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ranks destinations and says when platforms are only known by their provider', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(settings: const ScanSettings()), loading: false));

      expect(find.text('Most data right now'), findsOneWidget);
      expect(find.text('YouTube'), findsWidgets);
      expect(find.text('Amazon CloudFront'), findsOneWidget);
      expect(find.text('Used by the most devices'), findsOneWidget);
      expect(find.textContaining('ROUTER_SCAN_PLATFORM_LISTS'), findsOneWidget);
    });

    testWidgets('a clean scan says so', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(findings: const []), loading: false));

      expect(find.text('Nothing unusual in the last scan'), findsOneWidget);
    });

    testWidgets('lists the devices and the flagged-only filter narrows them', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false));

      expect(find.text('Reception PC'), findsWidgets);
      expect(find.text('Dr Sara phone'), findsWidgets);

      await tester.tap(find.text('Flagged only'));
      await tester.pump();
      expect(find.text('Reception PC'), findsWidgets);

      await tester.enterText(find.byType(TextField).first, 'youtube');
      await tester.pump();
      expect(find.text('No device matches'), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'nothing-like-this');
      await tester.pump();
      expect(find.text('No device matches'), findsOneWidget);
    });

    testWidgets('searching by destination finds the devices using it', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false));

      await tester.enterText(find.byType(TextField).first, 'youtube');
      await tester.pump();
      expect(find.text('Dr Sara phone'), findsWidgets);
    });

    testWidgets('opening a device shows what it has open right now and its connections', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false));

      await tester.tap(find.text('Dr Sara phone').first);
      await tester.pumpAndSettle();

      expect(find.text('Open right now'), findsOneWidget);
      expect(find.text('Busiest connections'), findsOneWidget);
      expect(find.textContaining('TCP 142.250.185.78:443'), findsOneWidget);
      expect(find.text('Seen over the last 7 days'), findsOneWidget);
      expect(find.textContaining('written to the audit log'), findsWidgets); // the dialog and the privacy card
    });

    testWidgets('does not call "new" devices new during the first day of recording', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(monitoringSince: DateTime.now().subtract(const Duration(hours: 2))), loading: false));

      expect(find.text('Devices recorded so far'), findsOneWidget);
      expect(find.text('Meaningful after the first day'), findsOneWidget);
    });

    testWidgets('after a day, new devices are listed as new', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false));

      expect(find.text('New devices in the last 24 hours'), findsOneWidget);
      expect(find.text('Unknown phone'), findsOneWidget);
    });

    testWidgets('a scan restored after a restart is labelled as such', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(restored: true), loading: false));

      expect(find.textContaining('restored after a restart'), findsWidgets);
    });

    for (final size in const [Size(1500, 2600), Size(900, 3000), Size(420, 5200)]) {
      testWidgets('lays out at ${size.width.toInt()}px without overflow', (tester) async {
        await _pump(tester, SecurityState(overview: _overview(), loading: false), size: size);
        expect(find.text('Findings'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('the scan button and refusals', () {
    testWidgets('is disabled while a scan runs', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false, scanning: true));

      expect(find.text('Scanning…'), findsWidgets);
      final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull);
    });

    testWidgets('waits out the cooldown and says how long', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(settings: const ScanSettings(cooldownSeconds: 200)), loading: false));

      expect(find.text('Again in 4 min'), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton).first);
      expect(button.onPressed, isNull);
    });

    testWidgets('a busy router is explained, not hidden', (tester) async {
      await _pump(
        tester,
        SecurityState(
          overview: _overview(),
          loading: false,
          scanProblem: const ScanRefused('ROUTER_BUSY', 'The router is at 92% CPU (limit 85%). Scanning now could slow the network down.'),
        ),
      );

      expect(find.text('The scan did not start'), findsOneWidget);
      expect(find.textContaining('92% CPU'), findsOneWidget);
    });

    testWidgets('a failed scan shows the reason', (tester) async {
      await _pump(tester, SecurityState(overview: _overview(), loading: false, scanProblem: const ScanRefused('ROUTER_ERROR', 'router unreachable: i/o timeout')));

      expect(find.text('The scan failed'), findsOneWidget);
      expect(find.textContaining('i/o timeout'), findsOneWidget);
    });
  });

  group('loading and errors', () {
    testWidgets('shows placeholders while loading', (tester) async {
      await _pump(tester, const SecurityState());
      expect(find.text('Connecting…'), findsOneWidget);
    });

    testWidgets('says when the server cannot be reached', (tester) async {
      await _pump(tester, const SecurityState(loading: false, fetchError: 'The NMS server is not reachable.'));
      expect(find.text('The security overview could not be loaded'), findsOneWidget);
      expect(find.text('Server unreachable'), findsOneWidget);
    });
  });

  test('the overview parses what the server sends', () {
    final overview = SecurityOverview.fromJson({
      'scanned': true,
      'scan': {'taken_at': '2026-11-01T16:00:00+02:00', 'duration_ms': 8168, 'connections': 3009, 'router_cpu_before': 57, 'router_cpu_after': 100, 'restored': false},
      'settings': {'scanning': false, 'cooldown_seconds': 120, 'auto_interval_seconds': 0, 'max_router_cpu': 85, 'retention_days': 30, 'platforms_from_router': ['youtube']},
      'summary': {'devices': 2, 'connections': 3009, 'findings_high': 1, 'findings_medium': 0, 'new_devices': 3},
      'findings': [
        {'severity': 'high', 'code': 'tor', 'title': 'Tor traffic', 'detail': 'd', 'action': 'a', 'mac': 'AA', 'ip': '172.16.0.1', 'device': 'PC'}
      ],
      'devices': [
        {'mac': 'AA', 'ip': '172.16.0.1', 'name': 'PC', 'kind': 'computer', 'connections': 5, 'download_bytes': 10, 'upload_bytes': 2, 'destinations': 2, 'top': [], 'findings_high': 1, 'findings_medium': 0}
      ],
      'top_by_data': [
        {'name': 'YouTube', 'kind': 'platform', 'connections': 3, 'devices': 2, 'download_bytes': 100, 'upload_bytes': 5}
      ],
      'top_by_devices': [],
      'popular_7d': [
        {'label': 'YouTube', 'kind': 'platform', 'devices': 2, 'scans': 4, 'connections': 9, 'bytes': 105}
      ],
      'new_devices': [],
      'monitoring_since': '2026-10-20T10:00:00+02:00',
    });
    expect(overview.scanned, isTrue);
    expect(overview.scan!.durationMs, 8168);
    expect(overview.findings.single.severity, Severity.high);
    expect(overview.findings.single.deviceKey, 'AA');
    expect(overview.deviceList.single.flagged, isTrue);
    expect(overview.topByData.single.kind, LabelKind.platform);
    expect(overview.topByData.single.totalBytes, 105);
    expect(overview.newDevicesMeaningful, isTrue);
    expect(overview.settings.platformsFromRouter, ['youtube']);
  });
}
