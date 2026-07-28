import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';
import '../../../domain/entities/dashboard_live.dart';
import '../../../core/network/websocket_client.dart';

class _TrafficSample {
  final double uploadMbps;
  final double downloadMbps;
  final DateTime time;
  const _TrafficSample(this.uploadMbps, this.downloadMbps, this.time);
}

final _trafficSamplesProvider = StateNotifierProvider<_TrafficStore, List<_TrafficSample>>(
  (_) => _TrafficStore(),
);

class _TrafficStore extends StateNotifier<List<_TrafficSample>> {
  _TrafficStore() : super([]);

  void add(double upload, double download) {
    state = [...state, _TrafficSample(upload, download, DateTime.now())].take(60).toList();
  }

  double get peakUpload {
    if (state.isEmpty) return 0;
    return state.map((s) => s.uploadMbps).reduce((a, b) => a > b ? a : b);
  }

  double get peakDownload {
    if (state.isEmpty) return 0;
    return state.map((s) => s.downloadMbps).reduce((a, b) => a > b ? a : b);
  }

  double get avgUpload {
    if (state.isEmpty) return 0;
    return state.map((s) => s.uploadMbps).reduce((a, b) => a + b) / state.length;
  }

  double get avgDownload {
    if (state.isEmpty) return 0;
    return state.map((s) => s.downloadMbps).reduce((a, b) => a + b) / state.length;
  }
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final wsState = ref.watch(wsConnectionStateProvider);
    final theme = Theme.of(context);

    ref.listen(dashboardSummaryProvider, (_, next) {
      next.whenData((summary) {
        if (summary != null) {
          ref.read(_trafficSamplesProvider.notifier).add(summary.totalUploadMbps, summary.totalDownloadMbps);
        }
      });
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Tooltip(
              message: switch (wsState) {
                WebSocketState.connected => 'Live',
                WebSocketState.connecting => 'Connecting...',
                WebSocketState.reconnecting => 'Reconnecting...',
                WebSocketState.disconnected => 'Offline',
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: switch (wsState) {
                        WebSocketState.connected => Colors.green,
                        WebSocketState.connecting => Colors.orange,
                        WebSocketState.reconnecting => Colors.orange,
                        WebSocketState.disconnected => Colors.grey,
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    switch (wsState) {
                      WebSocketState.connected => 'Live',
                      WebSocketState.connecting => '...',
                      WebSocketState.reconnecting => '...',
                      WebSocketState.disconnected => '',
                    },
                    style: TextStyle(
                      fontSize: 11,
                      color: switch (wsState) {
                        WebSocketState.connected => Colors.green.shade300,
                        _ => Colors.grey,
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardSummaryProvider),
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Network Map',
            onPressed: () => context.go(RouteNames.networkMap),
          ),
        ],
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text(e.toString().replaceFirst('Exception: ', ''), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(dashboardSummaryProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (summary) {
          if (summary == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text('Unable to load dashboard', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(dashboardSummaryProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return _DashboardBody(summary: summary);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardLive summary;
  const _DashboardBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusBar(theme),
          const SizedBox(height: 20),
          _buildMetricRow(theme),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildTrafficChart(theme)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildDeviceDistribution(theme)),
            ],
          ),
          const SizedBox(height: 20),
          _buildTrafficMetricsRow(theme),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: _buildAlertSummary(context, theme)),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: _buildQuickActions(context, theme)),
            ],
          ),
          const SizedBox(height: 20),
          _buildDeviceTypeBreakdown(theme),
        ],
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primaryContainer, theme.colorScheme.primaryContainer.withValues(alpha: 0.3)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Network Status', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '${summary.onlineDevices} of ${summary.totalDevices} devices online',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _statusChip(theme, 'Online', summary.onlineDevices, Colors.green),
          const SizedBox(width: 8),
          _statusChip(theme, 'Offline', summary.offlineDevices, Colors.red),
          const SizedBox(width: 8),
          _statusChip(theme, 'Degraded', summary.degradedDevices, Colors.orange),
        ],
      ),
    );
  }

  Widget _statusChip(ThemeData theme, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(count.toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildMetricRow(ThemeData theme) {
    return Row(
      children: [
        _metricCard(theme, Icons.devices, 'Total Devices', summary.totalDevices, theme.colorScheme.primary),
        const SizedBox(width: 12),
        _metricCard(theme, Icons.people, 'Active Clients', summary.activeClients, Colors.teal),
        const SizedBox(width: 12),
        _metricCard(theme, Icons.warning, 'Critical Alerts', summary.criticalAlerts, Colors.red),
        const SizedBox(width: 12),
        _metricCard(
          theme,
          Icons.speed,
          'Network Load',
          '${summary.totalUploadMbps.toStringAsFixed(1)} / ${summary.totalDownloadMbps.toStringAsFixed(1)} Mbps',
          Colors.indigo,
        ),
      ],
    );
  }

  Widget _metricCard(ThemeData theme, IconData icon, String label, dynamic value, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
              ]),
              const SizedBox(height: 12),
              Text(value.toString(), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrafficChart(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Real-Time Traffic', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                Row(children: [
                  _legendDot(Colors.green, 'Upload'),
                  const SizedBox(width: 12),
                  _legendDot(Colors.blue, 'Download'),
                ]),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (summary.totalUploadMbps > summary.totalDownloadMbps
                          ? summary.totalUploadMbps
                          : summary.totalDownloadMbps) *
                      1.3,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = rodIndex == 0 ? 'Upload' : 'Download';
                        return BarTooltipItem('$label\n${rod.toY.toStringAsFixed(2)} Mbps', const TextStyle());
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (v, _) => Text(['Upload', 'Download'][v.toInt()], style: const TextStyle(fontSize: 10)),
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text('${v.toInt()} Mbps', style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (summary.totalUploadMbps > 0 || summary.totalDownloadMbps > 0)
                        ? ((summary.totalUploadMbps > summary.totalDownloadMbps
                                    ? summary.totalUploadMbps
                                    : summary.totalDownloadMbps) *
                                1.3 /
                                4)
                            .clamp(1, double.infinity)
                        : 100,
                  ),
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: summary.totalUploadMbps,
                        color: Colors.green,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: summary.totalDownloadMbps,
                        color: Colors.blue,
                        width: 28,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildTrafficMetricsRow(ThemeData theme) {
    return _TrafficMetricsSection(summary: summary, theme: theme);
  }

  Widget _buildDeviceDistribution(ThemeData theme) {
    final total = summary.totalDevices;
    final online = summary.onlineDevices;
    final offline = summary.offlineDevices;
    final degraded = summary.degradedDevices;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                  sections: [
                    PieChartSectionData(
                      value: online.toDouble(),
                      color: Colors.green,
                      radius: 30,
                      title: '${(total > 0 ? (online / total * 100) : 0).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: offline.toDouble(),
                      color: Colors.red,
                      radius: 25,
                      title: '${(total > 0 ? (offline / total * 100) : 0).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    PieChartSectionData(
                      value: degraded.toDouble(),
                      color: Colors.orange,
                      radius: 25,
                      title: '${(total > 0 ? (degraded / total * 100) : 0).toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _smallDot(Colors.green, 'Online'),
                const SizedBox(width: 12),
                _smallDot(Colors.red, 'Offline'),
                const SizedBox(width: 12),
                _smallDot(Colors.orange, 'Degraded'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _smallDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _buildAlertSummary(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Alert Summary', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  onPressed: () => context.go(RouteNames.alerts),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _alertRow(theme, 'Critical', summary.criticalAlerts, Colors.red),
            const SizedBox(height: 8),
            _alertRow(theme, 'Open', summary.openAlerts, Colors.orange),
            const SizedBox(height: 8),
            _alertRow(theme, 'Active Clients', summary.activeClients, Colors.teal),
          ],
        ),
      ),
    );
  }

  Widget _alertRow(ThemeData theme, String label, int count, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(count.toString(), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Actions', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionButton(theme, Icons.add, 'Add Device', () => context.push(RouteNames.deviceCreate)),
                const SizedBox(width: 8),
                _actionButton(theme, Icons.wifi_tethering, 'Scan', () => context.go(RouteNames.networkScan)),
                const SizedBox(width: 8),
                _actionButton(theme, Icons.map, 'Map', () => context.go(RouteNames.networkMap)),
                const SizedBox(width: 8),
                _actionButton(theme, Icons.devices, 'Devices', () => context.go(RouteNames.devices)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(ThemeData theme, IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: Border.all(color: theme.colorScheme.outlineVariant), borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 24),
              const SizedBox(height: 4),
              Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTypeBreakdown(ThemeData theme) {
    if (summary.devicesByType.isEmpty) return const SizedBox.shrink();
    final typeColors = {
      'router': Colors.blue,
      'switch': Colors.teal,
      'server': Colors.purple,
      'firewall': Colors.red,
      'workstation': Colors.orange,
      'printer': Colors.brown,
      'access_point': Colors.indigo,
      'camera': Colors.cyan,
      'phone': Colors.pink,
      'iot': Colors.amber,
      'medical_device': Colors.deepOrange,
    };
    final sortedTypes = summary.devicesByType.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Device Type Breakdown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...sortedTypes.map((entry) {
              final color = typeColors[entry.key] ?? theme.colorScheme.primary;
              final pct = summary.totalDevices > 0 ? (entry.value / summary.totalDevices * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: Text(entry.key.replaceAll('_', ' ').toUpperCase(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          backgroundColor: color.withValues(alpha: 0.1),
                          color: color,
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 30,
                      child: Text(entry.value.toString(), style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TrafficMetricsSection extends ConsumerWidget {
  final DashboardLive summary;
  final ThemeData theme;
  const _TrafficMetricsSection({required this.summary, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final samples = ref.watch(_trafficSamplesProvider);
    final peakUp = samples.isEmpty ? summary.totalUploadMbps : samples.map((s) => s.uploadMbps).reduce((a, b) => a > b ? a : b);
    final peakDown = samples.isEmpty ? summary.totalDownloadMbps : samples.map((s) => s.downloadMbps).reduce((a, b) => a > b ? a : b);
    final avgUp = samples.isEmpty ? summary.totalUploadMbps : samples.map((s) => s.uploadMbps).reduce((a, b) => a + b) / samples.length;
    final avgDown = samples.isEmpty ? summary.totalDownloadMbps : samples.map((s) => s.downloadMbps).reduce((a, b) => a + b) / samples.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Traffic Details', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24, runSpacing: 12,
              children: [
                _trafficMetric(Icons.speed, 'Current Upload', '${summary.totalUploadMbps.toStringAsFixed(2)} Mbps', Colors.green),
                _trafficMetric(Icons.speed, 'Current Download', '${summary.totalDownloadMbps.toStringAsFixed(2)} Mbps', Colors.blue),
                _trafficMetric(Icons.trending_up, 'Peak Upload', '${peakUp.toStringAsFixed(2)} Mbps', Colors.green.shade700),
                _trafficMetric(Icons.trending_up, 'Peak Download', '${peakDown.toStringAsFixed(2)} Mbps', Colors.blue.shade700),
                _trafficMetric(Icons.analytics, 'Avg Upload', '${avgUp.toStringAsFixed(2)} Mbps', Colors.green.shade300),
                _trafficMetric(Icons.analytics, 'Avg Download', '${avgDown.toStringAsFixed(2)} Mbps', Colors.blue.shade300),
                _trafficMetric(Icons.router, 'Router Throughput', '${(summary.totalUploadMbps + summary.totalDownloadMbps).toStringAsFixed(2)} Mbps', Colors.indigo),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _trafficMetric(IconData icon, String label, String value, Color color) {
    return SizedBox(
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              Text(value, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
