import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/services/marco_state_service.dart';
import 'package:network_monitorong/data/datasources/remote/marco_remote_datasource.dart';
import 'package:network_monitorong/data/models/marco_models.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/providers/marco/marco_provider.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_group_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMarcoRemote implements MarcoRemoteDataSource {
  Map<String, dynamic>? savedPolicy;

  MarcoGroup get _group => MarcoGroup(
        id: 'group-1',
        name: 'Family',
        description: 'Family devices',
        color: 'blue',
        icon: 'group',
        policy: savedPolicy ?? const {'internet_enabled': true},
        members: const [MarcoMember(deviceId: 'd1', name: 'Tablet', macAddress: 'AA:BB:CC:DD:EE:FF')],
        createdAt: DateTime(2024, 1, 1),
      );

  @override
  Future<MarcoGroupsResult> listGroups() async => MarcoGroupsResult(groups: [_group], dryRun: true);

  @override
  Future<List<MarcoPlatform>> listPlatforms() async => const [MarcoPlatform(key: 'youtube', label: 'YouTube')];

  @override
  Future<MarcoActionResult> updatePolicy(String groupId, Map<String, dynamic> policy) async {
    savedPolicy = policy;
    return const MarcoActionResult(dryRun: true, message: 'saved');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

void main() {
  testWidgets('Apply policies sends the edited policy to the backend', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final remote = _FakeMarcoRemote();
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          marcoRemoteProvider.overrideWithValue(remote),
          marcoStateServiceProvider.overrideWithValue(MarcoStateService(preferences)),
        ],
        child: const MaterialApp(home: MarcoGroupDetailScreen(groupId: 'group-1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tablet • AA:BB:CC:DD:EE:FF'), findsOneWidget);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Unlimited speed'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byWidgetPredicate(
        (widget) => widget is TextField && widget.decoration?.labelText == 'Download limit (Mbps)',
      ),
      '12',
    );

    await tester.ensureVisible(find.text('Apply policies'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply policies'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(remote.savedPolicy?['download_limit_mbps'], 12.0);
    expect(remote.savedPolicy?['unlimited_speed'], false);
  });
}
