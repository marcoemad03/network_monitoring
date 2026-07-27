import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_monitorong/core/di/injection_container.dart';
import 'package:network_monitorong/core/services/marco_state_service.dart';
import 'package:network_monitorong/domain/entities/connected_device.dart';
import 'package:network_monitorong/domain/entities/router_connection_status.dart';
import 'package:network_monitorong/presentation/providers/device/device_provider.dart';
import 'package:network_monitorong/presentation/screens/devices/connected_devices_screen.dart';

void main() {
  final checkedAt = DateTime(2026, 7, 26, 11);
  final devices = [
    ConnectedDevice(
      id: 'AA:BB:CC:DD:EE:01',
      deviceName: 'Nurse Station',
      hostname: 'nurse-01',
      ipAddress: '172.16.0.20',
      macAddress: 'AA:BB:CC:DD:EE:01',
      isOnline: true,
      connectionType: 'LAN',
      interfaceName: 'ether5',
      lastSeen: checkedAt,
    ),
    ConnectedDevice(
      id: 'AA:BB:CC:DD:EE:02',
      deviceName: 'Portable Scanner',
      hostname: 'scanner-01',
      ipAddress: '172.16.0.8',
      macAddress: 'AA:BB:CC:DD:EE:02',
      isOnline: false,
      connectionType: 'WiFi',
      connectedAccessPoint: 'ward-ap',
      interfaceName: 'wifi1',
      lastSeen: checkedAt,
    ),
  ];

  ProviderScope buildScreen(SharedPreferences prefs) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        marcoStateServiceProvider.overrideWith(
          (ref) => MarcoStateService(prefs),
        ),
        connectedDevicesProvider.overrideWith(
          (ref) async => (
            connection: RouterConnectionStatus(
              code: 'CONNECTED',
              message: 'Connected to MikroTik RouterOS API',
              reachable: true,
              routerName: 'Hospital Router',
              routerVersion: '7.47.8',
              checkedAt: checkedAt,
            ),
            devices: devices,
          ),
        ),
      ],
      child: const MaterialApp(home: ConnectedDevicesScreen()),
    );
  }

  testWidgets('renders RouterOS status and connected devices', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildScreen(prefs));
    await tester.pumpAndSettle();

    expect(find.text('Connected to MikroTik RouterOS API'), findsOneWidget);
    expect(find.textContaining('Hospital Router'), findsOneWidget);
    expect(find.text('2 devices'), findsOneWidget);
    expect(find.text('Nurse Station'), findsOneWidget);
    expect(find.text('Portable Scanner'), findsOneWidget);
    expect(find.text('ether5'), findsOneWidget);
    expect(find.text('ward-ap'), findsOneWidget);
  });

  testWidgets('search and connection filter update visible devices', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildScreen(prefs));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'scanner-01');
    await tester.pump();
    expect(find.text('Portable Scanner'), findsOneWidget);
    expect(find.text('Nurse Station'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('All Connections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LAN').last);
    await tester.pumpAndSettle();
    expect(find.text('Nurse Station'), findsOneWidget);
    expect(find.text('Portable Scanner'), findsNothing);
  });

  testWidgets('IP sorting direction changes row order', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildScreen(prefs));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('172.16.0.8')).dy,
      lessThan(tester.getTopLeft(find.text('172.16.0.20')).dy),
    );

    await tester.tap(find.byTooltip('Ascending'));
    await tester.pump();
    expect(
      tester.getTopLeft(find.text('172.16.0.20')).dy,
      lessThan(tester.getTopLeft(find.text('172.16.0.8')).dy),
    );
  });
}
