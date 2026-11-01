import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/models/wan_usage_models.dart';
import 'package:network_monitorong/domain/entities/dashboard_live.dart';
import 'package:network_monitorong/presentation/providers/dashboard/wan_provider.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/screens/dashboard/dashboard_screen.dart';

WanUsage _usage({bool stale = false, String? error, bool available = true}) {
  final now = DateTime.now();
  return WanUsage(
    available: available,
    stale: stale,
    error: error,
    interfaceName: 'ether2',
    linkRunning: true,
    current: WanSpeed(downloadBps: 19300000, uploadBps: 1750000, updatedAt: now.subtract(const Duration(seconds: 3))),
    router: const WanRouter(board: 'RB2011UiAS', version: '6.49.23 (stable)', cpuLoadPercent: 46, memoryUsedPercent: 31.2, uptimeSeconds: 606683),
    sinceBoot: const WanSinceBoot(downloadBytes: 410000000000, uploadBytes: 52000000000, uptimeSeconds: 606683),
    today: const WanPeriod(downloadBytes: 2400000000, uploadBytes: 240000000, peakDownloadBps: 48000000, peakUploadBps: 4000000),
    month: const WanPeriod(downloadBytes: 61000000000, uploadBytes: 5200000000, peakDownloadBps: 90000000, peakUploadBps: 9000000),
    trackingSince: now.subtract(const Duration(hours: 3)),
    live: [
      for (var i = 40; i >= 0; i--)
        WanPoint(at: now.subtract(Duration(seconds: i * 15)), downloadBps: 15000000 + (i % 7) * 1500000, uploadBps: 1500000 + (i % 5) * 200000),
    ],
    daily: [
      for (var i = 6; i >= 0; i--)
        WanDay(day: now.subtract(Duration(days: i)), downloadBytes: (3 + i) * 1000000000, uploadBytes: (1 + i % 3) * 200000000),
    ],
  );
}

DashboardLive _summary() => DashboardLive(
      totalDevices: 20,
      onlineDevices: 12,
      offlineDevices: 6,
      degradedDevices: 2,
      totalClients: 90,
      activeClients: 74,
      criticalAlerts: 1,
      openAlerts: 5,
      updatedAt: DateTime.now(),
    );

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  Stream<WanFeed>? feed,
  Stream<DashboardLive?>? summary,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        wanUsageProvider.overrideWith((ref) => feed ?? Stream.value(WanFeed(data: _usage(), fetchError: null, fetchedAt: DateTime.now()))),
        dashboardSummaryProvider.overrideWith((ref) => summary ?? Stream.value(_summary())),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  for (final size in const [Size(1500, 1000), Size(900, 1000), Size(420, 900)]) {
    testWidgets('renders real values without overflow at ${size.width.toInt()}px', (tester) async {
      await _pump(tester, size: size);

      expect(find.text('Internet speed'), findsOneWidget);
      expect(find.text('19.3'), findsOneWidget); // download
      expect(find.text('1.75'), findsOneWidget); // upload
      expect(find.text('Used today'), findsOneWidget);
      expect(find.text('Used this month'), findsOneWidget);
      expect(find.text('2.64'), findsOneWidget); // today total 2.4 + 0.24 GB
      expect(find.textContaining('Live'), findsOneWidget);
      expect(find.text('46%'), findsOneWidget); // router cpu
      expect(find.text('RB2011UiAS'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(find.text('74'), findsOneWidget); // active clients
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('says so when the router is not connected instead of showing numbers', (tester) async {
    await _pump(
      tester,
      size: const Size(1200, 900),
      feed: Stream.value(WanFeed(
        data: const WanUsage(available: false, error: 'router unreachable: dial tcp 172.16.0.1:8728: i/o timeout'),
        fetchError: null,
        fetchedAt: DateTime.now(),
      )),
    );

    expect(find.text('Router not connected'), findsWidgets);
    expect(find.textContaining('Mbps'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('marks stale readings as out of date', (tester) async {
    await _pump(
      tester,
      size: const Size(1200, 900),
      feed: Stream.value(WanFeed(data: _usage(stale: true, error: 'router unreachable'), fetchError: null, fetchedAt: DateTime.now())),
    );

    expect(find.textContaining('Out of date'), findsOneWidget);
    expect(find.textContaining('Live'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the last data and reports an unreachable server', (tester) async {
    await _pump(
      tester,
      size: const Size(1200, 900),
      feed: Stream.value(WanFeed(data: _usage(), fetchError: 'The NMS server is not reachable.', fetchedAt: DateTime.now())),
    );

    expect(find.textContaining('Server unreachable'), findsOneWidget);
    expect(find.text('19.3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows loading placeholders before the first reading', (tester) async {
    await _pump(tester, size: const Size(1200, 900), feed: const Stream<WanFeed>.empty(), summary: const Stream<DashboardLive?>.empty());

    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.textContaining('Mbps'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
