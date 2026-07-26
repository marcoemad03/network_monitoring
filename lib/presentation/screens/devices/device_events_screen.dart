import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/device/enterprise_providers.dart';
import '../../../domain/entities/device_event.dart';
import '../../../domain/entities/device_event_summary.dart';
import '../../../shared/extensions/datetime_extensions.dart';
import '../../../shared/widgets/app_card.dart';

class DeviceEventsScreen extends ConsumerStatefulWidget {
  final String deviceId;
  final String? deviceName;

  const DeviceEventsScreen({
    super.key,
    required this.deviceId,
    this.deviceName,
  });

  @override
  ConsumerState<DeviceEventsScreen> createState() => _DeviceEventsScreenState();
}

class _DeviceEventsScreenState extends ConsumerState<DeviceEventsScreen> {
  String? _selectedFilter;

  Future<void> _onRefresh() async {
    ref.invalidate(deviceEventsProvider((deviceId: widget.deviceId, eventType: _selectedFilter)));
    ref.invalidate(deviceEventSummaryProvider(widget.deviceId));
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(deviceEventsProvider((deviceId: widget.deviceId, eventType: _selectedFilter)));
    final summaryAsync = ref.watch(deviceEventSummaryProvider(widget.deviceId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Events'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {},
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryBar(summaryAsync),
              _buildFilterChips(),
              eventsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 12),
                        const Text('Failed to load events'),
                      ],
                    ),
                  ),
                ),
                data: (events) {
                  if (events.isEmpty) {
                    return _buildEmptyState();
                  }
                  return _buildEventList(events);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No events recorded',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBar(AsyncValue<DeviceEventSummary?> summaryAsync) {
    return summaryAsync.when(
      loading: () => const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary == null) return const SizedBox.shrink();
        return SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            children: [
              _summaryCard(
                  'Total', summary.totalEvents, Icons.event, Colors.blue),
              _summaryCard('Connections', summary.connectionEvents, Icons.link,
                  Colors.green),
              _summaryCard(
                  'Disconnections',
                  summary.disconnectionEvents,
                  Icons.link_off,
                  Colors.red),
              _summaryCard('Admin Actions', summary.adminActions,
                  Icons.admin_panel_settings, Colors.orange),
              _summaryCard(
                  'Blocks', summary.blockEvents, Icons.block, Colors.purple),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(
      String label, int count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: 110,
        child: AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: _eventTypes.map((type) {
          final isSelected = _selectedFilter == type.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(type.label),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedFilter = type.value);
                ref.invalidate(deviceEventsProvider((deviceId: widget.deviceId, eventType: _selectedFilter)));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEventList(List<DeviceEvent> events) {
    return Column(
      children: events.map((event) => _buildEventCard(event)).toList(),
    );
  }

  Widget _buildEventCard(DeviceEvent event) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor:
                    _eventColor(event.eventType).withValues(alpha: 0.1),
                child: Icon(
                  _eventIcon(event.eventType),
                  size: 20,
                  color: _eventColor(event.eventType),
                ),
              ),
              title: Text(
                _eventLabel(event.eventType),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                event.createdAt.timeAgo(),
                style: TextStyle(
                    fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            if (event.metadata.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text(
                  _metadataSummary(event.metadata, event.eventType),
                  style: TextStyle(
                      fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _metadataSummary(
      Map<String, dynamic> metadata, String eventType) {
    if (metadata.isEmpty) return '';
    switch (eventType) {
      case 'ip_change':
        final ip =
            metadata['ip'] ?? metadata['new_ip'] ?? metadata['address'];
        if (ip != null) return 'IP: $ip';
        break;
      case 'bandwidth_usage':
        final usage =
            metadata['usage'] ?? metadata['value'] ?? metadata['mbps'];
        if (usage != null) return 'Usage: $usage';
        break;
      case 'website_block':
        final url = metadata['url'] ?? metadata['domain'];
        if (url != null) return 'URL: $url';
        break;
    }
    final entry = metadata.entries.firstOrNull;
    if (entry != null) return '${entry.key}: ${entry.value}';
    return '';
  }

  IconData _eventIcon(String eventType) {
    switch (eventType) {
      case 'connection':
        return Icons.link;
      case 'disconnection':
        return Icons.link_off;
      case 'ip_change':
        return Icons.swap_horiz;
      case 'group_change':
        return Icons.group_work;
      case 'policy_change':
        return Icons.policy;
      case 'bandwidth_usage':
        return Icons.speed;
      case 'internet_block':
        return Icons.block;
      case 'website_block':
        return Icons.block;
      case 'admin_action':
        return Icons.admin_panel_settings;
      default:
        return Icons.info_outline;
    }
  }

  String _eventLabel(String eventType) {
    switch (eventType) {
      case 'connection':
        return 'Connected';
      case 'disconnection':
        return 'Disconnected';
      case 'ip_change':
        return 'IP Changed';
      case 'group_change':
        return 'Group Changed';
      case 'policy_change':
        return 'Policy Changed';
      case 'bandwidth_usage':
        return 'Bandwidth Alert';
      case 'internet_block':
        return 'Internet Blocked';
      case 'website_block':
        return 'Website Blocked';
      case 'admin_action':
        return 'Admin Action';
      default:
        return eventType;
    }
  }

  Color _eventColor(String eventType) {
    switch (eventType) {
      case 'connection':
        return Colors.green;
      case 'disconnection':
        return Colors.red;
      case 'ip_change':
        return Colors.orange;
      case 'group_change':
        return Colors.purple;
      case 'policy_change':
        return Colors.blue;
      case 'bandwidth_usage':
        return Colors.teal;
      case 'internet_block':
        return Colors.red;
      case 'website_block':
        return Colors.red;
      case 'admin_action':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}

const _eventTypes = [
  _EventType(null, 'All'),
  _EventType('connection', 'Connection'),
  _EventType('disconnection', 'Disconnection'),
  _EventType('ip_change', 'IP Change'),
  _EventType('group_change', 'Group Change'),
  _EventType('policy_change', 'Policy Change'),
  _EventType('bandwidth_usage', 'Bandwidth'),
  _EventType('block', 'Block'),
  _EventType('admin_action', 'Admin'),
];

class _EventType {
  final String? value;
  final String label;

  const _EventType(this.value, this.label);
}
