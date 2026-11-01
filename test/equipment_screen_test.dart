import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:network_monitorong/core/enums/device_status.dart';
import 'package:network_monitorong/core/enums/device_type.dart';
import 'package:network_monitorong/core/errors/failures.dart';
import 'package:network_monitorong/data/models/equipment_models.dart';
import 'package:network_monitorong/data/models/wan_usage_models.dart';
import 'package:network_monitorong/domain/entities/device.dart';
import 'package:network_monitorong/domain/usecases/device/create_device_usecase.dart';
import 'package:network_monitorong/domain/usecases/device/update_device_usecase.dart';
import 'package:network_monitorong/presentation/providers/dashboard/wan_provider.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/providers/equipment/equipment_provider.dart';
import 'package:network_monitorong/presentation/screens/devices/device_form_screen.dart';
import 'package:network_monitorong/presentation/screens/devices/equipment_filters.dart';
import 'package:network_monitorong/presentation/screens/devices/equipment_screen.dart';

EquipmentItem _item(
  String name, {
  DeviceType type = DeviceType.switch_,
  DeviceStatus status = DeviceStatus.online,
  String ip = '10.0.1.1',
  bool critical = false,
  bool pinned = false,
  bool monitored = true,
  double? ping = 2.5,
  double? loss = 0,
  String vendor = '',
  String location = '',
}) =>
    EquipmentItem(
      id: 'id-$name',
      name: name,
      ipAddress: ip,
      type: type,
      status: status,
      vendor: vendor,
      location: location,
      isCritical: critical,
      isPinned: pinned,
      isMonitored: monitored,
      lastSeen: DateTime.now().subtract(const Duration(minutes: 3)),
      pingAvgMs: ping,
      pingLossPercent: loss,
      pingAt: DateTime.now(),
    );

final _equipment = [
  _item('Core-Switch-01', ip: '10.0.1.1', vendor: 'Cisco', location: 'Server room'),
  _item('PACS-Server-01', type: DeviceType.server, status: DeviceStatus.offline, ip: '10.0.10.10', critical: true, ping: null),
  _item('Ward-B-AP-02', type: DeviceType.accessPoint, status: DeviceStatus.degraded, ip: '10.0.50.2', ping: 180, loss: 12),
  _item('MRI-Machine-01', type: DeviceType.medicalDevice, ip: '10.0.20.10', pinned: true),
  _item('Legacy-Switch', status: DeviceStatus.maintenance, ip: '10.0.80.1'),
  _item('Spare-Printer', type: DeviceType.printer, status: DeviceStatus.offline, ip: '10.0.70.10', monitored: false, ping: null),
];

void main() {
  group('applyEquipmentFilters', () {
    test('puts critical devices that need attention first, then the rest, then pinned, then by name', () {
      final names = applyEquipmentFilters(_equipment).map((e) => e.name).toList();
      expect(names, ['PACS-Server-01', 'Ward-B-AP-02', 'MRI-Machine-01', 'Core-Switch-01', 'Legacy-Switch', 'Spare-Printer']);
    });

    test('a device that is not monitored never "needs attention"', () {
      final printer = _equipment.last;
      expect(printer.status, DeviceStatus.offline);
      expect(printer.needsAttention, isFalse);
      expect(applyEquipmentFilters(_equipment, state: EquipmentStateFilter.attention).map((e) => e.name), ['PACS-Server-01', 'Ward-B-AP-02']);
    });

    test('filters by state and type', () {
      expect(applyEquipmentFilters(_equipment, state: EquipmentStateFilter.online).map((e) => e.name), ['MRI-Machine-01', 'Core-Switch-01']);
      expect(applyEquipmentFilters(_equipment, state: EquipmentStateFilter.maintenance).map((e) => e.name), ['Legacy-Switch']);
      expect(applyEquipmentFilters(_equipment, type: DeviceType.server).map((e) => e.name), ['PACS-Server-01']);
    });

    test('search matches name, address, vendor and location, all words required', () {
      expect(applyEquipmentFilters(_equipment, query: 'cisco').map((e) => e.name), ['Core-Switch-01']);
      expect(applyEquipmentFilters(_equipment, query: '10.0.50').map((e) => e.name), ['Ward-B-AP-02']);
      expect(applyEquipmentFilters(_equipment, query: 'server room core').map((e) => e.name), ['Core-Switch-01']);
      expect(applyEquipmentFilters(_equipment, query: 'cisco printer'), isEmpty);
    });

    test('counts devices per type, biggest first', () {
      final counts = equipmentTypeCounts(_equipment);
      expect(counts.first.key, DeviceType.switch_);
      expect(counts.first.value, 2);
    });
  });

  group('EquipmentScreen', () {
    Future<void> pump(WidgetTester tester, Size size, Stream<EquipmentFeed> feed, {WanUsage? wan}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            equipmentFeedProvider.overrideWith((ref) => feed),
            wanUsageProvider.overrideWith(
              (ref) => Stream.value(WanFeed(data: wan ?? const WanUsage(available: false, error: 'router unreachable'), fetchError: null, fetchedAt: DateTime.now())),
            ),
          ],
          child: const MaterialApp(home: EquipmentScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Stream<EquipmentFeed> ok() => Stream.value(EquipmentFeed(items: _equipment, fetchError: null, fetchedAt: DateTime.now()));

    for (final size in const [Size(1500, 1000), Size(1000, 1000), Size(420, 2600)]) {
      testWidgets('lists the equipment at ${size.width.toInt()}px without overflow', (tester) async {
        await pump(tester, size, ok());

        expect(find.text('PACS-Server-01'), findsOneWidget);
        expect(find.text('Core-Switch-01'), findsOneWidget);
        expect(find.text('Offline'), findsWidgets);
        expect(find.text('Degraded'), findsWidgets);
        expect(find.text('Needs attention'), findsOneWidget);
        expect(find.text('Add device'), findsOneWidget);
        expect(find.textContaining('No reply to ping'), findsOneWidget); // the offline server
        expect(find.textContaining('Not monitored'), findsOneWidget); // the spare printer
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('shows ping latency and loss from the latest ping', (tester) async {
      await pump(tester, const Size(1500, 1000), ok());

      expect(find.text('2.5 ms'), findsWidgets);
      expect(find.text('180 ms · 12% lost'), findsOneWidget);
    });

    testWidgets('the state tiles filter the list', (tester) async {
      await pump(tester, const Size(1500, 1000), ok());

      await tester.tap(find.text('Needs attention'));
      await tester.pump();

      expect(find.text('PACS-Server-01'), findsOneWidget);
      expect(find.text('Ward-B-AP-02'), findsOneWidget);
      expect(find.text('Core-Switch-01'), findsNothing);
    });

    testWidgets('searching narrows the list and an empty result offers to clear it', (tester) async {
      await pump(tester, const Size(1500, 1000), ok());

      await tester.enterText(find.byType(TextField).first, 'mri');
      await tester.pump();
      expect(find.text('MRI-Machine-01'), findsOneWidget);
      expect(find.text('Core-Switch-01'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pump();
      expect(find.text('No equipment matches'), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('Core-Switch-01'), findsOneWidget);
    });

    testWidgets('shows the MikroTik router live when it is connected', (tester) async {
      await pump(
        tester,
        const Size(1500, 1000),
        ok(),
        wan: WanUsage(
          available: true,
          linkRunning: true,
          current: const WanSpeed(downloadBps: 19300000, uploadBps: 1750000),
          router: const WanRouter(board: 'RB2011UiAS', version: '6.49.23 (stable)', cpuLoadPercent: 46, memoryUsedPercent: 31.2, uptimeSeconds: 606683),
        ),
      );

      expect(find.text('MikroTik RB2011UiAS'), findsOneWidget);
      expect(find.text('CPU 46%'), findsOneWidget);
      expect(find.text('Internet link up'), findsOneWidget);
      expect(find.textContaining('19.3 Mbps'), findsOneWidget);
    });

    testWidgets('says why when the router is not connected', (tester) async {
      await pump(tester, const Size(1500, 1000), ok());

      expect(find.text('Router not connected'), findsOneWidget);
    });

    testWidgets('an empty registry invites adding the first device', (tester) async {
      await pump(tester, const Size(1200, 900), Stream.value(EquipmentFeed(items: const [], fetchError: null, fetchedAt: DateTime.now())));

      expect(find.text('No equipment registered yet'), findsOneWidget);
      expect(find.text('Add the first device'), findsOneWidget);
    });

    testWidgets('keeps the last list and reports an unreachable server', (tester) async {
      await pump(tester, const Size(1200, 900), Stream.value(EquipmentFeed(items: _equipment, fetchError: 'The NMS server is not reachable.', fetchedAt: DateTime.now())));

      expect(find.textContaining('Server unreachable'), findsOneWidget);
      expect(find.text('Core-Switch-01'), findsOneWidget);
    });

    testWidgets('shows placeholders before the first answer', (tester) async {
      await pump(tester, const Size(1200, 900), const Stream<EquipmentFeed>.empty());

      expect(find.text('Connecting…'), findsOneWidget);
      expect(find.text('Core-Switch-01'), findsNothing);
    });
  });

  group('DeviceFormScreen', () {
    Future<void> pumpForm(WidgetTester tester, {required CreateDeviceUseCase create, UpdateDeviceUseCase? update, String? editId, Device? existing}) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('home'))),
          GoRoute(path: '/form', builder: (_, __) => DeviceFormScreen(deviceId: editId)),
          GoRoute(path: '/devices/:id', builder: (_, s) => Scaffold(body: Text('detail ${s.pathParameters['id']}'))),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            createDeviceUseCaseProvider.overrideWithValue(create),
            if (update != null) updateDeviceUseCaseProvider.overrideWithValue(update),
            if (editId != null) deviceDetailProvider(editId).overrideWith((ref) async => existing),
            equipmentFeedProvider.overrideWith((ref) => const Stream<EquipmentFeed>.empty()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/form');
      await tester.pumpAndSettle();
    }

    testWidgets('does not save without a name and a valid IP, and says what is wrong', (tester) async {
      final create = _FakeCreate();
      await pumpForm(tester, create: create);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('The name is required'), findsOneWidget);
      expect(find.text('IP address is required'), findsOneWidget);
      expect(create.saved, isEmpty);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Core-Switch-03');
      await tester.enterText(find.widgetWithText(TextFormField, 'IP address *'), '10.0.1.999');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Invalid IP address format'), findsOneWidget);
      expect(create.saved, isEmpty);
    });

    testWidgets('sends the typed values to the server and opens the new device', (tester) async {
      final create = _FakeCreate();
      await pumpForm(tester, create: create);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), '  Core-Switch-03 ');
      await tester.enterText(find.widgetWithText(TextFormField, 'IP address *'), '10.0.1.3');
      await tester.enterText(find.widgetWithText(TextFormField, 'Vendor'), 'Cisco');
      await tester.enterText(find.widgetWithText(TextFormField, 'Location'), 'Server room');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(create.saved, hasLength(1));
      final d = create.saved.single;
      expect(d.name, 'Core-Switch-03');
      expect(d.ipAddress, '10.0.1.3');
      expect(d.vendor, 'Cisco');
      expect(d.location, 'Server room');
      expect(d.macAddress, isNull); // left empty means none
      expect(d.isMonitored, isTrue);
      expect(find.text('detail new-id'), findsOneWidget);
    });

    testWidgets('shows the server message, such as a duplicate IP, and stays on the form', (tester) async {
      final create = _FakeCreate(failure: const ValidationFailure(message: 'Another device already uses this IP address'));
      await pumpForm(tester, create: create);

      await tester.enterText(find.widgetWithText(TextFormField, 'Name *'), 'Dup');
      await tester.enterText(find.widgetWithText(TextFormField, 'IP address *'), '10.0.1.1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Another device already uses this IP address'), findsOneWidget);
      expect(find.text('Add device'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget); // not stuck on "Saving…"
    });

    testWidgets('editing loads the stored device and saves changes under its id', (tester) async {
      final update = _FakeUpdate();
      final stored = Device(
        id: 'dev-9',
        name: 'Core-Switch-01',
        ipAddress: '10.0.1.1',
        type: DeviceType.switch_,
        status: DeviceStatus.online,
        vendor: 'Cisco',
        isCritical: true,
        firstSeen: DateTime(2025),
        lastSeen: DateTime(2025),
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      await pumpForm(tester, create: _FakeCreate(), update: update, editId: 'dev-9', existing: stored);

      expect(find.text('Edit device'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Core-Switch-01'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Cisco'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Core-Switch-01'), 'Core-Switch-01B');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(update.saved, hasLength(1));
      expect(update.saved.single.id, 'dev-9');
      expect(update.saved.single.name, 'Core-Switch-01B');
      expect(update.saved.single.isCritical, isTrue);
      expect(update.saved.single.status, DeviceStatus.online); // the status is measured, not edited
    });
  });
}

class _FakeCreate implements CreateDeviceUseCase {
  _FakeCreate({this.failure});

  final Failure? failure;
  final saved = <Device>[];

  @override
  Future<Either<Failure, Device>> call(Device device) async {
    if (failure != null) return Left(failure!);
    saved.add(device);
    return Right(device.copyWith(id: 'new-id'));
  }
}

class _FakeUpdate implements UpdateDeviceUseCase {
  final saved = <Device>[];

  @override
  Future<Either<Failure, Device>> call(Device device) async {
    saved.add(device);
    return Right(device);
  }
}
