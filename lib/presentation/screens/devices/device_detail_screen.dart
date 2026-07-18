import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/device/device_provider.dart';
import '../../widgets/common/status_badge.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../core/enums/device_type.dart';
import '../../router/route_names.dart';
import '../../../domain/entities/device.dart';
import '../../../domain/entities/device_metrics.dart';
import '../../../domain/entities/device_client.dart';

class DeviceDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const DeviceDetailScreen({super.key, required this.id});

  @override
  ConsumerState<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends ConsumerState<DeviceDetailScreen> {
  bool _listenerAttached = false;

  @override
  Widget build(BuildContext context) {
    final deviceAsync = ref.watch(deviceDetailProvider(widget.id));

    if (!_listenerAttached) {
      _listenerAttached = true;
      ref.listen<AsyncValue<Map<String, dynamic>>>(deviceUpdateStreamProvider, (_, next) {
        next.whenOrNull(data: (data) {
          if (data['device_id'] == widget.id) {
            ref.invalidate(deviceDetailProvider(widget.id));
            ref.invalidate(deviceClientsProvider(widget.id));
          }
        });
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push(
              RouteNames.deviceEdit.replaceAll(':id', widget.id),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(deviceDetailProvider(widget.id));
              ref.invalidate(deviceClientsProvider(widget.id));
            },
          ),
        ],
      ),
      body: deviceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          message: 'Failed to load device',
          onRetry: () => ref.invalidate(deviceDetailProvider(widget.id)),
        ),
        data: (device) {
          if (device == null) {
            return const Center(child: Text('Device not found'));
          }
          return _DeviceDetailContent(device: device, deviceId: widget.id);
        },
      ),
    );
  }
}

class _DeviceDetailContent extends ConsumerWidget {
  final Device device;
  final String deviceId;

  const _DeviceDetailContent({required this.device, required this.deviceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = Color(device.status.colorValue);
    final metricsAsync = ref.watch(_deviceLatestMetricsProvider(deviceId));
    final clientsAsync = ref.watch(deviceClientsProvider(deviceId));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, statusColor),
          const SizedBox(height: 16),
          _buildMetricGauges(theme, metricsAsync),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildNetworkInfo(theme)),
              const SizedBox(width: 12),
              Expanded(child: _buildHardwareInfo(theme)),
            ],
          ),
          const SizedBox(height: 16),
          _buildPingLatencySection(theme, metricsAsync),
          const SizedBox(height: 16),
          _buildTrafficSection(theme),
          const SizedBox(height: 16),
          _buildClientsSection(theme, clientsAsync),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Color statusColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _deviceIcon(device.type), color: statusColor, size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(device.ipAddress,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: theme.colorScheme.onSurfaceVariant,
                      )),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      StatusBadge(label: device.status.label, color: statusColor),
                      const SizedBox(width: 8),
                      StatusBadge(label: device.type.label,
                          color: theme.colorScheme.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGauges(
      ThemeData theme, AsyncValue<DeviceMetrics?> metricsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Live Metrics',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            metricsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text('Metrics unavailable',
                  style: theme.textTheme.bodySmall),
              data: (metrics) {
                if (metrics == null) return Text('No metrics available',
                    style: theme.textTheme.bodySmall);
                return Row(
                  children: [
                    _gauge(theme, 'CPU', metrics.cpuUsagePercent, Icons.memory,
                        Colors.blue),
                    const SizedBox(width: 12),
                    _gauge(theme, 'Memory', metrics.memoryUsagePercent,
                        Icons.storage, Colors.green),
                    const SizedBox(width: 12),
                    _gauge(theme, 'Disk', metrics.diskUsagePercent,
                        Icons.disc_full, Colors.orange),
                    const SizedBox(width: 12),
                    _gauge(theme, 'Latency', metrics.averageLatencyMs,
                        Icons.timer, Colors.purple),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _gauge(ThemeData theme, String label, double? value, IconData icon,
      Color color) {
    final displayValue = value ?? 0;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text('${displayValue.toStringAsFixed(1)}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Network', style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
            _infoRow('IP Address', device.ipAddress),
            _infoRow('MAC Address', device.macAddress ?? 'N/A'),
            _infoRow('Hostname', device.hostname ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildHardwareInfo(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hardware', style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
            const SizedBox(height: 12),
            _infoRow('Vendor', device.vendor ?? 'N/A'),
            _infoRow('Model', device.model ?? 'N/A'),
            _infoRow('OS', device.osVersion ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildPingLatencySection(
      ThemeData theme, AsyncValue<DeviceMetrics?> metricsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ping & Latency',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            metricsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text('Ping data unavailable'),
              data: (metrics) {
                if (metrics == null) return Text('No ping data');
                final lossColor = metrics.packetLossPercent != null &&
                        metrics.packetLossPercent! > 5
                    ? Colors.red
                    : Colors.green;
                return Row(
                  children: [
                    _pingStat(theme, 'Avg Latency',
                        '${metrics.averageLatencyMs?.toStringAsFixed(1) ?? "N/A"} ms',
                        Colors.purple),
                    const SizedBox(width: 12),
                    _pingStat(theme, 'Max Latency',
                        '${metrics.maxLatencyMs?.toStringAsFixed(1) ?? "N/A"} ms',
                        Colors.orange),
                    const SizedBox(width: 12),
                    _pingStat(theme, 'Packet Loss',
                        '${metrics.packetLossPercent?.toStringAsFixed(1) ?? "N/A"}%',
                        lossColor),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _pingStat(
      ThemeData theme, String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Traffic',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1000,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(
                          ['', 'Upload', '', 'Download', ''][v.toInt()],
                          style: const TextStyle(fontSize: 10)),
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30,
                        getTitlesWidget: (v, _) => Text('${v.toInt()}M',
                            style: const TextStyle(fontSize: 10))),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(toY: 200, color: Colors.green, width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(toY: 500, color: Colors.blue, width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    ]),
                  ],
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 250),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientsSection(
      ThemeData theme, AsyncValue<List<DeviceClient>> clientsAsync) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connected Clients',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Text('Clients unavailable'),
              data: (clients) {
                if (clients.isEmpty) {
                  return Text('No connected clients',
                      style: theme.textTheme.bodySmall);
                }
                return Column(
                  children: clients.take(5).map((client) {
                    final signalColor = client.signalStrengthDbm != null
                        ? (client.signalStrengthDbm! >= -60
                            ? Colors.green
                            : client.signalStrengthDbm! >= -75
                                ? Colors.orange
                                : Colors.red)
                        : Colors.grey;
                    return ListTile(
                      dense: true,
                      leading: Icon(_clientIcon(client.connectionType),
                          color: signalColor, size: 20),
                      title: Text(client.hostname ?? client.macAddress,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '${client.ipAddress ?? "N/A"}  •  ${client.vendor ?? "Unknown"}',
                        style: const TextStyle(fontSize: 11)),
                      trailing: client.signalStrengthDbm != null
                          ? Text('${client.signalStrengthDbm} dBm',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: signalColor,
                                  fontWeight: FontWeight.w500))
                          : null,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _deviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.router: return Icons.router;
      case DeviceType.switch_: return Icons.lan;
      case DeviceType.server: return Icons.dns;
      case DeviceType.firewall: return Icons.security;
      case DeviceType.workstation: return Icons.desktop_windows;
      case DeviceType.printer: return Icons.print;
      case DeviceType.accessPoint: return Icons.wifi;
      case DeviceType.camera: return Icons.videocam;
      case DeviceType.phone: return Icons.phone;
      case DeviceType.iot: return Icons.sensors;
      default: return Icons.devices_other;
    }
  }

  IconData _clientIcon(String connectionType) {
    switch (connectionType) {
      case 'wifi': return Icons.wifi;
      case 'ethernet': return Icons.lan;
      default: return Icons.devices;
    }
  }
}

final _deviceLatestMetricsProvider =
    FutureProvider.autoDispose.family<DeviceMetrics?, String>((ref, id) async {
  final repo = ref.watch(deviceRepositoryProvider);
  final result = await repo.getLatestMetrics(id);
  return result.fold((_) => null, (m) => m);
});
