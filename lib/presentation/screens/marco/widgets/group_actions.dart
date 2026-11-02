import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/marco_models.dart';
import '../../../providers/marco/marco_details_provider.dart';
import '../../../providers/marco/marco_provider.dart';
import 'add_devices_dialog.dart';
import 'group_form_dialog.dart';

void toast(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks for a new group and creates it. Returns the group id, or null when cancelled.
Future<void> createGroupFlow(BuildContext context, WidgetRef ref, {required Set<String> existingNames, String template = 'blank', void Function(String name)? onCreated}) async {
  final form = await showGroupFormDialog(context, existingNames: existingNames, initialTemplate: template);
  if (form == null || !context.mounted) return;
  try {
    final result = await ref.read(marcoGroupsProvider.notifier).createGroup(
      name: form.name,
      description: form.description,
      color: form.color,
      icon: form.icon,
      policy: form.policy,
    );
    if (context.mounted) {
      toast(context, result.dryRun ? 'Group created. Safe mode is on, so nothing was changed on the router.' : 'Group created');
      onCreated?.call(form.name);
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Could not create the group: $e');
  }
}

Future<void> editGroupFlow(BuildContext context, WidgetRef ref, MarcoGroup group, {required Set<String> otherNames}) async {
  final form = await showGroupFormDialog(
    context,
    creating: false,
    name: group.name,
    description: group.description,
    color: group.color,
    icon: group.icon,
    existingNames: otherNames,
  );
  if (form == null || !context.mounted) return;
  try {
    await ref.read(marcoGroupsProvider.notifier).updateGroup(group.id, name: form.name, description: form.description, color: form.color, icon: form.icon);
    ref.invalidate(marcoDetailsProvider);
    if (context.mounted) toast(context, 'Group saved');
  } catch (e) {
    if (context.mounted) toast(context, 'Could not save the group: $e');
  }
}

/// Returns true when the group was deleted.
Future<bool> deleteGroupFlow(BuildContext context, WidgetRef ref, MarcoGroup group) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete ${group.name}?'),
      content: Text(
        group.members.isEmpty
            ? 'The group has no devices.'
            : '${group.members.length} device${group.members.length == 1 ? '' : 's'} will go back to normal access: the group\'s blocks and limits are removed from the router.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error, foregroundColor: Theme.of(ctx).colorScheme.onError),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete group'),
        ),
      ],
    ),
  );
  if (confirm != true || !context.mounted) return false;
  try {
    final result = await ref.read(marcoGroupsProvider.notifier).deleteGroup(group.id);
    if (context.mounted) toast(context, result.dryRun ? 'Group deleted. Safe mode is on, so nothing was changed on the router.' : 'Group deleted');
    return true;
  } catch (e) {
    if (context.mounted) toast(context, 'Could not delete the group: $e');
    return false;
  }
}

/// Opens the device picker and adds what was chosen.
Future<void> addDevicesFlow(BuildContext context, WidgetRef ref, MarcoGroup group) async {
  final macs = await showAddDevicesDialog(context, group: group);
  if (macs == null || macs.isEmpty || !context.mounted) return;
  try {
    final result = await ref.read(marcoGroupsProvider.notifier).addMembers(group.id, macs);
    ref.invalidate(marcoDetailsProvider);
    if (context.mounted) {
      toast(
        context,
        '${macs.length} device${macs.length == 1 ? '' : 's'} added to ${group.name}.${result.dryRun ? ' Safe mode is on, so the router was not changed.' : ' The rules are being applied.'}',
      );
    }
  } catch (e) {
    if (context.mounted) toast(context, 'Could not add the devices: $e');
  }
}
