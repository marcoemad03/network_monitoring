import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/data_format.dart';
import '../../../data/models/marco_models.dart';
import '../../../data/models/marco_site_models.dart';
import '../../providers/marco/marco_details_provider.dart';
import '../../providers/marco/marco_provider.dart';
import '../dashboard/widgets/dash_card.dart';
import '../network/widgets/map_kinds.dart';
import 'widgets/group_actions.dart';
import 'widgets/marco_style.dart';
import 'widgets/member_detail_dialog.dart';
import 'widgets/rules_tab.dart';
import 'widgets/sites_tab.dart';

export 'widgets/marco_style.dart' show marcoColor, marcoIcon;

/// One group: its devices, its rules, the sites it blocks and what changed lately.
class MarcoGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const MarcoGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<MarcoGroupDetailScreen> createState() => _MarcoGroupDetailScreenState();
}

class _MarcoGroupDetailScreenState extends ConsumerState<MarcoGroupDetailScreen> {
  Future<void> _savePolicy(Map<String, dynamic> policy) async {
    try {
      final result = await ref.read(marcoGroupsProvider.notifier).updatePolicy(widget.groupId, policy);
      ref.invalidate(marcoDetailsProvider);
      if (mounted) toast(context, result.dryRun ? 'Saved. Safe mode is on, so the router was not changed.' : 'Saved. The rules are being applied to the router.');
    } catch (e) {
      if (mounted) toast(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = ref.watch(marcoDetailsProvider(widget.groupId));
    final data = details.valueOrNull;
    final groups = ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const <MarcoGroup>[];

    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group')),
        body: details.hasError
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmptyNotice(icon: Icons.cloud_off, title: 'The group could not be loaded', detail: '${details.error}'),
                    const SizedBox(height: 8),
                    FilledButton.icon(onPressed: () => ref.invalidate(marcoDetailsProvider(widget.groupId)), icon: const Icon(Icons.refresh), label: const Text('Try again')),
                  ],
                ),
              )
            : const Padding(padding: EdgeInsets.all(20), child: Column(children: [SkeletonBox(height: 110), SizedBox(height: 16), SkeletonBox(height: 300)])),
      );
    }

    final group = data.group;
    final color = marcoColor(group.color);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/marco-groups')),
          title: Text(group.name),
          actions: [
            IconButton(
              tooltip: 'Edit name, color and icon',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => editGroupFlow(context, ref, group, otherNames: {for (final g in groups) if (g.id != group.id) g.name.toLowerCase()}),
            ),
            IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(marcoDetailsProvider(widget.groupId))),
            IconButton(
              tooltip: 'Delete group',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await deleteGroupFlow(context, ref, group) && context.mounted) context.go('/marco-groups');
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.devices, size: 18), text: 'Devices (${data.members.length})'),
              const Tab(icon: Icon(Icons.tune, size: 18), text: 'Rules'),
              Tab(icon: const Icon(Icons.block, size: 18), text: 'Websites (${data.sites.length})'),
              const Tab(icon: Icon(Icons.history, size: 18), text: 'Activity'),
            ],
          ),
        ),
        body: Column(
          children: [
            _Header(data: data, color: color),
            Expanded(
              child: TabBarView(
                children: [
                  _DevicesTab(data: data, onAdd: () => addDevicesFlow(context, ref, group)),
                  RulesTab(policy: group.policy, dryRun: data.dryRun, onSave: _savePolicy),
                  SitesTab(details: data, onSave: _savePolicy),
                  _ActivityTab(logs: data.logs),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.data, required this.color});
  final MarcoGroupDetails data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final g = data.group;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: color, child: Icon(marcoIcon(g.icon), color: Colors.white)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.description.isEmpty ? 'No description' : g.description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        StatusPill(tone: StatusTone.neutral, label: '${data.members.length} device${data.members.length == 1 ? '' : 's'}', icon: Icons.devices),
                        StatusPill(tone: data.onlineCount > 0 ? StatusTone.ok : StatusTone.neutral, label: '${data.onlineCount} online', icon: Icons.wifi),
                        StatusPill(tone: StatusTone.neutral, label: '${data.todayBytes == 0 ? '0 B' : formatBytes(data.todayBytes)} today', icon: Icons.data_usage),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [for (final s in data.summary) Text('• $s', style: theme.textTheme.bodySmall)],
          ),
          if (data.dryRun)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: theme.colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Expanded(child: Text('Safe mode: changes are saved but the router is not touched.', style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DevicesTab extends ConsumerStatefulWidget {
  const _DevicesTab({required this.data, required this.onAdd});
  final MarcoGroupDetails data;
  final VoidCallback onAdd;

  @override
  ConsumerState<_DevicesTab> createState() => _DevicesTabState();
}

class _DevicesTabState extends ConsumerState<_DevicesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = widget.data.members;
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? all : all.where((m) => [m.name, m.ip, m.mac, m.place, kindStyle(m.kind).label].join(' ').toLowerCase().contains(q)).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(isDense: true, prefixIcon: Icon(Icons.search, size: 20), hintText: 'Search the devices in this group', border: OutlineInputBorder()),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add), label: const Text('Add devices')),
            ],
          ),
        ),
        Expanded(
          child: all.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EmptyNotice(icon: Icons.devices_other, title: 'No devices in this group yet', detail: 'Add devices from the ones the router sees. The group\'s rules apply to them as soon as they are added.'),
                      const SizedBox(height: 8),
                      FilledButton.icon(onPressed: widget.onAdd, icon: const Icon(Icons.add), label: const Text('Add devices')),
                    ],
                  ),
                )
              : shown.isEmpty
              ? const Center(child: EmptyNotice(icon: Icons.search_off, title: 'No device matches'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  itemBuilder: (context, i) => _MemberRow(
                    member: shown[i],
                    onTap: () => showMemberDetailDialog(context, group: widget.data.group, member: shown[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.onTap});
  final MarcoMemberDetail member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle(member.kind);
    final c = member.control;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(style.icon, size: 21, color: style.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(member.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Tooltip(message: member.online ? 'Online' : 'Offline', child: Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: member.online ? const Color(0xFF2E7D32) : theme.colorScheme.outline))),
                    ],
                  ),
                  Text(
                    [style.label, if (member.ip.isNotEmpty) member.ip, if (member.place.isNotEmpty) member.place].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (c != null && c.blocked) const Padding(padding: EdgeInsets.only(right: 8), child: StatusPill(tone: StatusTone.error, label: 'Blocked', icon: Icons.block)),
            if (c != null && !c.blocked && c.limited) const Padding(padding: EdgeInsets.only(right: 8), child: StatusPill(tone: StatusTone.warning, label: 'Limited', icon: Icons.speed)),
            if (!member.enforced) const Padding(padding: EdgeInsets.only(right: 8), child: StatusPill(tone: StatusTone.neutral, label: 'Not seen yet', icon: Icons.hourglass_empty)),
            SizedBox(
              width: 84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(member.todayBytes == 0 ? '0 B' : formatBytes(member.todayBytes), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text('today', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.logs});
  final List<MarcoPolicyLog> logs;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return const Center(child: EmptyNotice(icon: Icons.history, title: 'Nothing has happened in this group yet'));
    }
    IconData icon(String s) => switch (s) {
      'applied' => Icons.check_circle_outline,
      'failed' => Icons.error_outline,
      'dry_run' || 'saved' => Icons.save_outlined,
      _ => Icons.edit_note,
    };
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final l = logs[i];
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon(l.status), size: 20, color: l.status == 'failed' ? theme.colorScheme.error : null),
          title: Text(l.message),
          subtitle: Text('${l.status == 'saved' ? 'saved, router not changed' : l.status} · ${formatAge(DateTime.now().difference(l.createdAt))}'),
        );
      },
    );
  }
}
