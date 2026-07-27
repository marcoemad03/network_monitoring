import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/di/injection_container.dart';
import 'package:network_monitorong/core/services/marco_state_service.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_group_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Apply policies persists the updated policy values', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final service = MarcoStateService(preferences);
    await service.saveGroup(
      MarcoGroup(
        id: 'group-1',
        name: 'Family',
        description: 'Family devices',
        color: 'blue',
        icon: 'group',
        macAddresses: const ['AA:BB:CC:DD:EE:FF'],
        policy: const {'internet_enabled': true},
        createdAt: DateTime(2024, 1, 1),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: MaterialApp(
          home: MarcoGroupDetailScreen(groupId: 'group-1'),
        ),
      ),
    );

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

    final reloaded = MarcoStateService(preferences);
    await reloaded.load();

    expect(reloaded.groups.single.policy['download_limit_mbps'], 12.0);
  });
}
