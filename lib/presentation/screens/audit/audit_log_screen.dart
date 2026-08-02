import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/di/injection_container.dart';

class _AuditEntry {
  final String id;
  final String action;
  final String entityType;
  final String? entityName;
  final String? performedBy;
  final DateTime timestamp;
  final bool isSuccess;
  final String? description;

  const _AuditEntry({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityName,
    this.performedBy,
    required this.timestamp,
    this.isSuccess = true,
    this.description,
  });

  factory _AuditEntry.fromJson(Map<String, dynamic> json) => _AuditEntry(
        id: json['id'] as String,
        action: json['action'] as String? ?? 'other',
        entityType: json['entity_type'] as String? ?? 'system',
        entityName: json['entity_name'] as String?,
        performedBy: json['performed_by_name'] as String? ?? json['performed_by'] as String?,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isSuccess: json['is_success'] as bool? ?? true,
        description: json['description'] as String?,
      );
}

final _auditLogsProvider = FutureProvider.family<List<_AuditEntry>, _AuditLogFilter>((ref, filter) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiConstants.auditLogs,
    queryParameters: {
      'page': filter.page,
      'limit': filter.limit,
      if (filter.action != null) 'action': filter.action,
      if (filter.entityType != null) 'entity_type': filter.entityType,
    },
  );
  final data = response.data['data'] as List;
  return data.map((e) => _AuditEntry.fromJson(e as Map<String, dynamic>)).toList();
});

class _AuditLogFilter {
  final int page;
  final int limit;
  final String? action;
  final String? entityType;

  const _AuditLogFilter({
    this.page = 1,
    this.limit = 50,
    this.action,
    this.entityType,
  });
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String? _actionFilter;
  String? _entityFilter;
  int _page = 1;

  @override
  Widget build(BuildContext context) {
    final filter = _AuditLogFilter(page: _page, action: _actionFilter, entityType: _entityFilter);
    final logsAsync = ref.watch(_auditLogsProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(icon: const Icon(Icons.file_download), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(_auditLogsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: theme.colorScheme.surfaceContainerLow,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Action',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    value: _actionFilter,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Actions')),
                      DropdownMenuItem(value: 'login', child: Text('Login')),
                      DropdownMenuItem(value: 'logout', child: Text('Logout')),
                      DropdownMenuItem(value: 'create', child: Text('Create')),
                      DropdownMenuItem(value: 'update', child: Text('Update')),
                      DropdownMenuItem(value: 'delete', child: Text('Delete')),
                      DropdownMenuItem(value: 'permission_change', child: Text('Permission')),
                    ],
                    onChanged: (v) => setState(() {
                      _actionFilter = v;
                      _page = 1;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Entity',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    value: _entityFilter,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All Entities')),
                      DropdownMenuItem(value: 'user', child: Text('User')),
                      DropdownMenuItem(value: 'device', child: Text('Device')),
                      DropdownMenuItem(value: 'alert', child: Text('Alert')),
                      DropdownMenuItem(value: 'configuration', child: Text('Configuration')),
                    ],
                    onChanged: (v) => setState(() {
                      _entityFilter = v;
                      _page = 1;
                    }),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: logsAsync.when(
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No audit logs found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _AuditLogTile(log: logs[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final _AuditEntry log;

  const _AuditLogTile({required this.log});

  IconData _actionIcon(String action) {
    switch (action) {
      case 'login':
        return Icons.login;
      case 'logout':
        return Icons.logout;
      case 'create':
        return Icons.add_circle;
      case 'update':
        return Icons.edit;
      case 'delete':
        return Icons.delete;
      case 'permission_change':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _actionColor(String action, ThemeData theme) {
    switch (action) {
      case 'create':
        return Colors.green;
      case 'delete':
        return Colors.red;
      case 'update':
        return Colors.orange;
      case 'login':
        return theme.colorScheme.primary;
      case 'logout':
        return Colors.grey;
      case 'permission_change':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _actionColor(log.action, theme).withValues(alpha: 0.15),
          child: Icon(_actionIcon(log.action), size: 18, color: _actionColor(log.action, theme)),
        ),
        title: Text(
          '${log.action.toUpperCase()}  ${log.entityType}${log.entityName != null ? ' — ${log.entityName}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${log.performedBy ?? 'System'}  •  ${_formatTimestamp(log.timestamp)}',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(
          log.isSuccess ? Icons.check_circle : Icons.error,
          size: 16,
          color: log.isSuccess ? Colors.green : Colors.red,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
