import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/data_format.dart';
import '../../../data/models/client_inventory_models.dart';
import '../../providers/clients/clients_provider.dart';
import '../../providers/marco/marco_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';
import 'client_filters.dart';
import 'widgets/client_detail_dialog.dart';
import 'widgets/client_row.dart';
import 'widgets/kind_visuals.dart';

/// Every device on the network: who is online now, what each one is, how much it
/// used, and the comment people left on it. Everything shown is measured by the
/// router or typed by a person; where the router cannot tell, the page says so.
class DevicesScreen extends ConsumerStatefulWidget {
  const DevicesScreen({super.key});

  @override
  ConsumerState<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends ConsumerState<DevicesScreen> {
  final _search = TextEditingController();
  ClientKind? _kind;
  ClientPresence _presence = ClientPresence.online;
  ClientSort _sort = ClientSort.usage;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(ClientDevice device) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => ClientDetailDialog(device: device));
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved'), duration: Duration(seconds: 2)));
    }
  }

  void _clearFilters() => setState(() {
        _search.clear();
        _kind = null;
        _presence = ClientPresence.online;
      });

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(clientFeedProvider);
    final feed = feedAsync.valueOrNull;
    final loading = feedAsync.isLoading && feed == null;
    final list = feed?.data;
    final groups = ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const [];

    final shown = list == null
        ? const <ClientDevice>[]
        : applyClientFilters(list.clients, query: _search.text, kind: _kind, presence: _presence, sort: _sort);
    final maxToday = shown.fold<int>(0, (m, d) => d.todayTotal > m ? d.todayTotal : m);

    String? groupOf(ClientDevice d) {
      for (final g in groups) {
        if (g.hasMac(d.mac)) return g.name;
      }
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          Flexible(child: Center(child: _FreshnessPill(feed: feed, loading: loading))),
          IconButton(
            tooltip: 'Advanced controls: block, disconnect, limit speed',
            icon: const Icon(Icons.tune),
            onPressed: () => context.push(RouteNames.connectedDevices),
          ),
          IconButton(tooltip: 'Refresh now', icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(clientFeedProvider)),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final layout = layoutFor(constraints.maxWidth);
          final pad = constraints.maxWidth < 700 ? 12.0 : 20.0;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(clientFeedProvider);
              await ref.read(clientFeedProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 8),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1500),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryStrip(list: list, loading: loading),
                            const SizedBox(height: 16),
                            if (list != null && list.available) ...[
                              _TypeChips(
                                counts: kindCounts(list.clients, _presence),
                                total: list.clients.where((d) => _presence == ClientPresence.all || d.online == (_presence == ClientPresence.online)).length,
                                selected: _kind,
                                onSelected: (k) => setState(() => _kind = k),
                              ),
                              const SizedBox(height: 12),
                            ],
                            _Toolbar(
                              controller: _search,
                              presence: _presence,
                              sort: _sort,
                              onQuery: () => setState(() {}),
                              onPresence: (p) => setState(() => _presence = p),
                              onSort: (s) => setState(() => _sort = s),
                            ),
                            const SizedBox(height: 12),
                            if (layout != ClientLayout.card && shown.isNotEmpty) ClientHeaderRow(layout: layout),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ..._listSlivers(context, layout: layout, pad: pad, list: list, loading: loading, error: feed?.fetchError, shown: shown, maxToday: maxToday, groupOf: groupOf),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _listSlivers(
    BuildContext context, {
    required ClientLayout layout,
    required double pad,
    required ClientList? list,
    required bool loading,
    required String? error,
    required List<ClientDevice> shown,
    required int maxToday,
    required String? Function(ClientDevice) groupOf,
  }) {
    Widget box(Widget child) => SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverToBoxAdapter(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500), child: child))),
        );

    if (loading) {
      return [box(Column(children: [for (var i = 0; i < 6; i++) const Padding(padding: EdgeInsets.only(bottom: 10), child: SkeletonBox(height: 64))]))];
    }
    if (list == null) {
      return [box(EmptyNotice(icon: Icons.cloud_off, title: 'The device list could not be loaded', detail: error ?? 'The NMS server has not answered.'))];
    }
    if (!list.available) {
      return [
        box(EmptyNotice(
          icon: Icons.router_outlined,
          title: 'Router not connected',
          detail: list.error ?? 'Waiting for the first reading from the router. The list appears as soon as it answers.',
        )),
      ];
    }
    if (shown.isEmpty) {
      final filtering = _search.text.isNotEmpty || _kind != null || _presence != ClientPresence.online;
      return [
        box(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmptyNotice(
              icon: Icons.search_off,
              title: filtering ? 'No device matches' : 'No device is online right now',
              detail: filtering ? 'Try a different search or filter.' : 'Devices appear here as soon as they connect.',
            ),
            if (filtering) TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Clear filters')),
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
          separatorBuilder: (_, __) => layout == ClientLayout.card
              ? const SizedBox(height: 10)
              : Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          itemBuilder: (context, i) {
            final d = shown[i];
            final row = layout == ClientLayout.card
                ? ClientCard(device: d, maxToday: maxToday, groupName: groupOf(d), onTap: () => _open(d))
                : ClientTableRow(device: d, layout: layout, maxToday: maxToday, groupName: groupOf(d), onTap: () => _open(d));
            return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500), child: row));
          },
        ),
      ),
    ];
  }
}

class _FreshnessPill extends StatelessWidget {
  const _FreshnessPill({required this.feed, required this.loading});

  final ClientFeed? feed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    final f = feed;
    final data = f?.data;
    if (f != null && f.fetchError != null) {
      final age = data?.updatedAt == null ? null : DateTime.now().difference(data!.updatedAt!);
      return StatusPill(
        tone: StatusTone.error,
        label: data == null ? 'Server unreachable' : 'Server unreachable · data from ${formatAge(age ?? Duration.zero)}',
        tooltip: f.fetchError,
      );
    }
    if (data == null) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    if (!data.available) return StatusPill(tone: StatusTone.error, label: 'Router not connected', tooltip: data.error);
    final age = data.updatedAt == null ? Duration.zero : DateTime.now().difference(data.updatedAt!);
    if (data.stale) {
      return StatusPill(tone: StatusTone.warning, label: 'Out of date · ${formatAge(age)}', tooltip: data.error ?? 'The router has not answered recently.');
    }
    if (data.error != null) return StatusPill(tone: StatusTone.warning, label: 'Router poll failing', tooltip: data.error);
    return StatusPill(tone: StatusTone.ok, icon: Icons.sensors, label: 'Live · updated ${formatAge(age)}');
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.list, required this.loading});

  final ClientList? list;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = list?.summary ?? const ClientSummary();
    final ready = list != null && list!.available;
    ClientDevice? top;
    if (ready) {
      for (final d in list!.clients) {
        if (d.todayTotal > 0 && (top == null || d.todayTotal > top.todayTotal)) top = d;
      }
    }
    final tiles = [
      _StatTile(
        icon: Icons.wifi,
        label: 'Online now',
        value: ready ? '${s.online}' : '—',
        detail: ready ? 'of ${s.known} devices seen' : null,
        loading: loading,
      ),
      _StatTile(
        icon: Icons.speed,
        label: 'Speed now',
        value: ready ? '↓ ${formatBitrate(s.downloadBps)}' : '—',
        detail: ready ? '↑ ${formatBitrate(s.uploadBps)}  ·  devices on the hotspot' : null,
        loading: loading,
      ),
      _StatTile(
        icon: Icons.data_usage,
        label: 'Used today',
        value: ready ? formatBytes(s.todayDownload + s.todayUpload) : '—',
        detail: ready ? '↓ ${formatBytes(s.todayDownload)}  ↑ ${formatBytes(s.todayUpload)}' : null,
        loading: loading,
      ),
      _StatTile(
        icon: Icons.emoji_events_outlined,
        label: 'Top user today',
        value: top == null ? '—' : top.displayName,
        detail: top == null ? (ready ? 'No usage recorded yet' : null) : formatBytes(top.todayTotal),
        loading: loading,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1000 ? 4 : c.maxWidth >= 520 ? 2 : 1;
        const gap = 12.0;
        final width = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: width, child: t)]);
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.icon, required this.label, required this.value, this.detail, required this.loading});

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: theme.colorScheme.onPrimaryContainer, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: loading
                    ? const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SkeletonBox(height: 12, width: 80), SizedBox(height: 8), SkeletonBox(height: 18, width: 110)])
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          if (detail != null) Text(detail!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
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

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.counts, required this.total, required this.selected, required this.onSelected});

  final List<MapEntry<ClientKind, int>> counts;
  final int total;
  final ClientKind? selected;
  final ValueChanged<ClientKind?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: Text('All  $total'),
          selected: selected == null,
          onSelected: (_) => onSelected(null),
        ),
        for (final e in counts)
          ChoiceChip(
            avatar: Icon(kindIcon(e.key), size: 18),
            label: Text('${kindPlural(e.key)}  ${e.value}'),
            selected: selected == e.key,
            onSelected: (on) => onSelected(on ? e.key : null),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.presence,
    required this.sort,
    required this.onQuery,
    required this.onPresence,
    required this.onSort,
  });

  final TextEditingController controller;
  final ClientPresence presence;
  final ClientSort sort;
  final VoidCallback onQuery;
  final ValueChanged<ClientPresence> onPresence;
  final ValueChanged<ClientSort> onSort;

  @override
  Widget build(BuildContext context) {
    final search = TextField(
      controller: controller,
      onChanged: (_) => onQuery(),
      decoration: InputDecoration(
        hintText: 'Search by name, IP, MAC, comment or type',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                icon: const Icon(Icons.close),
                onPressed: () {
                  controller.clear();
                  onQuery();
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
    final presenceButtons = SegmentedButton<ClientPresence>(
      showSelectedIcon: false,
      segments: [for (final p in ClientPresence.values) ButtonSegment(value: p, label: Text(p.label))],
      selected: {presence},
      onSelectionChanged: (s) => onPresence(s.first),
    );
    final sortMenu = DropdownMenu<ClientSort>(
      initialSelection: sort,
      label: const Text('Sort by'),
      width: 190,
      requestFocusOnTap: false,
      onSelected: (s) {
        if (s != null) onSort(s);
      },
      dropdownMenuEntries: [for (final s in ClientSort.values) DropdownMenuEntry(value: s, label: s.label)],
    );
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 900) {
          return Row(
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              presenceButtons,
              const SizedBox(width: 12),
              sortMenu,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            search,
            const SizedBox(height: 10),
            Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [presenceButtons, sortMenu]),
          ],
        );
      },
    );
  }
}
