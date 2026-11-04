import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/marco_models.dart';
import '../../providers/marco/marco_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';
import 'widgets/group_actions.dart';
import 'widgets/marco_style.dart';

export 'widgets/marco_style.dart' show marcoColor, marcoIcon;

/// All groups at a glance. A group is a set of devices that share rules: internet
/// on or off, speed, hours, data limits and blocked websites.
class MarcoGroupsScreen extends ConsumerStatefulWidget {
  const MarcoGroupsScreen({super.key});

  @override
  ConsumerState<MarcoGroupsScreen> createState() => _MarcoGroupsScreenState();
}

class _MarcoGroupsScreenState extends ConsumerState<MarcoGroupsScreen> {
  bool _previewing = false;

  Set<String> _names(List<MarcoGroup> groups, [String? except]) => {for (final g in groups) if (g.id != except) g.name.toLowerCase()};

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(marcoGroupsProvider);
    final groups = groupsAsync.valueOrNull?.groups ?? const <MarcoGroup>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            tooltip: (groupsAsync.valueOrNull?.dryRun ?? true) ? 'Preview what would change on the router' : 'Update the router now',
            icon: _previewing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.fact_check_outlined),
            onPressed: _previewing ? null : _previewSync,
          ),
          IconButton(tooltip: 'Router terminal', icon: const Icon(Icons.terminal), onPressed: () => context.push(RouteNames.routerTerminal)),
          IconButton(tooltip: 'Everything that changed', icon: const Icon(Icons.history), onPressed: _showLogs),
          IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: () => ref.read(marcoGroupsProvider.notifier).refresh()),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: FilledButton.icon(onPressed: () => createGroupFlow(context, ref, existingNames: _names(groups)), icon: const Icon(Icons.add), label: const Text('New group')),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(20), child: Column(children: [SkeletonBox(height: 60), SizedBox(height: 16), SkeletonBox(height: 180)])),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyNotice(icon: Icons.cloud_off, title: 'The groups could not be loaded', detail: '$error'),
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: () => ref.read(marcoGroupsProvider.notifier).refresh(), icon: const Icon(Icons.refresh), label: const Text('Try again')),
            ],
          ),
        ),
        data: (result) => result.groups.isEmpty
            ? _Empty(dryRun: result.dryRun, onTemplate: (t) => createGroupFlow(context, ref, existingNames: const {}, template: t))
            : _Overview(
                result: result,
                onOpen: (g) => context.push(RouteNames.marcoGroupDetail(g.id)),
                onEdit: (g) => editGroupFlow(context, ref, g, otherNames: _names(result.groups, g.id)),
                onDelete: (g) => deleteGroupFlow(context, ref, g),
              ),
      ),
    );
  }

  Future<void> _previewSync({bool confirmRemovals = false}) async {
    setState(() => _previewing = true);
    try {
      final preview = await ref.read(marcoRemoteProvider).sync(confirmRemovals: confirmRemovals);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(preview.dryRun ? 'What would change on the router' : 'Router updated'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(preview.message),
                  const SizedBox(height: 12),
                  Text('${preview.plannedChanges.length} change${preview.plannedChanges.length == 1 ? '' : 's'}', style: Theme.of(ctx).textTheme.titleSmall),
                  for (final change in preview.plannedChanges.take(60))
                    Padding(padding: const EdgeInsets.only(top: 4), child: Text(change, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11))),
                  if (preview.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Things to know', style: Theme.of(ctx).textTheme.titleSmall),
                    for (final warning in preview.warnings) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $warning')),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (preview.prunePending > 0 && !preview.dryRun)
              TextButton(
                onPressed: () async {
                  final nav = Navigator.of(ctx);
                  final ok = await showDialog<bool>(
                    context: ctx,
                    builder: (c) => AlertDialog(
                      title: Text('Remove ${preview.prunePending} old rules?'),
                      content: const Text('These are rules and address lists this NMS created earlier for groups that no longer exist. Nothing else on the router is touched.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove them')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    nav.pop();
                    if (mounted) await _previewSync(confirmRemovals: true);
                  }
                },
                child: Text('Remove ${preview.prunePending} old rules'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) toast(context, 'Could not update the router: $e');
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  Future<void> _showLogs() async {
    ref.invalidate(marcoLogsProvider);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Everything that changed'),
        content: SizedBox(
          width: 600,
          height: 440,
          child: Consumer(
            builder: (context, ref, _) => ref.watch(marcoLogsProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (logs) => logs.isEmpty
                  ? const Center(child: Text('Nothing has changed yet'))
                  : ListView.separated(
                      itemCount: logs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: Icon(logs[i].status == 'failed' ? Icons.error_outline : (logs[i].status == 'applied' ? Icons.check_circle_outline : Icons.edit_note), size: 18),
                        title: Text(logs[i].message),
                        subtitle: Text('${logs[i].status} · ${logs[i].createdAt.toLocal()}'),
                      ),
                    ),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.result, required this.onOpen, required this.onEdit, required this.onDelete});
  final MarcoGroupsResult result;
  final ValueChanged<MarcoGroup> onOpen;
  final ValueChanged<MarcoGroup> onEdit;
  final ValueChanged<MarcoGroup> onDelete;

  @override
  Widget build(BuildContext context) {
    final groups = result.groups;
    final devices = groups.fold<int>(0, (a, g) => a + g.members.length);
    final online = groups.fold<int>(0, (a, g) => a + g.members.where((m) => m.isOnline).length);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (result.dryRun) const _SafeMode(),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusPill(tone: StatusTone.neutral, label: '${groups.length} group${groups.length == 1 ? '' : 's'}', icon: Icons.folder_outlined),
            StatusPill(tone: StatusTone.neutral, label: '$devices device${devices == 1 ? '' : 's'} in groups', icon: Icons.devices),
            StatusPill(tone: online > 0 ? StatusTone.ok : StatusTone.neutral, label: '$online online now', icon: Icons.wifi),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 1000 ? 3 : (box.maxWidth >= 640 ? 2 : 1);
            const gap = 14.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final g in groups) SizedBox(width: w, child: _GroupCard(group: g, onOpen: () => onOpen(g), onEdit: () => onEdit(g), onDelete: () => onDelete(g)))],
            );
          },
        ),
      ],
    );
  }
}

class _SafeMode extends StatelessWidget {
  const _SafeMode();

  @override
  Widget build(BuildContext context) {
    final tone = toneStyle(context, StatusTone.warning);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(child: Text('Safe mode is on: groups and rules are saved, but nothing is applied to the router. Use the preview button to see what would change.', style: TextStyle(color: tone.foreground))),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onOpen, required this.onEdit, required this.onDelete});
  final MarcoGroup group;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = marcoColor(group.color);
    final online = group.members.where((m) => m.isOnline).length;
    final badges = policyBadges(group.policy);
    return Semantics(
      button: true,
      label: '${group.name}, ${group.members.length} devices, $online online',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 5, color: color),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 22, backgroundColor: color, child: Icon(marcoIcon(group.icon), color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              Text(group.description.isEmpty ? 'No description' : group.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'More',
                          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: ListTile(dense: true, leading: Icon(Icons.edit_outlined), title: Text('Edit name, color, icon'))),
                            PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline), title: Text('Delete group'))),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${group.members.length}', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, height: 1)),
                        const SizedBox(width: 6),
                        Padding(padding: const EdgeInsets.only(bottom: 3), child: Text(group.members.length == 1 ? 'device' : 'devices', style: theme.textTheme.bodyMedium)),
                        const Spacer(),
                        if (group.members.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8, bottom: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: online > 0 ? const Color(0xFF2E7D32) : theme.colorScheme.outline)),
                                const SizedBox(width: 6),
                                Text('$online online', style: theme.textTheme.bodySmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (badges.isEmpty)
                      Text('No rules yet', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final b in badges)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(b.icon, size: 14, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 5), Text(b.label, style: theme.textTheme.labelMedium)]),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.dryRun, required this.onTemplate});
  final bool dryRun;
  final ValueChanged<String> onTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            if (dryRun) const _SafeMode(),
            Icon(Icons.folder_special_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text('Make your first group', textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'A group is a set of devices that follow the same rules: slower internet for guests, social media blocked at the reception, internet off at night.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final t in groupTemplates)
                  SizedBox(
                    width: 220,
                    child: Card(
                      margin: EdgeInsets.zero,
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => onTemplate(t.key),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(backgroundColor: marcoColor(t.color), child: Icon(t.icon, color: Colors.white)),
                              const SizedBox(height: 10),
                              Text(t.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(t.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
