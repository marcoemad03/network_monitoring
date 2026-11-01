import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/marco_models.dart';
import '../../providers/marco/marco_provider.dart';
import '../../router/route_names.dart';

class MarcoGroupsScreen extends ConsumerStatefulWidget {
  const MarcoGroupsScreen({super.key});

  @override
  ConsumerState<MarcoGroupsScreen> createState() => _MarcoGroupsScreenState();
}

class _MarcoGroupsScreenState extends ConsumerState<MarcoGroupsScreen> {
  bool _previewing = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(marcoGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marco Groups'),
        actions: [
          IconButton(
            tooltip: 'Preview router changes',
            icon: _previewing
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.fact_check_outlined),
            onPressed: _previewing ? null : _previewSync,
          ),
          IconButton(
            tooltip: 'Policy log',
            icon: const Icon(Icons.history),
            onPressed: _showLogs,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(marcoGroupsProvider.notifier).refresh(),
          ),
          IconButton(
            tooltip: 'Create group',
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.read(marcoGroupsProvider.notifier).refresh(),
        ),
        data: (result) => Column(
          children: [
            if (result.dryRun) const _DryRunBanner(),
            Expanded(
              child: result.groups.isEmpty
                  ? _EmptyView(onCreate: _createGroup)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: result.groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _GroupCard(
                        group: result.groups[index],
                        onOpen: () => context.push(RouteNames.marcoGroupDetail(result.groups[index].id)),
                        onEdit: () => _editGroup(result.groups[index]),
                        onDelete: () => _deleteGroup(result.groups[index]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _previewSync() async {
    setState(() => _previewing = true);
    try {
      final preview = await ref.read(marcoRemoteProvider).sync();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(preview.dryRun ? 'Router plan (dry-run)' : 'Router synchronized'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(preview.message),
                  const SizedBox(height: 12),
                  Text('${preview.plannedChanges.length} router change(s) planned',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  for (final change in preview.plannedChanges.take(60))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(change, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11)),
                    ),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Warnings', style: Theme.of(ctx).textTheme.titleSmall),
                    for (final warning in preview.warnings)
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $warning')),
                  ],
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
        ),
      );
    } catch (e) {
      _toast('Preview failed: $e');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _showLogs() async {
    ref.invalidate(marcoLogsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Policy log'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: Consumer(
            builder: (context, ref, _) => ref.watch(marcoLogsProvider).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('$e'),
                  data: (logs) => logs.isEmpty
                      ? const Center(child: Text('No policy activity yet'))
                      : ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            leading: Icon(_logIcon(logs[i].status), size: 18),
                            title: Text(logs[i].message),
                            subtitle: Text('${logs[i].status} • ${logs[i].createdAt.toLocal()}'),
                          ),
                        ),
                ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  IconData _logIcon(String status) {
    switch (status) {
      case 'applied':
        return Icons.check_circle_outline;
      case 'failed':
        return Icons.error_outline;
      default:
        return Icons.edit_note;
    }
  }

  Future<void> _createGroup() async {
    final form = await _showGroupDialog(title: 'Create Marco Group', action: 'Create');
    if (form == null) return;
    try {
      await ref.read(marcoGroupsProvider.notifier).createGroup(
            name: form.name,
            description: form.description,
            color: form.color,
            icon: form.icon,
          );
    } catch (e) {
      _toast('Could not create group: $e');
    }
  }

  Future<void> _editGroup(MarcoGroup group) async {
    final form = await _showGroupDialog(
      title: 'Edit Marco Group',
      action: 'Save',
      name: group.name,
      description: group.description,
      color: group.color,
      icon: group.icon,
    );
    if (form == null) return;
    try {
      await ref.read(marcoGroupsProvider.notifier).updateGroup(
            group.id,
            name: form.name,
            description: form.description ?? '',
            color: form.color,
            icon: form.icon,
          );
    } catch (e) {
      _toast('Could not save group: $e');
    }
  }

  Future<void> _deleteGroup(MarcoGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete ${group.name}? Its policies are removed from the router and its '
            '${group.members.length} device(s) return to normal access.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await ref.read(marcoGroupsProvider.notifier).deleteGroup(group.id);
      _toast(result.dryRun ? 'Group deleted (router writes are disabled)' : 'Group deleted');
    } catch (e) {
      _toast('Delete failed: $e');
    }
  }

  Future<_GroupForm?> _showGroupDialog({
    required String title,
    required String action,
    String name = '',
    String description = '',
    String color = 'blue',
    String icon = 'group',
  }) {
    final nameController = TextEditingController(text: name);
    final descController = TextEditingController(text: description);
    return showDialog<_GroupForm>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Group Name')),
              const SizedBox(height: 12),
              TextField(controller: descController, decoration: const InputDecoration(labelText: 'Description')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: color,
                decoration: const InputDecoration(labelText: 'Color'),
                items: const [
                  DropdownMenuItem(value: 'blue', child: Text('Blue')),
                  DropdownMenuItem(value: 'green', child: Text('Green')),
                  DropdownMenuItem(value: 'orange', child: Text('Orange')),
                  DropdownMenuItem(value: 'red', child: Text('Red')),
                ],
                onChanged: (value) => color = value ?? 'blue',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: icon,
                decoration: const InputDecoration(labelText: 'Icon'),
                items: const [
                  DropdownMenuItem(value: 'group', child: Text('Group')),
                  DropdownMenuItem(value: 'device', child: Text('Device')),
                  DropdownMenuItem(value: 'school', child: Text('School')),
                  DropdownMenuItem(value: 'medical', child: Text('Medical')),
                ],
                onChanged: (value) => icon = value ?? 'group',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final trimmed = nameController.text.trim();
              if (trimmed.isEmpty) return;
              final desc = descController.text.trim();
              Navigator.pop(ctx, _GroupForm(trimmed, desc.isEmpty ? null : desc, color, icon));
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }
}

class _GroupForm {
  final String name;
  final String? description;
  final String color;
  final String icon;
  const _GroupForm(this.name, this.description, this.color, this.icon);
}

Color marcoColor(String name) {
  switch (name) {
    case 'green':
      return Colors.green;
    case 'orange':
      return Colors.orange;
    case 'red':
      return Colors.red;
    case 'purple':
      return Colors.purple;
    case 'teal':
      return Colors.teal;
    default:
      return Colors.blue;
  }
}

IconData marcoIcon(String name) {
  switch (name) {
    case 'device':
      return Icons.devices;
    case 'school':
      return Icons.school;
    case 'medical':
      return Icons.medical_services;
    default:
      return Icons.group;
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onOpen, required this.onEdit, required this.onDelete});

  final MarcoGroup group;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _summary() {
    final p = group.policy;
    final parts = <String>[];
    if (p['internet_enabled'] == false) parts.add('internet off');
    if (p['unlimited_speed'] == false && (p['download_limit_mbps'] != null || p['upload_limit_mbps'] != null)) {
      parts.add('speed limited');
    }
    if (p['daily_quota_gb'] != null || p['monthly_quota_gb'] != null) parts.add('quota');
    final blocked = (p['blocked_websites'] as List?)?.length ?? 0;
    if (blocked > 0) parts.add('$blocked site(s) blocked');
    return parts.isEmpty ? 'No restrictions' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: marcoColor(group.color),
          child: Icon(marcoIcon(group.icon), color: Colors.white),
        ),
        title: Text(group.name),
        subtitle: Text(
          '${group.members.length} device(s) • ${_summary()}'
          '${group.description.isEmpty ? '' : '\n${group.description}'}',
        ),
        isThreeLine: group.description.isNotEmpty,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ],
        ),
        onTap: onOpen,
      ),
    );
  }
}

class _DryRunBanner extends StatelessWidget {
  const _DryRunBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.orange.withOpacity(0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Colors.orange, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Safe mode: router writes are disabled. Policies are saved and previewed, '
              'but nothing is applied to the MikroTik.',
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_work_outlined, size: 72),
          const SizedBox(height: 12),
          Text('Create your first Marco Group', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create Group')),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56),
            const SizedBox(height: 12),
            Text('Could not load Marco groups', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
