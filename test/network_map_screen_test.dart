import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/models/network_map_models.dart';
import 'package:network_monitorong/presentation/providers/network/network_map_provider.dart';
import 'package:network_monitorong/presentation/screens/network/network_map_screen.dart';
import 'package:network_monitorong/presentation/screens/network/widgets/map_canvas.dart';

MapDevice _dev(
  String name, {
  String ip = '',
  String mac = '',
  String kind = 'computer',
  bool online = true,
  String port = 'ether5',
  String place = '',
  PlaceSource source = PlaceSource.none,
  String sourceKind = 'client',
}) => MapDevice(
  id: 'mac:$mac',
  source: sourceKind,
  name: name,
  ip: ip,
  mac: mac,
  kind: kind,
  online: online,
  status: online ? 'online' : 'offline',
  port: port,
  place: place,
  placeSource: source,
);

NetworkMapData _map({String? topologyError, String? error}) {
  final devices = [
    _dev('Nurse PC', ip: '172.16.0.10', mac: 'AA:00:00:00:00:01', place: 'Emergency ward', source: PlaceSource.custom),
    _dev('iPhone Sara', ip: '172.16.0.11', mac: 'AA:00:00:00:00:02', kind: 'phone'),
    _dev('Lab printer', ip: '172.16.0.12', mac: 'AA:00:00:00:00:03', kind: 'printer', port: 'ether2'),
    _dev('Old tablet', ip: '172.16.0.13', mac: 'AA:00:00:00:00:04', kind: 'tablet', online: false),
    _dev('Mystery', ip: '172.16.0.14', mac: 'AA:00:00:00:00:05', kind: 'unknown', port: ''),
    _dev('PACS', ip: '172.16.0.50', kind: 'server', sourceKind: 'equipment'),
  ];
  return NetworkMapData(
    available: true,
    topologyError: topologyError,
    error: error,
    updatedAt: DateTime.now(),
    topologyAt: DateTime.now(),
    router: const MapRouter(name: 'MikroTik', ip: '172.16.0.1', online: true),
    ports: const [
      MapPort(name: 'ether2', label: 'in', labelSource: 'comment', running: true, devices: 1, online: 1),
      MapPort(name: 'ether3'),
      MapPort(name: 'ether5', label: 'out', labelSource: 'comment', running: true, devices: 4, online: 3),
    ],
    devices: devices,
    summary: const MapSummary(
      total: 6,
      online: 5,
      offline: 1,
      located: 1,
      unplaced: 5,
      unnamed: 1,
      byKind: {'computer': 1, 'phone': 1, 'printer': 1, 'tablet': 1, 'unknown': 1, 'server': 1},
    ),
  );
}

class _FakeMap extends NetworkMapController {
  _FakeMap(this._initial);

  final NetworkMapState _initial;
  final List<String> calls = [];

  @override
  NetworkMapState build() => _initial;

  @override
  Future<void> refresh({bool force = false}) async => calls.add('refresh:$force');

  @override
  Future<void> saveDevice(String mac, {String? displayName, String? kind, String? place}) async =>
      calls.add('save:$mac|$displayName|$kind|$place');

  @override
  Future<int> saveDevicePlaces(List<String> macs, String place) async {
    calls.add('places:${macs.join(",")}|$place');
    return macs.length;
  }

  @override
  Future<void> savePortLabel(String port, String label) async => calls.add('port:$port|$label');
}

Future<_FakeMap> _pump(WidgetTester tester, NetworkMapState state, {Size size = const Size(1500, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  late _FakeMap fake;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [networkMapProvider.overrideWith(() => fake = _FakeMap(state))],
      child: const MaterialApp(home: NetworkMapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

void main() {
  test('layout puts every device behind its port and unknown ports last', () {
    final data = _map();
    final layout = MapLayout.compute(data, data.devices.where((d) => d.online).toList());
    expect(layout.groups.map((g) => g.port), ['ether2', 'ether5', '']);
    expect(layout.groups[1].devices.map((d) => d.name), containsAll(['Nurse PC', 'iPhone Sara', 'PACS']));
    for (final g in layout.groups) {
      for (var i = 0; i < g.devices.length; i++) {
        expect(g.rect.contains(g.cardRect(i).center), isTrue, reason: 'card $i of ${g.port} sits inside its group');
      }
    }
    expect(layout.size.width, greaterThan(layout.router.right));
  });

  testWidgets('shows online devices with name, IP and place, and hides offline ones', (tester) async {
    await _pump(tester, NetworkMapState(data: _map(), loading: false));
    expect(find.text('Nurse PC'), findsOneWidget);
    expect(find.text('172.16.0.10'), findsOneWidget);
    expect(find.text('Emergency ward'), findsWidgets);
    expect(find.text('Old tablet'), findsNothing);
    expect(find.textContaining('6 devices'), findsOneWidget);
    expect(find.textContaining('5 without'), findsOneWidget);
    expect(find.text('MikroTik'), findsOneWidget);
    expect(find.text('Port not known'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Offline (1)'));
    await tester.pump();
    expect(find.text('Old tablet'), findsOneWidget);
  });

  testWidgets('search narrows the map and an empty result says so', (tester) async {
    await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.enterText(find.byType(TextField).first, 'printer');
    await tester.pump();
    expect(find.text('Lab printer'), findsOneWidget);
    expect(find.text('Nurse PC'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'zzz-nothing');
    await tester.pump();
    expect(find.text('No device matches'), findsOneWidget);
  });

  testWidgets('selecting a device opens its details and saving sends the changes', (tester) async {
    final fake = await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.tap(find.text('iPhone Sara'));
    await tester.pump();
    expect(find.text('MAC address'), findsOneWidget);
    expect(find.text('AA:00:00:00:00:02'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);

    await tester.tap(find.text('Name it / set place'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Place'), 'Ward 3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('save:AA:00:00:00:00:02|null|null|Ward 3'));
  });

  testWidgets('registered equipment cannot be edited from the map', (tester) async {
    await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.tap(find.text('PACS'));
    await tester.pump();
    expect(find.text('Name it / set place'), findsNothing);
    expect(find.textContaining('Equipment page'), findsOneWidget);
  });

  testWidgets('list view ticks several devices and sets one place for all', (tester) async {
    final fake = await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.text('MAC address'), findsOneWidget);
    final boxes = find.byType(Checkbox);
    await tester.tap(boxes.at(2));
    await tester.tap(boxes.at(3));
    await tester.pump();
    expect(find.text('2 selected'), findsOneWidget);
    await tester.tap(find.text('Set place'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Place'), 'Laboratory');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final call = fake.calls.singleWhere((c) => c.startsWith('places:'));
    expect(call.endsWith('|Laboratory'), isTrue);
    expect(call.split('|').first.split(',').length, 2);
  });

  testWidgets('naming a port sends it to the server', (tester) async {
    final fake = await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.tap(find.widgetWithText(ActionChip, 'ether2 · in · 1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Front desk switch');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('port:ether2|Front desk switch'));
  });

  testWidgets('refresh button asks the server to read the router again', (tester) async {
    final fake = await _pump(tester, NetworkMapState(data: _map(), loading: false));
    await tester.tap(find.byTooltip('Read the router again'));
    await tester.pump();
    expect(fake.calls, contains('refresh:true'));
  });

  testWidgets('says plainly when ports or the server could not be read', (tester) async {
    await _pump(
      tester,
      NetworkMapState(data: _map(topologyError: 'router unreachable'), fetchError: 'The NMS server is not reachable.', loading: false, fetchedAt: DateTime.now()),
    );
    expect(find.textContaining('Ports could not be read (router unreachable)'), findsOneWidget);
    expect(find.textContaining('The NMS server is not reachable.'), findsOneWidget);
    expect(find.text('Nurse PC'), findsOneWidget);
  });

  testWidgets('shows a retry when nothing could be loaded', (tester) async {
    final fake = await _pump(tester, const NetworkMapState(fetchError: 'The NMS server is not reachable.', loading: false));
    expect(find.text('The NMS server is not reachable.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(fake.calls, contains('refresh:true'));
  });

  testWidgets('narrow window opens the details in a dialog without overflow', (tester) async {
    await _pump(tester, NetworkMapState(data: _map(), loading: false), size: const Size(700, 900));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Nurse PC'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Emergency ward'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
