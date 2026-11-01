import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/core/config/build_config.dart';
import 'package:network_monitorong/core/config/environment.dart';
import 'package:network_monitorong/core/network/dio_client.dart';
import 'package:network_monitorong/core/security/jwt_manager.dart';
import 'package:network_monitorong/core/services/marco_state_service.dart';
import 'package:network_monitorong/data/datasources/remote/marco_remote_datasource.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/providers/marco/marco_provider.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_group_detail_screen.dart';
import 'package:network_monitorong/presentation/screens/marco/marco_groups_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the Marco screens against a real backend on localhost:8080 (development
/// auth, router writes disabled). Skipped automatically when no backend answers.
///
///   flutter test test/marco_live_backend_test.dart
void main() {
  late bool backendUp;
  late MarcoRemoteDataSource remote;
  final runId = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final createdGroups = <String>[];

  setUpAll(() async {
    HttpOverrides.global = null; // flutter_test blocks real sockets by default
    BuildConfig.initialize(environment: Environment.development);
    remote = MarcoRemoteDataSource(
      DioClient(jwtManager: JwtManager(const FlutterSecureStorage())),
    );
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('http://localhost:8080/api/v1/health'));
      final response = await request.close();
      await response.drain<void>();
      backendUp = response.statusCode == 200;
      client.close();
      // These tests create groups and members, which the backend then syncs. Only run
      // them against a backend that does not write to the router.
      if (backendUp && !(await remote.listGroups()).dryRun) {
        backendUp = false;
      }
    } catch (_) {
      backendUp = false;
    }
  });

  tearDownAll(() async {
    if (!backendUp) return;
    for (final id in createdGroups) {
      try {
        await remote.deleteGroup(id);
      } catch (_) {
        // The backend may report a router sync problem even though the group is gone.
      }
    }
  });

  Future<void> until(WidgetTester tester, Finder finder, {int seconds = 20}) async {
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Timed out waiting for $finder');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
    }
  }

  Future<Widget> app(Widget home) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        marcoRemoteProvider.overrideWithValue(remote),
        marcoStateServiceProvider.overrideWithValue(MarcoStateService(preferences)),
      ],
      child: MaterialApp(home: home),
    );
  }

  testWidgets('groups screen lists a backend group and shows the safe-mode banner', (tester) async {
    if (!backendUp) {
      markTestSkipped('no backend on localhost:8080, or it has router writes enabled (ROUTER_POLICY_WRITES=true)');
      return;
    }
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final name = 'UI list $runId';
      final group = await remote.createGroup(name: name, description: 'live test', color: 'green', icon: 'medical');
      createdGroups.add(group.id);

      await tester.pumpWidget(await app(const MarcoGroupsScreen()));
      await until(tester, find.text(name));

      expect(find.textContaining('Safe mode'), findsOneWidget);
      expect(find.textContaining('0 device(s)'), findsWidgets);
      expect(find.text('Could not load Marco groups'), findsNothing);
    });
  });

  testWidgets('detail screen saves membership and policy through the real API', (tester) async {
    if (!backendUp) {
      markTestSkipped('no backend on localhost:8080, or it has router writes enabled (ROUTER_POLICY_WRITES=true)');
      return;
    }
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      final group = await remote.createGroup(name: 'UI detail $runId', description: '', color: 'blue', icon: 'group');
      createdGroups.add(group.id);
      final hex = DateTime.now().millisecondsSinceEpoch.toRadixString(16).toUpperCase();
      final mac = 'AA:BB:CC:${hex.substring(hex.length - 4, hex.length - 2)}:${hex.substring(hex.length - 2)}:01';

      await tester.pumpWidget(await app(MarcoGroupDetailScreen(groupId: group.id)));
      await until(tester, find.text('Apply policies'));
      await until(tester, find.text('YouTube'));

      // --- membership ---
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Add MAC address (AA:BB:CC:DD:EE:FF)',
        ),
        mac,
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add'));
      await tester.tap(find.widgetWithText(FilledButton, 'Add'));
      await until(
        tester,
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').toLowerCase().contains(mac.toLowerCase()),
        ),
      );

      // --- policy ---
      await tester.tap(find.widgetWithText(SwitchListTile, 'Unlimited speed'));
      await tester.pump();
      Finder field(String label) => find.byWidgetPredicate(
            (w) => w is TextField && w.decoration?.labelText == label,
          );
      await tester.enterText(field('Download limit (Mbps)'), '12');
      await tester.enterText(field('Upload limit (Mbps)'), '6');
      await tester.ensureVisible(find.text('YouTube'));
      await tester.tap(find.text('YouTube'));
      await tester.pump();
      await tester.ensureVisible(find.text('Apply policies'));
      await tester.tap(find.text('Apply policies'), warnIfMissed: false);

      // The save round-trips to the backend; poll the API for the stored result.
      Map<String, dynamic>? stored;
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        final groups = (await remote.listGroups()).groups;
        stored = groups.firstWhere((g) => g.id == group.id).policy;
        if (stored['download_limit_mbps'] != null) break;
      }
      expect(stored?['unlimited_speed'], false);
      expect(stored?['download_limit_mbps'], 12);
      expect(stored?['upload_limit_mbps'], 6);
      expect(stored?['blocked_websites'], contains('youtube'));

      final reloaded = (await remote.listGroups()).groups.firstWhere((g) => g.id == group.id);
      expect(reloaded.hasMac(mac), isTrue);

      // --- remove the member again through the chip ---
      final chip = tester.widget<InputChip>(find.byType(InputChip));
      chip.onDeleted!();
      for (var i = 0; i < 100; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
        final now = (await remote.listGroups()).groups.firstWhere((g) => g.id == group.id);
        if (now.members.isEmpty) break;
      }
      final afterRemove = (await remote.listGroups()).groups.firstWhere((g) => g.id == group.id);
      expect(afterRemove.members, isEmpty);
    });
  });
}
