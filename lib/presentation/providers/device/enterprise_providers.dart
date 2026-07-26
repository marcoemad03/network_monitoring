import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/device_control_log.dart';
import '../../../domain/entities/device_event.dart';
import '../../../domain/entities/device_event_summary.dart';
import '../../../domain/entities/device_inventory.dart';
import 'device_provider.dart';

// Device Control
final deviceControlProvider = FutureProvider.autoDispose.family<void, ({String deviceId, String action, Map<String, dynamic>? params})>(
  (ref, args) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.controlDevice(args.deviceId, args.action, params: args.params);
    return result.fold((f) => throw Exception('Control failed: ${f.message}'), (r) => r);
  },
);

final deviceControlLogsProvider = FutureProvider.autoDispose.family<List<DeviceControlLog>, String>(
  (ref, deviceId) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.getDeviceControlLogs(deviceId);
    return result.fold((f) => [], (logs) => logs);
  },
);

// Device Events
final deviceEventsProvider = FutureProvider.autoDispose.family<List<DeviceEvent>, ({String deviceId, String? eventType})>(
  (ref, args) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.getDeviceEvents(args.deviceId, eventType: args.eventType);
    return result.fold((f) => [], (events) => events);
  },
);

final deviceEventSummaryProvider = FutureProvider.autoDispose.family<DeviceEventSummary?, String>(
  (ref, deviceId) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.getDeviceEventSummary(deviceId);
    return result.fold((f) => null, (s) => s);
  },
);

// Device Inventory
final deviceInventoryProvider = FutureProvider.autoDispose<List<DeviceInventory>>((ref) async {
  final repo = ref.watch(deviceRepositoryProvider);
  final result = await repo.getDeviceInventory(limit: 200);
  return result.fold((f) => [], (list) => list);
});

// Discovery
final discoverDevicesProvider = FutureProvider.autoDispose.family<List<DeviceInventory>, String>(
  (ref, vendorId) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.discoverDevices172(vendorId);
    return result.fold((f) => [], (devices) => devices);
  },
);
