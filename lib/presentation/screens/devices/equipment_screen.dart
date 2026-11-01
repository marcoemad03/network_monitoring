import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../../core/utils/data_format.dart';
import '../../../data/models/equipment_models.dart';
import '../../../data/models/wan_usage_models.dart';
import '../../providers/dashboard/wan_provider.dart';
import '../../providers/equipment/equipment_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';
import 'equipment_filters.dart';

/// The registered equipment: routers, switches, servers, medical devices and so
/// on. Their state comes from the ping the server sends them. The MikroTik
/// router is also shown live, because it reports its own load.
class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  final _search = TextEditingController();
  DeviceType? _type;
  EquipmentStateFilter _state = EquipmentStateFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _search.clear();
        _type = null;
        _state = EquipmentStateFilter.all;
      });

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(equipmentFeedProvider);
    final feed = feedAsync.valueOrNull;
    final loading = feedAsync.isLoading && feed == null;
    final all = feed?.items;
    final wan = ref.watch(wanUsageProvider).valueOrNull?.data;

    final shown = all == null ? const <EquipmentItem>[] : applyEquipmentFilters(all, query: _search.text, type: _type, state: _state);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment'),
        actions: [
          Flexible(child: Center(child: _FreshPill(feed: feed, loading: loading))),
          IconButton(tooltip: 'Refresh now', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(equipmentFeedProvider)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(RouteNames.deviceCreate),
        icon: const Icon(Icons.add),
        label: const Text('Add device'),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth < 700 ? 12.0 : 20.0;
          final card = c.maxWidth < 760;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(equipmentFeedProvider);
              await ref.read(equipmentFeedProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RouterStrip(usage: wan),
                            const SizedBox(height: 14),
                            if (all != null) ...[
                              _StateTiles(all: all, selected: _state, onSelected: (s) => setState(() => _state = s)),
                              const SizedBox(height: 14),
                              _TypeChips(counts: equipmentTypeCounts(all), total: all.length, selected: _type, onSelected: (t) => setState(() => _type = t)),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _search,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'Search by name, IP, vendor, model or location',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _search.text.isEmpty
                                    ? null
                                    : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close), onPressed: () => setState(_search.clear)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ..._list(context, pad: pad, card: card, all: all, shown: shown, loading: loading, error: feed?.fetchError),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _list(
    BuildContext context, {
    required double pad,
    required bool card,
    required List<EquipmentItem>? all,
    required List<EquipmentItem> shown,
    required bool loading,
    required String? error,
  }) {
    Widget box(Widget child) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverToBoxAdapter(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1400), child: child))),
        );

    if (loading) {
      return [box(Column(children: [for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 68))]))];
    }
    if (all == null) {
      return [box(EmptyNotice(icon: Icons.cloud_off, title: 'The equipment list could not be loaded', detail: error ?? 'The NMS server has not answered.'))];
    }
    if (all.isEmpty) {
      return [
        box(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EmptyNotice(
              icon: Icons.router_outlined,
              title: 'No equipment registered yet',
              detail: 'Add the switches, servers, access points and medical devices you want to watch. The NMS pings each one and tells you when it stops answering.',
            ),
            FilledButton.icon(onPressed: () => context.push(RouteNames.deviceCreate), icon: const Icon(Icons.add), label: const Text('Add the first device')),
          ],
        )),
      ];
    }
    if (shown.isEmpty) {
      return [
        box(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EmptyNotice(icon: Icons.search_off, title: 'No equipment matches', detail: 'Try a different search or filter.'),
            TextButton.icon(onPressed: _clear, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters')),
          ],
        )),
      ];
    }
    final theme = Theme.of(context);
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: pad),
        sliver: SliverList.separated(
          itemCount: shown.length,
          separatorBuilder: (_, __) => SizedBox(height: card ? 10 : 8),
          itemBuilder: (context, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: _EquipmentRow(item: shown[i], compact: card, theme: theme, onTap: () => context.push(RouteNames.deviceDetail.replaceAll(':id', shown[i].id))),
            ),
          ),
        ),
      ),
    ];
  }
}

// ---------------------------------------------------------------------------

class _FreshPill extends StatelessWidget {
  const _FreshPill({required this.feed, required this.loading});

  final EquipmentFeed? feed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    final f = feed;
    if (f == null) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    if (f.fetchError != null) {
      return StatusPill(tone: StatusTone.error, label: f.items == null ? 'Server unreachable' : 'Server unreachable · showing the last list', tooltip: f.fetchError);
    }
    return const StatusPill(tone: StatusTone.ok, icon: Icons.sensors, label: 'Live');
  }
}

/// The MikroTik router, live. It reports its own CPU, memory and link state.
class _RouterStrip extends StatelessWidget {
  const _RouterStrip({required this.usage});

  final WanUsage? usage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final router = usage?.router;
    final connected = usage != null && usage!.available && router != null;

    Widget fact(IconData icon, String text, {StatusTone? tone}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: tone == null ? muted : toneStyle(context, tone).foreground),
            const SizedBox(width: 6),
            Text(text, style: theme.textTheme.bodyMedium),
          ],
        );

    StatusTone load(num percent) => percent >= 90 ? StatusTone.error : percent >= 70 ? StatusTone.warning : StatusTone.ok;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.router, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(connected ? 'MikroTik ${router.board}' : 'MikroTik router', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  Text(connected ? 'RouterOS ${router.version}' : 'Measured live by the NMS', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ],
          ),
          if (!connected)
            StatusPill(tone: StatusTone.error, label: usage == null ? 'Connecting…' : 'Router not connected', tooltip: usage?.error)
          else ...[
            StatusPill(tone: usage!.linkRunning ? StatusTone.ok : StatusTone.error, label: usage!.linkRunning ? 'Internet link up' : 'Internet link down'),
            fact(Icons.memory, 'CPU ${router.cpuLoadPercent}%', tone: load(router.cpuLoadPercent)),
            fact(Icons.sd_storage_outlined, 'Memory ${router.memoryUsedPercent.round()}%', tone: load(router.memoryUsedPercent)),
            fact(Icons.schedule, 'Up ${formatUptime(router.uptimeSeconds)}'),
            if (usage!.current != null) fact(Icons.swap_vert, '↓ ${formatBitrate(usage!.current!.downloadBps)}   ↑ ${formatBitrate(usage!.current!.uploadBps)}'),
          ],
        ],
      ),
    );
  }
}

class _StateTiles extends StatelessWidget {
  const _StateTiles({required this.all, required this.selected, required this.onSelected});

  final List<EquipmentItem> all;
  final EquipmentStateFilter selected;
  final ValueChanged<EquipmentStateFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(EquipmentStateFilter f) => all.where((e) => matchesState(e, f)).length;
    final attention = count(EquipmentStateFilter.attention);
    final tiles = [
      (EquipmentStateFilter.all, Icons.inventory_2_outlined, StatusTone.neutral),
      (EquipmentStateFilter.online, Icons.check_circle_outline, StatusTone.ok),
      (EquipmentStateFilter.attention, Icons.warning_amber_rounded, attention > 0 ? StatusTone.error : StatusTone.neutral),
      (EquipmentStateFilter.maintenance, Icons.build_outlined, StatusTone.neutral),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 760 ? 4 : 2;
        const gap = 10.0;
        final width = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles)
              SizedBox(
                width: width,
                child: _StateTile(icon: t.$2, tone: t.$3, label: t.$1.label, value: count(t.$1), selected: selected == t.$1, onTap: () => onSelected(t.$1)),
              ),
          ],
        );
      },
    );
  }
}

class _StateTile extends StatelessWidget {
  const _StateTile({required this.icon, required this.tone, required this.label, required this.value, required this.selected, required this.onTap});

  final IconData icon;
  final StatusTone tone;
  final String label;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = toneStyle(context, tone);
    return Semantics(
      button: true,
      selected: selected,
      label: '$value $label${selected ? ', selected filter' : ''}',
      child: ExcludeSemantics(
        child: Material(
          color: style.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: selected ? theme.colorScheme.primary : Colors.transparent, width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: style.foreground),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: style.foreground)),
                        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.counts, required this.total, required this.selected, required this.onSelected});

  final List<MapEntry<DeviceType, int>> counts;
  final int total;
  final DeviceType? selected;
  final ValueChanged<DeviceType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(label: Text('All types  $total'), selected: selected == null, onSelected: (_) => onSelected(null)),
        for (final e in counts)
          ChoiceChip(
            avatar: Icon(_icon(e.key), size: 18),
            label: Text('${e.key.label}  ${e.value}'),
            selected: selected == e.key,
            onSelected: (on) => onSelected(on ? e.key : null),
          ),
      ],
    );
  }
}

IconData _icon(DeviceType t) => switch (t) {
      DeviceType.router => Icons.router_outlined,
      DeviceType.switch_ => Icons.lan_outlined,
      DeviceType.server => Icons.dns_outlined,
      DeviceType.firewall => Icons.security,
      DeviceType.accessPoint => Icons.wifi,
      DeviceType.printer => Icons.print_outlined,
      DeviceType.camera => Icons.videocam_outlined,
      DeviceType.medicalDevice => Icons.medical_services_outlined,
      DeviceType.iot => Icons.sensors,
      DeviceType.workstation => Icons.computer,
      _ => Icons.devices_other,
    };

({StatusTone tone, IconData icon}) _statusLook(DeviceStatus s) => switch (s) {
      DeviceStatus.online => (tone: StatusTone.ok, icon: Icons.check_circle_outline),
      DeviceStatus.offline => (tone: StatusTone.error, icon: Icons.cancel_outlined),
      DeviceStatus.degraded => (tone: StatusTone.warning, icon: Icons.warning_amber_rounded),
      DeviceStatus.maintenance => (tone: StatusTone.neutral, icon: Icons.build_outlined),
      _ => (tone: StatusTone.neutral, icon: Icons.help_outline),
    };

class _EquipmentRow extends StatelessWidget {
  const _EquipmentRow({required this.item, required this.compact, required this.theme, required this.onTap});

  final EquipmentItem item;
  final bool compact;
  final ThemeData theme;
  final VoidCallback onTap;

  String get _ping {
    if (!item.isMonitored) return 'Not monitored';
    final ms = item.pingAvgMs;
    final loss = item.pingLossPercent;
    if (item.pingAt == null) return 'Not pinged yet';
    if (item.status == DeviceStatus.offline) return 'No reply to ping';
    final latency = ms == null ? '—' : '${ms.toStringAsFixed(ms >= 10 ? 0 : 1)} ms';
    final lost = (loss ?? 0) > 0 ? ' · ${loss!.toStringAsFixed(loss >= 10 ? 0 : 1)}% lost' : '';
    return '$latency$lost';
  }

  String get _seen {
    final seen = item.lastSeen;
    if (seen == null) return '';
    return item.status == DeviceStatus.online ? 'Answering now' : 'Last seen ${formatAge(DateTime.now().difference(seen))}';
  }

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final look = _statusLook(item.status);
    final detail = [if (item.vendor.isNotEmpty) item.vendor, if (item.model.isNotEmpty) item.model].join(' ');

    final title = Row(
      children: [
        Flexible(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
        if (item.isCritical) ...[const SizedBox(width: 6), Tooltip(message: 'Critical device', child: Icon(Icons.priority_high, size: 16, color: theme.colorScheme.error))],
        if (item.isPinned) ...[const SizedBox(width: 4), Tooltip(message: 'Pinned', child: Icon(Icons.push_pin_outlined, size: 15, color: muted))],
      ],
    );
    final sub = Text(
      [item.type.label, if (detail.isNotEmpty) detail, if (item.location.isNotEmpty) item.location].join(' · '),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(color: muted),
    );
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: toneStyle(context, look.tone).background, borderRadius: BorderRadius.circular(12)),
      child: Icon(_icon(item.type), color: toneStyle(context, look.tone).foreground),
    );
    final status = StatusPill(tone: look.tone, icon: look.icon, label: item.status.label);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamilyFallback: const ['Consolas', 'monospace']);

    return Semantics(
      button: true,
      label: '${item.name}, ${item.type.label}, ${item.status.label}${item.isCritical ? ', critical' : ''}. Opens details.',
      child: ExcludeSemantics(
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: item.needsAttention ? theme.colorScheme.error.withValues(alpha: 0.5) : theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [icon, const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, sub])), status]),
                        const SizedBox(height: 8),
                        Text('${item.ipAddress}  ·  $_ping', style: mono),
                        if (_seen.isNotEmpty) Text(_seen, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                      ],
                    )
                  : Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [title, sub])),
                        Expanded(flex: 2, child: Text(item.ipAddress, style: mono)),
                        Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_ping, style: theme.textTheme.bodyMedium), if (_seen.isNotEmpty) Text(_seen, style: theme.textTheme.bodySmall?.copyWith(color: muted))])),
                        SizedBox(width: 130, child: Align(alignment: Alignment.centerLeft, child: status)),
                        Icon(Icons.chevron_right, color: muted),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
