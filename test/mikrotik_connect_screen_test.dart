import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/di/injection_container.dart';
import 'package:network_monitorong/presentation/screens/connect/mikrotik_connect_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('development starts with MikroTik connection fields', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: MikroTikConnectScreen()),
      ),
    );

    expect(find.text('Connect to MikroTik'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Router IP'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Username'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('8728 - RouterOS API'), findsOneWidget);
    expect(find.text('Test and Connect'), findsOneWidget);
    expect(find.text('JWT disabled locally'), findsOneWidget);
  });

  testWidgets('connection form remains usable at mobile width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(420, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const MaterialApp(home: MikroTikConnectScreen()),
      ),
    );

    expect(find.text('Connect to MikroTik'), findsOneWidget);
    expect(find.text('JWT disabled locally'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
