import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/datasources/remote/client_remote_datasource.dart';
import 'package:network_monitorong/data/models/inventory_models.dart';
import 'package:network_monitorong/presentation/providers/clients/clients_provider.dart';
import 'package:network_monitorong/presentation/screens/assets/asset_list_screen.dart';

class _FakeClients implements ClientRemoteDataSource {
  String? mac;
  String? kind;

  @override
  Future<void> saveNote(String mac, {String? displayName, String? note, String? kind, String? place}) async {
    this.mac = mac;
    this.kind = kind;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _inv = AssetInventory.fromJson({
  'total': 3,
  'online': 2,
  'needs_review': 1,
  'counts': [
    {'kind': 'printer', 'total': 1, 'online': 1},
    {'kind': 'computer', 'total': 1, 'online': 1},
    {'kind': 'unknown', 'total': 1, 'online': 0},
  ],
  'items': [
    {'id': 'a', 'name': 'Reception printer', 'ip': '172.16.0.20', 'mac': 'AA:00:00:00:00:02', 'kind': 'printer', 'kind_source': 'scan', 'confidence': 'high', 'model': 'HP M404', 'serial': 'S1', 'page_count': 900, 'toner_percent': 40, 'online': true},
    {'id': 'b', 'name': 'PC-1', 'ip': '172.16.0.21', 'mac': 'AA:00:00:00:00:03', 'kind': 'computer', 'confidence': 'high', 'online': true},
    {'id': 'c', 'name': 'Mystery', 'ip': '172.16.0.22', 'mac': 'AA:00:00:00:00:04', 'kind': 'unknown', 'confidence': 'none'},
  ],
  'excluded': [
    {'id': 'd', 'name': 'Galaxy', 'ip': '172.16.0.23', 'mac': 'AA:00:00:00:00:05', 'kind': 'phone', 'confidence': 'high', 'online': true},
  ],
});

Future<_FakeClients> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final clients = _FakeClients();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [inventoryProvider.overrideWith((ref) async => _inv), clientRemoteProvider.overrideWithValue(clients)],
      child: const MaterialApp(home: AssetListScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return clients;
}

void main() {
  testWidgets('counts by type and details, without phones', (tester) async {
    await _pump(tester);
    expect(find.text('All devices'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('HP M404'), findsOneWidget);
    expect(find.textContaining('900 pages'), findsOneWidget);
    expect(find.textContaining('Toner 40%'), findsOneWidget);
    expect(find.text('Galaxy'), findsNothing);
    expect(find.text('Phones, not counted (1)'), findsOneWidget);
  });

  testWidgets('filters by type, phones and search', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Computer').first);
    await tester.pumpAndSettle();
    expect(find.text('PC-1'), findsOneWidget);
    expect(find.text('Reception printer'), findsNothing);

    await tester.tap(find.text('Phones, not counted (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Galaxy'), findsOneWidget);

    await tester.tap(find.text('All devices'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '172.16.0.22');
    await tester.pumpAndSettle();
    expect(find.text('Mystery'), findsOneWidget);
    expect(find.text('PC-1'), findsNothing);
  });

  testWidgets('an IP can be told it is a router', (tester) async {
    final clients = await _pump(tester);
    await tester.tap(find.text('Mystery'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Router').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(clients.mac, 'AA:00:00:00:00:04');
    expect(clients.kind, 'router');
  });
}
