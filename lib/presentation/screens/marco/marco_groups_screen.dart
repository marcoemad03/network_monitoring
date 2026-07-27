import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/marco_state_service.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';

class MarcoGroupsScreen extends ConsumerStatefulWidget {
  const MarcoGroupsScreen({super.key});

  @override
  ConsumerState<MarcoGroupsScreen> createState() => _MarcoGroupsScreenState();
}

class _MarcoGroupsScreenState extends ConsumerState<MarcoGroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final groups = ref.read(marcoStateServiceProvider).groups;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marco Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _createGroup,
            tooltip: 'Create group',
          ),
        ],
      ),
      body: groups.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_work_outlined, size: 72),
                  const SizedBox(height: 12),
                  Text('Create your first Marco Group', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _createGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Group'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _colorFromName(group.color),
                      child: Icon(_iconFromName(group.icon), color: Colors.white),
                    ),
                    title: Text(group.name),
                    subtitle: Text(group.description.isEmpty ? 'No description' : group.description),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editGroup(group),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteGroup(group),
                        ),
                      ],
                    ),
                    onTap: () => context.push(RouteNames.marcoGroupDetail(group.id)),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();
    final descController = TextEditingController();
    String color = 'blue';
    String icon = 'group';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Marco Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group Name')),
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
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref.read(marcoStateServiceProvider).saveGroup(
                MarcoGroup(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  description: descController.text.trim(),
                  color: color,
                  icon: icon,
                  macAddresses: const [],
                  policy: const {},
                  createdAt: DateTime.now(),
                ),
              );
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _editGroup(MarcoGroup group) async {
    final controller = TextEditingController(text: group.name);
    final descController = TextEditingController(text: group.description);
    String color = group.color;
    String icon = group.icon;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Marco Group'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Group Name')),
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
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              await ref.read(marcoStateServiceProvider).saveGroup(
                MarcoGroup(
                  id: group.id,
                  name: name,
                  description: descController.text.trim(),
                  color: color,
                  icon: icon,
                  macAddresses: group.macAddresses,
                  policy: group.policy,
                  createdAt: group.createdAt,
                ),
              );
              if (mounted) setState(() {});
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(MarcoGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text('Delete ${group.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(marcoStateServiceProvider).deleteGroup(group.id);
      if (mounted) setState(() {});
    }
  }

  Color _colorFromName(String name) {
    switch (name) {
      case 'green':
        return Colors.green;
      case 'orange':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _iconFromName(String name) {
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
}
