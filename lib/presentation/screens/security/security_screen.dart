import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/data_format.dart';
import '../../../data/datasources/remote/security_remote_datasource.dart';
import '../../../data/models/security_models.dart';
import '../../providers/security/security_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';
import 'widgets/device_activity_dialog.dart';
import 'widgets/security_widgets.dart';

/// What the devices on the network are connected to, and what looks wrong.
///
/// The picture comes from a scan of the router's connection table. A scan loads
/// the router, so it runs only when someone asks, after a confirmation, and the
/// page says what the last one cost.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  final _search = TextEditingController();
  bool _flaggedOnly = false;
  DateTime _loadedAt = DateTime.now();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _confirmScan(SecurityOverview? overview) async {
    final last = overview?.scan;
    final max = overview?.settings.maxRouterCpu ?? 85;
    final took = last == null || last.restored ? 'several seconds' : 'about ${(last.durationMs / 1000).round().clamp(1, 600)} seconds';
    final load = last == null || last.restored
        ? 'The router\'s CPU can climb to 100% while it answers.'
        : 'Last time the router\'s CPU went from ${last.routerCpuBefore}% to ${last.routerCpuAfter}%.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.radar),
        title: const Text('Scan the network now?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The NMS reads every connection the router is carrying right now${last == null ? '' : ' (about ${formatCount(last.connections)} last time)'}. It takes $took.'),
              const SizedBox(height: 10),
              Text(load),
              const SizedBox(height: 10),
              Text('The scan is refused if the router is already above $max% CPU. It only reads: nothing on the router changes.'),
              const SizedBox(height: 10),
              Text('Only destinations are kept (a platform, a provider, an application), never page addresses or content.', style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        actions: [
          TextButton.icon(onPressed: () => context.push(RouteNames.securitySites), icon: const Icon(Icons.travel_explore), label: const Text('Websites')),
          const SizedBox(width: 4),
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.radar), label: const Text('Scan now')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(securityProvider.notifier).scan();
    }
  }

  void _openDevice(String key, String name, List<SecurityFinding> findings) {
    showDialog<void>(context: context, builder: (_) => DeviceActivityDialog(deviceKey: key, name: name, findings: findings));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityProvider);
    ref.listen(securityProvider, (_, __) => _loadedAt = DateTime.now());
    final overview = state.overview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        actions: [
          TextButton.icon(onPressed: () => context.push(RouteNames.securitySites), icon: const Icon(Icons.travel_explore), label: const Text('Websites')),
          const SizedBox(width: 4),
          Flexible(child: Center(child: _ScanStatusPill(state: state))),
          const SizedBox(width: 8),
          _ScanButton(state: state, loadedAt: _loadedAt, onPressed: () => _confirmScan(overview)),
          const SizedBox(width: 12),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final pad = c.maxWidth < 700 ? 12.0 : 20.0;
          return RefreshIndicator(
            onRefresh: () => ref.read(securityProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(pad),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: _body(context, state, c.maxWidth),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, SecurityState state, double width) {
    final overview = state.overview;
    final children = <Widget>[];

    if (state.scanProblem != null) children.add(_ScanProblem(problem: state.scanProblem!));
    if (state.fetchError != null && overview == null) {
      children.add(EmptyNotice(icon: Icons.cloud_off, title: 'The security overview could not be loaded', detail: state.fetchError));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
    if (state.loading && overview == null) {
      children.addAll([const SkeletonBox(height: 88), const SizedBox(height: 14), const SkeletonBox(height: 220)]);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
    if (overview == null) return const SizedBox.shrink();

    if (!overview.scanned) {
      children.add(_FirstScan(overview: overview, scanning: state.scanning, onScan: () => _confirmScan(overview)));
      if (overview.newDevices.isNotEmpty) children.addAll([const SizedBox(height: 16), _NewDevicesCard(overview: overview)]);
      children.addAll([const SizedBox(height: 16), _PrivacyCard(settings: overview.settings)]);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    final wide = width >= 1000;
    children.addAll([
      if (overview.scan != null && overview.scan!.restored) _RestoredNote(scan: overview.scan!),
      _SummaryTiles(overview: overview),
      const SizedBox(height: 16),
      _FindingsCard(overview: overview, onOpen: (f) => _openDevice(f.deviceKey, f.device, overview.findings)),
      const SizedBox(height: 16),
      if (wide)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _RankingCard(title: 'Most data right now', icon: Icons.data_usage, items: overview.topByData, byData: true, note: _platformNote(overview))),
            const SizedBox(width: 16),
            Expanded(child: _RankingCard(title: 'Used by the most devices', icon: Icons.groups_outlined, items: overview.topByDevices, byData: false)),
          ],
        )
      else ...[
        _RankingCard(title: 'Most data right now', icon: Icons.data_usage, items: overview.topByData, byData: true, note: _platformNote(overview)),
        const SizedBox(height: 16),
        _RankingCard(title: 'Used by the most devices', icon: Icons.groups_outlined, items: overview.topByDevices, byData: false),
      ],
      const SizedBox(height: 16),
      _PopularCard(items: overview.popular),
      const SizedBox(height: 16),
      _DevicesCard(
        overview: overview,
        search: _search,
        flaggedOnly: _flaggedOnly,
        wide: width >= 900,
        onSearch: () => setState(() {}),
        onFlaggedOnly: (v) => setState(() => _flaggedOnly = v),
        onOpen: (d) => _openDevice(d.key, d.name, overview.findings),
      ),
      if (overview.newDevices.isNotEmpty) ...[const SizedBox(height: 16), _NewDevicesCard(overview: overview)],
      const SizedBox(height: 16),
      _PrivacyCard(settings: overview.settings),
      const SizedBox(height: 24),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  /// Tells whether the router's own platform lists were used, since without them
  /// YouTube and the like show up only as their cloud provider.
  String? _platformNote(SecurityOverview o) => o.settings.platformsFromRouter.isEmpty
      ? 'Platforms such as YouTube show as their provider (Google). Point ROUTER_SCAN_PLATFORM_LISTS at the router lists that name them to see them by name.'
      : null;
}

String formatCount(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

// ---------------------------------------------------------------------------

class _ScanStatusPill extends StatelessWidget {
  const _ScanStatusPill({required this.state});

  final SecurityState state;

  @override
  Widget build(BuildContext context) {
    if (state.scanning) return const StatusPill(tone: StatusTone.neutral, label: 'Scanning the router…');
    if (state.fetchError != null && state.overview == null) return StatusPill(tone: StatusTone.error, label: 'Server unreachable', tooltip: state.fetchError);
    final scan = state.overview?.scan;
    if (state.overview == null) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    if (scan == null) return const StatusPill(tone: StatusTone.warning, label: 'No scan yet');
    final age = DateTime.now().difference(scan.takenAt);
    return StatusPill(
      tone: age > const Duration(hours: 6) ? StatusTone.warning : StatusTone.ok,
      icon: Icons.radar,
      label: 'Last scan ${formatAge(age)}',
      tooltip: '${formatCount(scan.connections)} connections${scan.restored ? ', restored after a restart' : ', took ${(scan.durationMs / 1000).toStringAsFixed(1)} s'}',
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.state, required this.loadedAt, required this.onPressed});

  final SecurityState state;
  final DateTime loadedAt;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final overview = state.overview;
    final cooldown = overview == null ? 0 : overview.settings.cooldownSeconds - DateTime.now().difference(loadedAt).inSeconds;
    final waiting = cooldown > 0;
    final disabled = state.scanning || overview == null || waiting;
    final label = state.scanning ? 'Scanning…' : waiting ? 'Again in ${(cooldown / 60).ceil()} min' : 'Scan now';
    return Tooltip(
      message: waiting ? 'A scan was taken a moment ago. Scans are spaced out to spare the router.' : 'Read the router\'s connection table (it loads the router for a few seconds)',
      child: FilledButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: state.scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar),
        label: Text(label),
      ),
    );
  }
}

class _ScanProblem extends StatelessWidget {
  const _ScanProblem({required this.problem});

  final ScanRefused problem;

  @override
  Widget build(BuildContext context) {
    final tone = switch (problem.code) {
      'COOLDOWN' || 'SCAN_RUNNING' => StatusTone.neutral,
      'ROUTER_BUSY' => StatusTone.warning,
      _ => StatusTone.error,
    };
    final style = toneStyle(context, tone);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(style.icon, color: style.foreground),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(switch (problem.code) {
                  'COOLDOWN' => 'A scan was taken a moment ago',
                  'SCAN_RUNNING' => 'A scan is already running',
                  'ROUTER_BUSY' => 'The scan did not start',
                  _ => 'The scan failed',
                }, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(problem.message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FirstScan extends StatelessWidget {
  const _FirstScan({required this.overview, required this.scanning, required this.onScan});

  final SecurityOverview overview;
  final bool scanning;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashCard(
      title: 'No scan has been taken yet',
      icon: Icons.radar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('A scan shows, for every device, what it is connected to right now: which platforms and providers, which applications, and how much data. It also flags behaviour worth a look, such as scanning for open ports, remote desktop or file sharing reaching the internet, VPN tunnels, Tor, torrents, or a device opening thousands of connections.'),
          const SizedBox(height: 12),
          Text('Reading the connection table loads the router for several seconds. That is why a scan runs only when you ask for it.', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: scanning || overview.settings.scanning ? null : onScan,
            icon: scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.radar),
            label: Text(scanning ? 'Scanning…' : 'Run the first scan'),
          ),
        ],
      ),
    );
  }
}

class _RestoredNote extends StatelessWidget {
  const _RestoredNote({required this.scan});

  final ScanMeta scan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(Icons.history, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text('Showing the scan from ${formatAge(DateTime.now().difference(scan.takenAt))}, restored after a restart. Single connections are not kept; scan again to see them.', style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _SummaryTiles extends StatelessWidget {
  const _SummaryTiles({required this.overview});

  final SecurityOverview overview;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, StatusTone tone, String value, String label, String? detail) => _Tile(icon: icon, tone: tone, value: value, label: label, detail: detail);
    final newMeaningful = overview.newDevicesMeaningful;
    final tiles = [
      tile(Icons.gpp_bad_outlined, overview.high > 0 ? StatusTone.error : StatusTone.neutral, '${overview.high}', 'High findings', overview.high == 0 ? 'Nothing urgent' : 'Look at these first'),
      tile(Icons.warning_amber_rounded, overview.medium > 0 ? StatusTone.warning : StatusTone.neutral, '${overview.medium}', 'Medium findings', null),
      tile(Icons.devices_other, StatusTone.neutral, '${overview.devices}', 'Devices in the scan', '${formatCount(overview.connections)} connections'),
      tile(Icons.fiber_new_outlined, StatusTone.neutral, newMeaningful ? '${overview.newDeviceCount}' : '—', 'New devices (24 h)',
          newMeaningful ? null : 'Meaningful after the first day'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 1000 ? 4 : 2;
      const gap = 12.0;
      final width = (c.maxWidth - gap * (cols - 1)) / cols;
      return Wrap(spacing: gap, runSpacing: gap, children: [for (final t in tiles) SizedBox(width: width, child: t)]);
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.tone, required this.value, required this.label, this.detail});

  final IconData icon;
  final StatusTone tone;
  final String value;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = toneStyle(context, tone);
    return Semantics(
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: style.background, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Icon(icon, color: style.foreground, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: style.foreground)),
                    Text(label, style: theme.textTheme.labelLarge),
                    if (detail != null) Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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

class _FindingsCard extends StatelessWidget {
  const _FindingsCard({required this.overview, required this.onOpen});

  final SecurityOverview overview;
  final ValueChanged<SecurityFinding> onOpen;

  @override
  Widget build(BuildContext context) {
    final findings = overview.findings;
    return DashCard(
      title: 'Findings',
      icon: Icons.shield_outlined,
      subtitle: 'What the last scan saw that is worth a look, worst first',
      child: findings.isEmpty
          ? const EmptyNotice(icon: Icons.verified_outlined, title: 'Nothing unusual in the last scan', detail: 'No scanning, exposed services, tunnels, Tor, torrents or connection floods were seen.')
          : Column(
              children: [
                for (final f in findings) Padding(padding: const EdgeInsets.only(bottom: 10), child: FindingTile(finding: f, onOpenDevice: () => onOpen(f))),
              ],
            ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.title, required this.icon, required this.items, required this.byData, this.note});

  final String title;
  final IconData icon;
  final List<DestinationUse> items;
  final bool byData;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return DashCard(
      title: title,
      icon: icon,
      subtitle: 'Connections open during the last scan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DestinationRanking(items: items, byData: byData),
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline, size: 16, color: muted),
              const SizedBox(width: 8),
              Expanded(child: Text(note!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted))),
            ]),
          ],
        ],
      ),
    );
  }
}

class _PopularCard extends StatelessWidget {
  const _PopularCard({required this.items});

  final List<PopularDestination> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashCard(
      title: 'Most used over the last 7 days',
      icon: Icons.trending_up,
      subtitle: 'Ranked by how many devices used it, across every scan',
      child: items.isEmpty
          ? const EmptyNotice(icon: Icons.hourglass_empty, title: 'Not enough scans yet', detail: 'Each scan adds to this ranking, so it becomes useful after a few.')
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final p in items)
                  Chip(
                    avatar: Icon(labelIcon(p.kind), size: 16),
                    label: Text('${p.label}  ·  ${p.devices} device${p.devices == 1 ? '' : 's'}  ·  ${p.scans} scan${p.scans == 1 ? '' : 's'}', style: theme.textTheme.labelMedium),
                  ),
              ],
            ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({
    required this.overview,
    required this.search,
    required this.flaggedOnly,
    required this.wide,
    required this.onSearch,
    required this.onFlaggedOnly,
    required this.onOpen,
  });

  final SecurityOverview overview;
  final TextEditingController search;
  final bool flaggedOnly;
  final bool wide;
  final VoidCallback onSearch;
  final ValueChanged<bool> onFlaggedOnly;
  final ValueChanged<DeviceActivity> onOpen;

  @override
  Widget build(BuildContext context) {
    final terms = search.text.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    final shown = overview.deviceList.where((d) {
      if (flaggedOnly && !d.flagged) return false;
      if (terms.isEmpty) return true;
      final hay = [d.name, d.ip, d.mac, ...d.top.map((t) => t.name)].join(' ').toLowerCase();
      return terms.every(hay.contains);
    }).toList();

    return DashCard(
      title: 'Devices',
      icon: Icons.devices_other,
      subtitle: 'Who is connected to what, flagged devices first',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: search,
                  onChanged: (_) => onSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search a device, address or destination (for example YouTube)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(label: const Text('Flagged only'), selected: flaggedOnly, onSelected: onFlaggedOnly),
            ],
          ),
          const SizedBox(height: 10),
          if (shown.isEmpty)
            const EmptyNotice(icon: Icons.search_off, title: 'No device matches', detail: 'Try a different search.')
          else
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
              wide ? DeviceActivityRow(device: shown[i], onTap: () => onOpen(shown[i])) : DeviceActivityCard(device: shown[i], onTap: () => onOpen(shown[i])),
            ],
        ],
      ),
    );
  }
}

class _NewDevicesCard extends StatelessWidget {
  const _NewDevicesCard({required this.overview});

  final SecurityOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final meaningful = overview.newDevicesMeaningful;
    return DashCard(
      title: meaningful ? 'New devices in the last 24 hours' : 'Devices recorded so far',
      icon: Icons.fiber_new_outlined,
      subtitle: meaningful ? 'A device nobody expected is the first thing to check' : 'The NMS started recording devices recently, so every device counts as new for now',
      child: Column(
        children: [
          for (final d in overview.newDevices.take(15))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(d.online ? Icons.circle : Icons.circle_outlined, size: 12, color: d.online ? Colors.green.shade600 : muted),
                  const SizedBox(width: 10),
                  Expanded(flex: 4, child: Text(d.name, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  Expanded(flex: 3, child: Text(d.vendor.isEmpty ? d.kind : d.vendor, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
                  Expanded(flex: 2, child: Text(d.ip, style: theme.textTheme.bodySmall)),
                  Text(d.firstSeen == null ? '' : formatAge(DateTime.now().difference(d.firstSeen!)), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
                ],
              ),
            ),
          if (overview.newDevices.length > 15)
            Align(alignment: Alignment.centerLeft, child: Text('and ${overview.newDevices.length - 15} more', style: theme.textTheme.bodySmall?.copyWith(color: muted))),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.settings});

  final ScanSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget line(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: muted),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
          ]),
        );
    return DashCard(
      title: 'What is recorded, and who can see it',
      icon: Icons.privacy_tip_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line(Icons.check, 'Only destinations: a platform, a provider, an application or an address. No page addresses, no content, no passwords.'),
          line(Icons.history_toggle_off, 'Scan results are deleted after ${settings.retentionDays} days.'),
          line(Icons.fact_check_outlined, 'Opening a device\'s activity and starting a scan are written to the audit log.'),
          line(Icons.schedule, settings.autoIntervalSeconds > 0 ? 'Scans also run automatically every ${(settings.autoIntervalSeconds / 60).round()} minutes.' : 'Scans run only when someone presses Scan now.'),
          line(Icons.speed, 'A scan is refused when the router is above ${settings.maxRouterCpu}% CPU, and scans are spaced out.'),
          const SizedBox(height: 6),
          Text('Watching what people do online has rules of its own. Make sure the hospital\'s policy tells staff and visitors that the network is monitored.', style: theme.textTheme.bodySmall?.copyWith(color: muted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}
