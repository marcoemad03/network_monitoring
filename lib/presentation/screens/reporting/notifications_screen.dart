import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/marco_state_service.dart';
import '../../providers/device/device_provider.dart';
import '../../providers/reporting/reporting_provider.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../shared/extensions/datetime_extensions.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount.valueOrNull != null && unreadCount.value! > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text('${unreadCount.value} unread'),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == 'all',
                  onSelected: () => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Unread',
                  selected: _filter == 'unread',
                  onSelected: () => setState(() => _filter = 'unread'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Acknowledged',
                  selected: _filter == 'acknowledged',
                  onSelected: () => setState(() => _filter = 'acknowledged'),
                ),
              ],
            ),
          ),
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => AppErrorWidget(
                message: 'Failed to load notifications',
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
              data: (notifications) {
                final localNotifications = ref.read(marcoStateServiceProvider).notifications;
                final filtered = notifications.where((n) {
                  if (_filter == 'unread') return !n.isRead;
                  if (_filter == 'acknowledged') return n.acknowledgedAt != null;
                  return true;
                }).toList();

                if (filtered.isEmpty && localNotifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          _filter == 'all' ? 'No notifications' : 'No $_filter notifications',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  );
                }
                if (filtered.isEmpty && localNotifications.isNotEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: localNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = localNotifications[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(_iconForType(notification.type), color: _colorForType(notification.type)),
                          title: Text(notification.title),
                          subtitle: Text(notification.message),
                          trailing: Text(notification.createdAt.timeAgo()),
                        ),
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final notification = filtered[index];
                    final severityColor = _severityColor(notification.severity);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (!notification.isRead) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notification marked locally as read')),
                            );
                          }
                        },
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
                                  color: notification.isRead ? Colors.grey : severityColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notification.title,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notification.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _SeverityBadge(label: notification.severity, color: severityColor),
                                        const Spacer(),
                                        Text(
                                          notification.triggeredAt.timeAgo(),
                                          style: theme.textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (notification.acknowledgedAt == null)
                                TextButton(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Acknowledged locally')),
                                    );
                                  },
                                  child: const Text('Ack'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'device_connected':
      case 'group_assignment':
        return Colors.green;
      case 'device_disconnected':
      case 'internet_blocked':
        return Colors.red;
      case 'pin_device':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'device_connected':
        return Icons.wifi;
      case 'device_disconnected':
        return Icons.wifi_off;
      case 'internet_blocked':
        return Icons.block;
      case 'pin_device':
        return Icons.push_pin;
      case 'group_assignment':
        return Icons.group;
      default:
        return Icons.notifications;
    }
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }


}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}
