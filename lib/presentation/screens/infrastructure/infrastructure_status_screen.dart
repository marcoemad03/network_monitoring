import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/backend_config.dart';
import '../../../core/network/health_check_service.dart';

final backendConfigProvider = FutureProvider<BackendConfig>((ref) {
  return BackendConfig.load();
});

final healthStatusProvider = StateNotifierProvider<HealthStatusNotifier, AsyncValue<HealthStatus>>((ref) {
  return HealthStatusNotifier();
});

class HealthStatusNotifier extends StateNotifier<AsyncValue<HealthStatus>> {
  HealthCheckService? _service;

  HealthStatusNotifier() : super(const AsyncValue.loading());

  void init(BackendConfig config) {
    _service = HealthCheckService(config);
    _service!.statusStream.listen((status) {
      state = AsyncValue.data(status);
    });
    check();
  }

  Future<void> check() async {
    if (_service == null) return;
    state = const AsyncValue.loading();
    final status = await _service!.check();
    state = AsyncValue.data(status);
  }

  @override
  void dispose() {
    _service?.stop();
    super.dispose();
  }
}

class InfrastructureStatusScreen extends ConsumerWidget {
  const InfrastructureStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(backendConfigProvider);
    final healthAsync = ref.watch(healthStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Infrastructure Status'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(healthStatusProvider.notifier).check(),
          ),
        ],
      ),
      body: configAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load config: $err')),
        data: (config) {
          return RefreshIndicator(
            onRefresh: () => ref.read(healthStatusProvider.notifier).check(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildBackendConfigSection(context, config),
                const SizedBox(height: 16),
                healthAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (err, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error: $err'),
                        ],
                      ),
                    ),
                  ),
                  data: (health) => _buildHealthStatusSection(context, config, health),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackendConfigSection(BuildContext context, BackendConfig config) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Backend Configuration', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow('Backend URL', config.baseUrl),
            _buildInfoRow('Backend Port', config.port.toString()),
            _buildInfoRow('Health Check Interval', '${config.healthCheckIntervalSeconds}s'),
            _buildInfoRow('Connection Timeout', '${config.connectionTimeoutMs}ms'),
            _buildInfoRow('Auto-Start Backend', config.autoStartBackend ? 'Enabled' : 'Disabled'),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthStatusSection(BuildContext context, BackendConfig config, HealthStatus health) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Backend Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    _buildStatusBadge(health),
                  ],
                ),
                const Divider(),
                _buildInfoRow('Response Time', health.responseTimeMs != null ? '${health.responseTimeMs}ms' : 'N/A'),
                _buildInfoRow('Last Checked', _formatDateTime(health.lastChecked)),
              ],
            ),
          ),
        ),
        if (health.errorReason != null) ...[
          const SizedBox(height: 16),
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Text('Connection Issue', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.error)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(health.errorReason!, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  if (health.errorDetail != null) ...[
                    const SizedBox(height: 4),
                    SelectableText(health.errorDetail!, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Service Status', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Divider(),
                _buildServiceRow('Server', health.server),
                _buildServiceRow('Database', health.database),
                _buildServiceRow('MikroTik', health.mikrotik),
                if (health.routerIP != null) _buildInfoRow('Router IP', health.routerIP!),
                if (health.version != null) _buildInfoRow('Backend Version', health.version!),
                if (health.uptime != null) _buildInfoRow('Backend Uptime', health.uptime!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(HealthStatus health) {
    final (Color color, String label) = switch (health.status) {
      BackendStatus.connected => (Colors.green, 'Connected'),
      BackendStatus.degraded => (Colors.orange, 'Degraded'),
      BackendStatus.disconnected => (Colors.red, 'Disconnected'),
      BackendStatus.unknown => (Colors.grey, 'Unknown'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRow(String label, String? status) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          if (status != null)
            Row(
              children: [
                Icon(
                  status == 'connected' || status == 'running' || status == 'ok'
                      ? Icons.check_circle
                      : status == 'degraded'
                          ? Icons.warning
                          : Icons.error,
                  size: 16,
                  color: status == 'connected' || status == 'running' || status == 'ok'
                      ? Colors.green
                      : status == 'degraded'
                          ? Colors.orange
                          : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(status, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
              ],
            )
          else
            const Text('N/A', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
