import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/data_format.dart';
import '../../../../data/models/marco_models.dart';
import '../../../../data/models/marco_site_models.dart';
import '../../../providers/marco/marco_details_provider.dart';
import '../../../providers/marco/marco_provider.dart';
import '../../network/widgets/map_kinds.dart';
import 'device_control_dialog.dart';
import 'marco_style.dart';

/// Everything about one device in a group, with the things you can do to it.
Future<void> showMemberDetailDialog(BuildContext context, {required MarcoGroup group, required MarcoMemberDetail member}) {
  return showDialog<void>(context: context, builder: (_) => MemberDetailDialog(group: group, member: member));
}

class MemberDetailDialog extends ConsumerStatefulWidget {
  const MemberDetailDialog({super.key, required this.group, required this.member});
  final MarcoGroup group;
  final MarcoMemberDetail member;

  @override
  ConsumerState<MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends ConsumerState<MemberDetailDialog> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await action();
      ref.invalidate(marcoDetailsProvider);
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.member;
    final style = kindStyle(m.kind);
    final others = (ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const <MarcoGroup>[]).where((g) => g.id != widget.group.id).toList();
    final control = m.control;
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Icon(style.icon, color: style.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Row(
                  children: [
                    Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: m.online ? const Color(0xFF2E7D32) : theme.colorScheme.outline)),
                    const SizedBox(width: 6),
                    Text('${style.label} · ${m.online ? 'Online' : 'Offline'}', style: theme.textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!m.enforced)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: toneColor(context), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(m.notEnforcedReason, style: theme.textTheme.bodySmall)),
                    ],
                  ),
                ),
              if (control != null && (control.blocked || control.limited))
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.colorScheme.errorContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(control.blocked ? Icons.block : Icons.speed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          control.blocked ? 'Internet blocked for this device' : 'Speed limited to ${control.downloadMbps ?? '–'} down / ${control.uploadMbps ?? '–'} up Mbps',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              row('IP address', m.ip.isEmpty ? 'Not seen yet' : m.ip),
              row('MAC address', m.mac),
              if (m.vendor.isNotEmpty) row('Make', m.vendor),
              if (m.place.isNotEmpty) row('Place', m.place),
              row('Last seen', m.online ? 'Now' : agoLabel(m.lastSeen)),
              const Divider(height: 24),
              row('Used today', m.todayBytes == 0 ? '0 B' : formatBytes(m.todayBytes)),
              row('Used this month', m.monthBytes == 0 ? '0 B' : formatBytes(m.monthBytes)),
              if (m.online && (m.downloadBps > 0 || m.uploadBps > 0)) row('Speed now', '↓ ${formatBitrate(m.downloadBps)}   ↑ ${formatBitrate(m.uploadBps)}'),
              const Divider(height: 24),
              Text('Group: ${widget.group.name}', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final saved = await showDeviceControlDialog(context, mac: m.mac, name: m.name, ip: m.ip, control: control);
                            if (saved == true && mounted) Navigator.pop(context);
                          },
                    icon: const Icon(Icons.speed, size: 18),
                    label: const Text('Block or limit speed'),
                  ),
                  if (others.isNotEmpty)
                    PopupMenuButton<MarcoGroup>(
                      enabled: !_busy,
                      tooltip: 'Move to another group',
                      onSelected: (g) => _run(() => ref.read(marcoGroupsProvider.notifier).assignDevice(g.id, m.mac), 'Moved to ${g.name}'),
                      itemBuilder: (_) => [
                        for (final g in others)
                          PopupMenuItem(value: g, child: Row(children: [CircleAvatar(radius: 6, backgroundColor: marcoColor(g.color)), const SizedBox(width: 10), Text(g.name)])),
                      ],
                      child: Chip(avatar: const Icon(Icons.swap_horiz, size: 18), label: const Text('Move to group')),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(() => ref.read(marcoGroupsProvider.notifier).removeMember(widget.group.id, m.deviceId), 'Removed from ${widget.group.name}'),
                    icon: const Icon(Icons.remove_circle_outline, size: 18),
                    label: const Text('Remove from group'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

Color toneColor(BuildContext context) => Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.6);
