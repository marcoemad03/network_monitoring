// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:network_monitorong/app.dart';
import 'package:network_monitorong/core/config/build_config.dart';
import 'package:network_monitorong/core/config/environment.dart';
import 'package:network_monitorong/core/di/injection_container.dart';
import 'package:network_monitorong/presentation/router/app_router.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    BuildConfig.initialize(environment: Environment.development);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final appRouter = AppRouter();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: NMSApp(appRouter: appRouter),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Connect to MikroTik'), findsOneWidget);
    expect(find.text('Login'), findsNothing);
  });
}
