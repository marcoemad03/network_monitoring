import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device/device_provider.dart';
import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../widgets/common/search_input.dart';
import '../../widgets/common/status_badge.dart';
import '../../router/route_names.dart';

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(deviceFilterProvider);
    final devicesAsync = ref.watch(deviceListProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SearchInput(
              onChanged: (value) =>
                  ref.read(deviceFilterProvider.notifier).setSearch(value),
              hintText: 'Search by name, IP, or MAC...',
            ),
          ),
          Expanded(
            child: devicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load devices'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(deviceListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (devices) {
                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No devices found',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => context.push(RouteNames.deviceCreate),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Device'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(deviceListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final statusColor = Color(
                        device.status.colorValue,
                      );
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(
                            RouteNames.deviceDetail.replaceAll(':id', device.id),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getDeviceIcon(device.type),
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        device.name,
                                        style:
                                            theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        device.ipAddress,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontFamily: 'JetBrainsMono',
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      if (device.hostname != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          device.hostname!,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    StatusBadge(
                                      label: device.status.label,
                                      color: statusColor,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      device.type.label,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.deviceCreate),
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return Icons.router;
      case DeviceType.switch_:
        return Icons.lan;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.firewall:
        return Icons.security;
      case DeviceType.workstation:
        return Icons.desktop_windows;
      case DeviceType.printer:
        return Icons.print;
      case DeviceType.accessPoint:
        return Icons.wifi;
      case DeviceType.camera:
        return Icons.videocam;
      case DeviceType.phone:
        return Icons.phone;
      case DeviceType.iot:
        return Icons.sensors;
      default:
        return Icons.devices_other;
    }
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Devices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Status'),
              items: DeviceStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s.value,
                        child: Text(s.label),
                      ))
                  .toList(),
              onChanged: (v) =>
                  ref.read(deviceFilterProvider.notifier).setStatus(v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Type'),
              items: DeviceType.values
                  .map((t) => DropdownMenuItem(
                        value: t.value,
                        child: Text(t.label),
                      ))
                  .toList(),
              onChanged: (v) =>
                  ref.read(deviceFilterProvider.notifier).setType(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(deviceFilterProvider.notifier).reset();
              Navigator.of(ctx).pop();
            },
            child: const Text('Reset'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
