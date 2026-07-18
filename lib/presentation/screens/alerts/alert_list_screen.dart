import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/alert/alert_provider.dart';
import '../../widgets/common/status_badge.dart';
import '../../../core/enums/alert_severity.dart';
import '../../../core/utils/date_formatters.dart';
import '../../router/route_names.dart';
import '../../../domain/entities/alert.dart';

class AlertListScreen extends ConsumerWidget {
  const AlertListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(alertFilterProvider);
    final alertsAsync = ref.watch(alertListProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertListProvider),
          ),
        ],
      ),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load alerts'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(alertListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text('No alerts', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('All systems are operating normally',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(alertListProvider),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final severityColor = Color(alert.severity.colorValue);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push(
                      RouteNames.alertDetail.replaceAll(':id', alert.id),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: severityColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  alert.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (alert.description != null)
                                  Text(
                                    alert.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    StatusBadge(
                                      label: alert.severity.label,
                                      color: severityColor,
                                    ),
                                    const SizedBox(width: 8),
                                    StatusBadge(
                                      label: _statusLabel(alert.status),
                                      color: _statusColor(alert.status),
                                      filled: false,
                                    ),
                                    const Spacer(),
                                    Text(
                                      DateFormatters.timeAgo(alert.detectedAt),
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                if (alert.deviceName != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    alert.deviceName!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 20),
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
    );
  }

  String _statusLabel(AlertStatus status) {
    switch (status) {
      case AlertStatus.open:
        return 'Open';
      case AlertStatus.acknowledged:
        return 'Acknowledged';
      case AlertStatus.resolved:
        return 'Resolved';
      case AlertStatus.suppressed:
        return 'Suppressed';
    }
  }

  Color _statusColor(AlertStatus status) {
    switch (status) {
      case AlertStatus.open:
        return Colors.red;
      case AlertStatus.acknowledged:
        return Colors.orange;
      case AlertStatus.resolved:
        return Colors.green;
      case AlertStatus.suppressed:
        return Colors.grey;
    }
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Alerts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Severity'),
              items: AlertSeverity.values
                  .map((s) => DropdownMenuItem(
                        value: s.value,
                        child: Text(s.label),
                      ))
                  .toList(),
              onChanged: (v) =>
                  ref.read(alertFilterProvider.notifier).setSeverity(v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Status'),
              items: ['open', 'acknowledged', 'resolved']
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s[0].toUpperCase() + s.substring(1)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  ref.read(alertFilterProvider.notifier).setStatus(v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(alertFilterProvider.notifier).reset();
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
