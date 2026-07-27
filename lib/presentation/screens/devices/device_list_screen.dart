import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device/device_provider.dart';
import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../widgets/common/search_input.dart';
import '../../widgets/common/status_badge.dart';
import '../../router/route_names.dart';
import '../../../domain/entities/device.dart';

const _infraTypes = [
  DeviceType.router,
  DeviceType.switch_,
  DeviceType.server,
  DeviceType.firewall,
  DeviceType.accessPoint,
  DeviceType.printer,
];

final _infraDeviceListProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final useCase = ref.watch(getDevicesUseCaseProvider);
  final result = await useCase(page: 1, limit: 200);
  return result.fold(
    (_) => <Device>[],
    (devices) => devices.where((d) => _infraTypes.any((t) => t.value == d.type.value)).toList(),
  );
});

class DeviceListScreen extends ConsumerWidget {
  const DeviceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(_infraDeviceListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_infraDeviceListProvider),
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load devices'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(_infraDeviceListProvider),
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
                  Icon(Icons.devices_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No infrastructure devices found', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Only Routers, Switches, Servers, Access Points, Firewalls, and Printers are shown.',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_infraDeviceListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                final statusColor = Color(device.status.colorValue);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(RouteNames.deviceDetail.replaceAll(':id', device.id)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_deviceIcon(device.type), color: statusColor, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(device.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(device.ipAddress, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'JetBrainsMono', color: theme.colorScheme.onSurfaceVariant)),
                                    if (device.hostname != null && device.hostname!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(device.hostname!, style: theme.textTheme.bodySmall),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  StatusBadge(label: device.status.label, color: statusColor),
                                  const SizedBox(height: 4),
                                  Text(device.type.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (device.currentUlSpeed != null || device.currentDlSpeed != null)
                                _chip(theme, Icons.swap_vert, '${(device.currentUlSpeed ?? 0) / 1000000 > 0 ? ((device.currentUlSpeed ?? 0) / 1000000).toStringAsFixed(1) : '0'} / ${(device.currentDlSpeed ?? 0) / 1000000 > 0 ? ((device.currentDlSpeed ?? 0) / 1000000).toStringAsFixed(1) : '0'} Mbps'),
                              if (device.osVersion != null && device.osVersion!.isNotEmpty)
                                _chip(theme, Icons.devices, device.osVersion!),
                              if (device.vendor != null && device.vendor!.isNotEmpty)
                                _chip(theme, Icons.business, device.vendor!),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.deviceCreate),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _chip(ThemeData theme, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }

  IconData _deviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.router: return Icons.router;
      case DeviceType.switch_: return Icons.lan;
      case DeviceType.server: return Icons.dns;
      case DeviceType.firewall: return Icons.security;
      case DeviceType.accessPoint: return Icons.wifi;
      case DeviceType.printer: return Icons.print;
      default: return Icons.devices_other;
    }
  }
}
