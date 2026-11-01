import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/models/client_inventory_models.dart';
import 'package:network_monitorong/presentation/providers/clients/clients_provider.dart';
import 'package:network_monitorong/presentation/providers/marco/marco_provider.dart';
import 'package:network_monitorong/data/models/marco_models.dart';
import 'package:network_monitorong/presentation/screens/devices/client_filters.dart';
import 'package:network_monitorong/presentation/screens/devices/devices_screen.dart';

ClientDevice _device(
  String mac,
  String name, {
  ClientKind kind = ClientKind.phone,
  bool online = true,
  String ip = '172.16.0.5',
  int today = 0,
  int bps = 0,
  String note = '',
  String routerComment = '',
  String brand = '',
  DateTime? lastSeen,
}) =>
    ClientDevice(
      mac: mac,
      ip: ip,
      hostname: name,
      displayName: name,
      nameSource: 'hostname',
      kind: kind,
      brand: brand,
      confidence: 'high',
      kindReason: 'host name "$name"',
      online: online,
      network: 'hotspot1',
      hasCounters: true,
      note: note,
      routerComment: routerComment,
      lastSeen: lastSeen ?? DateTime.now(),
      uptimeSeconds: 3600,
      downloadBps: bps,
      uploadBps: bps ~/ 10,
      todayDownload: today,
      todayUpload: today ~/ 10,
    );

final _devices = [
  _device('AA:00:00:00:00:01', 'iPhone', brand: 'Apple', today: 900000000, bps: 2000000, ip: '172.16.0.9'),
  _device('AA:00:00:00:00:02', 'DESKTOP-AB12CD3', kind: ClientKind.computer, today: 3000000000, bps: 8000000, ip: '172.16.0.10', routerComment: 'مخزن'),
  _device('AA:00:00:00:00:03', 'HPLaserJetM404', kind: ClientKind.printer, today: 1000000, ip: '172.16.0.100', note: 'Reception printer'),
  _device('AA:00:00:00:00:04', 'OldTablet', kind: ClientKind.tablet, online: false, ip: '172.16.0.7', lastSeen: DateTime.now().subtract(const Duration(days: 2))),
];

void main() {
  group('applyClientFilters', () {
    test('lists only online devices by default, busiest first', () {
      final r = applyClientFilters(_devices);
      expect(r.map((d) => d.displayName), ['DESKTOP-AB12CD3', 'iPhone', 'HPLaserJetM404']);
    });

    test('offline and all views', () {
      expect(applyClientFilters(_devices, presence: ClientPresence.offline).map((d) => d.displayName), ['OldTablet']);
      expect(applyClientFilters(_devices, presence: ClientPresence.all), hasLength(4));
    });

    test('filters by kind', () {
      expect(applyClientFilters(_devices, kind: ClientKind.printer).map((d) => d.displayName), ['HPLaserJetM404']);
    });

    test('search looks at name, address, comment and brand, all words must match', () {
      expect(applyClientFilters(_devices, query: 'reception').map((d) => d.displayName), ['HPLaserJetM404']);
      expect(applyClientFilters(_devices, query: 'apple').map((d) => d.displayName), ['iPhone']);
      expect(applyClientFilters(_devices, query: '172.16.0.10').map((d) => d.displayName), ['DESKTOP-AB12CD3', 'HPLaserJetM404']);
      expect(applyClientFilters(_devices, query: 'مخزن').map((d) => d.displayName), ['DESKTOP-AB12CD3']);
      expect(applyClientFilters(_devices, query: 'iphone printer'), isEmpty);
    });

    test('sorts IP addresses numerically, not as text', () {
      final r = applyClientFilters(_devices, sort: ClientSort.ip);
      expect(r.map((d) => d.ip), ['172.16.0.9', '172.16.0.10', '172.16.0.100']);
      expect(compareIp('172.16.0.9', '172.16.0.10'), lessThan(0));
      expect(compareIp('not-an-ip', '172.16.0.1'), greaterThan(0));
    });

    test('sorts by speed and by name', () {
      expect(applyClientFilters(_devices, sort: ClientSort.speed).first.displayName, 'DESKTOP-AB12CD3');
      expect(applyClientFilters(_devices, sort: ClientSort.name).map((d) => d.displayName), ['DESKTOP-AB12CD3', 'HPLaserJetM404', 'iPhone']);
    });

    test('counts online devices per kind, biggest first', () {
      final counts = kindCounts([..._devices, _device('AA:00:00:00:00:05', 'Galaxy-A24')], ClientPresence.online);
      expect(counts.first.key, ClientKind.phone);
      expect(counts.first.value, 2);
      expect(counts.map((e) => e.key), isNot(contains(ClientKind.tablet))); // the tablet is offline
    });
  });

  group('DevicesScreen', () {
    Future<void> pump(WidgetTester tester, Size size, Stream<ClientFeed> feed) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clientFeedProvider.overrideWith((ref) => feed),
            marcoGroupsProvider.overrideWith(_NoGroups.new),
          ],
          child: const MaterialApp(home: DevicesScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    ClientFeed ok({bool available = true, String? error, bool stale = false}) => ClientFeed(
          data: ClientList(
            available: available,
            error: error,
            stale: stale,
            updatedAt: DateTime.now().subtract(const Duration(seconds: 4)),
            summary: const ClientSummary(
              online: 3,
              known: 4,
              onlineByKind: {ClientKind.phone: 1, ClientKind.computer: 1, ClientKind.printer: 1},
              downloadBps: 10000000,
              uploadBps: 1000000,
              todayDownload: 4000000000,
              todayUpload: 400000000,
            ),
            clients: _devices,
          ),
          fetchError: null,
          fetchedAt: DateTime.now(),
        );

    for (final size in const [Size(1500, 1000), Size(1000, 1000), Size(420, 2400)]) {
      testWidgets('shows the devices with usage and comments at ${size.width.toInt()}px, no overflow', (tester) async {
        await pump(tester, size, Stream.value(ok()));

        expect(find.text('DESKTOP-AB12CD3'), findsWidgets); // the row and the "Top user today" tile
        expect(find.text('iPhone'), findsOneWidget);
        expect(find.text('OldTablet'), findsNothing); // offline, hidden by default
        expect(find.textContaining('Live'), findsOneWidget);
        expect(find.text('Online now'), findsWidgets);
        expect(find.textContaining('Phones'), findsOneWidget);
        expect(find.textContaining('Computers'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('switching to All shows offline devices with when they were last seen', (tester) async {
      await pump(tester, const Size(1500, 1000), Stream.value(ok()));

      await tester.tap(find.text('All seen'));
      await tester.pump();

      expect(find.text('OldTablet'), findsOneWidget);
      expect(find.text('Offline'), findsWidgets);
      expect(find.text('2d ago'), findsOneWidget);
    });

    testWidgets('searching narrows the list and an empty result offers to clear it', (tester) async {
      await pump(tester, const Size(1500, 1000), Stream.value(ok()));

      await tester.enterText(find.byType(TextField).first, 'laserjet');
      await tester.pump();
      expect(find.text('HPLaserJetM404'), findsOneWidget);
      expect(find.text('iPhone'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'nothing-like-this');
      await tester.pump();
      expect(find.text('No device matches'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('iPhone'), findsOneWidget);
    });

    testWidgets('tapping a device opens its details with the comment field', (tester) async {
      await pump(tester, const Size(1500, 1000), Stream.value(ok()));

      await tester.tap(find.text('HPLaserJetM404'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Name and type'), findsOneWidget);
      expect(find.text('Comment'), findsWidgets);
      expect(find.text('Reception printer'), findsWidgets); // the saved comment
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('the details name the company behind the MAC address', (tester) async {
      final withVendor = ClientList(
        available: true,
        updatedAt: DateTime.now(),
        summary: const ClientSummary(online: 1, known: 1),
        clients: [
          ClientDevice(
            mac: 'DC:4A:3E:68:76:3F',
            ip: '172.16.0.50',
            displayName: 'Hewlett Packard computer · 172.16.0.50',
            nameSource: 'guess',
            kind: ClientKind.computer,
            brand: 'Hewlett Packard',
            vendor: 'Hewlett Packard',
            confidence: 'low',
            kindReason: 'its MAC address belongs to Hewlett Packard',
            online: true,
          ),
        ],
      );
      await pump(tester, const Size(1500, 1000), Stream.value(ClientFeed(data: withVendor, fetchError: null, fetchedAt: DateTime.now())));
      expect(find.textContaining('Computer · Hewlett Packard'), findsOneWidget);

      await tester.tap(find.textContaining('Hewlett Packard computer'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Made by'), findsOneWidget);
      expect(find.text('Low confidence, a best guess: its MAC address belongs to Hewlett Packard'), findsWidgets);
    });

    testWidgets('says why when the router is not connected', (tester) async {
      await pump(tester, const Size(1200, 900), Stream.value(ok(available: false, error: 'router unreachable')));

      expect(find.text('Router not connected'), findsWidgets);
      expect(find.text('iPhone'), findsNothing);
    });

    testWidgets('marks old data as out of date', (tester) async {
      await pump(tester, const Size(1200, 900), Stream.value(ok(stale: true)));

      expect(find.textContaining('Out of date'), findsOneWidget);
    });

    testWidgets('shows placeholders before the first answer', (tester) async {
      await pump(tester, const Size(1200, 900), const Stream<ClientFeed>.empty());

      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('iPhone'), findsNothing);
    });
  });
}

class _NoGroups extends MarcoGroupsController {
  @override
  Future<MarcoGroupsResult> build() async => const MarcoGroupsResult(groups: [], dryRun: false);
}
