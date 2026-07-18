import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';

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
                    onPressed: () => ref.invalidate(notificationsProvider),
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
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load notifications'),
                    const SizedBox(height: 8),
                    OutlinedButton(
            onPressed: () => ref.invalidate(notificationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (notifications) {
                final filtered = notifications.where((n) {
                  if (_filter == 'unread') return !n.isRead;
                  if (_filter == 'acknowledged') return n.acknowledgedAt != null;
                  return true;
                }).toList();

                if (filtered.isEmpty) {
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
                              const SnackBar(content: Text('Mark as read requires backend connection')),
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
                                          _formatTimestamp(notification.triggeredAt),
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
                                      const SnackBar(content: Text('Acknowledge requires backend connection')),
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

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
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
