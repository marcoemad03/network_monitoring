import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/datasources/remote/client_remote_datasource.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/marco_models.dart';
import '../../../providers/clients/clients_provider.dart';
import '../../../providers/marco/marco_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import 'client_row.dart';
import 'kind_visuals.dart';

const _noGroup = '';

/// Everything about one device, with the fields a person may change: its name,
/// its type and a comment.
class ClientDetailDialog extends ConsumerStatefulWidget {
  const ClientDetailDialog({super.key, required this.device});

  final ClientDevice device;

  @override
  ConsumerState<ClientDetailDialog> createState() => _ClientDetailDialogState();
}

class _ClientDetailDialogState extends ConsumerState<ClientDetailDialog> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late ClientKind? _kind; // null = detect automatically
  late String _group;
  late final String _initialGroup;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _name = TextEditingController(text: d.nameSource == 'custom' ? d.displayName : '');
    _note = TextEditingController(text: d.note);
    _kind = d.kindIsCustom ? d.kind : null;
    final group = ref.read(marcoGroupByMacProvider(d.mac));
    _initialGroup = group?.id ?? _noGroup;
    _group = _initialGroup;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _changed {
    final d = widget.device;
    final nameBefore = d.nameSource == 'custom' ? d.displayName : '';
    final kindBefore = d.kindIsCustom ? d.kind : null;
    return _name.text.trim() != nameBefore || _note.text.trim() != d.note || _kind != kindBefore || _group != _initialGroup;
  }

  Future<void> _save() async {
    final d = widget.device;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final nameBefore = d.nameSource == 'custom' ? d.displayName : '';
      final kindBefore = d.kindIsCustom ? d.kind : null;
      final source = ref.read(clientRemoteProvider);
      if (_name.text.trim() != nameBefore || _note.text.trim() != d.note || _kind != kindBefore) {
        await source.saveNote(
          d.mac,
          displayName: _name.text.trim() != nameBefore ? _name.text.trim() : null,
          note: _note.text.trim() != d.note ? _note.text.trim() : null,
          kind: _kind != kindBefore ? (_kind?.name ?? '') : null,
        );
      }
      if (_group != _initialGroup) await _saveGroup(d);
      ref.invalidate(clientFeedProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ClientApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveGroup(ClientDevice d) async {
    final controller = ref.read(marcoGroupsProvider.notifier);
    if (_group == _noGroup) {
      final old = ref.read(marcoGroupByMacProvider(d.mac));
      final member = old?.members.where((m) => (m.macAddress ?? '').toUpperCase() == d.mac.toUpperCase()).firstOrNull;
      if (old != null && member != null) await controller.removeMember(old.id, member.deviceId);
    } else {
      await controller.assignDevice(_group, d.mac);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.device;
    final theme = Theme.of(context);
    final groups = ref.watch(marcoGroupsProvider).valueOrNull?.groups ?? const <MarcoGroup>[];
    final narrow = MediaQuery.sizeOf(context).width < 640;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(device: d),
        const SizedBox(height: 18),
        _section(theme, 'Name and type'),
        TextField(
          controller: _name,
          maxLength: 80,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Name',
            helperText: 'Leave empty to use ${d.hostname.isNotEmpty ? '"${d.hostname}"' : 'the address'}',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<ClientKind?>(
          initialValue: _kind,
          decoration: InputDecoration(
            labelText: 'Type',
            helperText: d.kindIsCustom ? 'Set by you' : '${confidenceLabel(d.confidence)}: ${d.kindReason}',
            helperMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          items: [
            DropdownMenuItem<ClientKind?>(
              value: null,
              child: Text(d.kindIsCustom || d.kind == ClientKind.unknown ? 'Detect automatically' : 'Detect automatically (${d.kind.label})'),
            ),
            for (final k in ClientKind.values.where((k) => k != ClientKind.unknown))
              DropdownMenuItem<ClientKind?>(value: k, child: Row(children: [Icon(kindIcon(k), size: 18), const SizedBox(width: 10), Text(k.label)])),
          ],
          onChanged: (v) => setState(() => _kind = v),
        ),
        const SizedBox(height: 14),
        _section(theme, 'Comment'),
        TextField(
          controller: _note,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Comment',
            hintText: 'Who uses it, where it is, anything worth remembering',
            border: OutlineInputBorder(),
          ),
        ),
        if (d.routerComment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(Icons.router_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(child: Text('On the router: ${d.routerComment}', style: theme.textTheme.bodySmall)),
                if (_note.text.trim() != d.routerComment)
                  TextButton(onPressed: () => setState(() => _note.text = d.routerComment), child: const Text('Use this')),
              ],
            ),
          ),
        const SizedBox(height: 8),
        _section(theme, 'Usage'),
        _UsagePanel(device: d),
        const SizedBox(height: 16),
        _section(theme, 'Details'),
        _Facts(device: d),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 16),
          _section(theme, 'Marco group'),
          DropdownButtonFormField<String>(
            initialValue: groups.any((g) => g.id == _group) ? _group : _noGroup,
            decoration: const InputDecoration(border: OutlineInputBorder(), helperText: 'A device can belong to one group; its policies apply to it.'),
            items: [
              const DropdownMenuItem(value: _noGroup, child: Text('No group')),
              for (final g in groups) DropdownMenuItem(value: g.id, child: Text(g.name)),
            ],
            onChanged: (v) => setState(() => _group = v ?? _noGroup),
          ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error))),
              ],
            ),
          ),
      ],
    );

    final actions = [
      TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Close')),
      FilledButton.icon(
        onPressed: (_changed && !_saving) ? _save : null,
        icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ];

    final content = SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 8), child: body);
    if (narrow) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: const Text('Device'), leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.of(context).pop(false))),
          body: content,
          bottomNavigationBar: SafeArea(child: Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: actions))),
        ),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: content),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [actions[0], const SizedBox(width: 8), actions[1]])),
          ],
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          KindAvatar(device: device, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  [device.kind == ClientKind.unknown ? 'Unknown type' : device.kind.label, if (device.brand.isNotEmpty) device.brand].join(' · '),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          StatusPill(tone: device.online ? StatusTone.ok : StatusTone.neutral, icon: device.online ? Icons.circle : Icons.circle_outlined, label: device.online ? 'Online' : 'Offline'),
        ],
      ),
    );
  }
}

class _UsagePanel extends ConsumerWidget {
  const _UsagePanel({required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!device.hasCounters && device.monthTotal == 0) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: muted),
          const SizedBox(width: 8),
          Expanded(child: Text('Usage is measured only for devices connected through the hotspot. This one is not.', style: theme.textTheme.bodySmall?.copyWith(color: muted))),
        ],
      );
    }
    final days = ref.watch(clientUsageProvider(device.mac));
    Widget tile(String label, int down, int up) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
              Text(formatBytes(down + up), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('↓ ${formatBytes(down)}  ↑ ${formatBytes(up)}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            tile('Today', device.todayDownload, device.todayUpload),
            tile('This month', device.monthDownload, device.monthUpload),
            if (device.online) tile('This connection', device.sessionDownload, device.sessionUpload),
          ],
        ),
        if (device.online && device.hasCounters) ...[
          const SizedBox(height: 8),
          Text('Right now: ↓ ${formatBitrate(device.downloadBps)}   ↑ ${formatBitrate(device.uploadBps)}', style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 12),
        days.when(
          loading: () => const SkeletonBox(height: 100),
          error: (_, __) => Text('Could not load the daily usage.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          data: (rows) => _DailyBars(rows: rows),
        ),
        const SizedBox(height: 4),
        Text('Counted from when monitoring began.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.rows});

  final List<ClientDay> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateTime.now();
    final days = [
      for (var i = 6; i >= 0; i--)
        () {
          final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
          final match = rows.where((r) => r.day.year == day.year && r.day.month == day.month && r.day.day == day.day);
          return (day: day, total: match.fold<int>(0, (s, r) => s + r.total));
        }(),
    ];
    final maxBytes = days.map((d) => d.total).fold<int>(0, (a, b) => a > b ? a : b);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (maxBytes == 0) {
      return Text('No usage recorded in the last 7 days.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
    }
    return SizedBox(
      height: 110,
      child: BarChart(
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 250),
        BarChartData(
          maxY: maxBytes * 1.15,
          minY: 0,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(i == days.length - 1 ? 'Today' : names[days[i].day.weekday - 1], style: theme.textTheme.labelSmall),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                '${names[days[group.x].day.weekday - 1]}  ${formatBytes(days[group.x].total)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: days[i].total.toDouble(),
                  width: 18,
                  color: theme.colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final rows = <_Fact>[
      _Fact('IP address', d.ip.isEmpty ? '—' : d.ip, copy: d.ip.isNotEmpty),
      _Fact('MAC address', d.mac, copy: true, hint: d.privateMac ? 'Private address: changes per network, common on phones and laptops' : null),
      _Fact('Host name', d.hostname.isEmpty ? 'not announced' : d.hostname, copy: d.hostname.isNotEmpty),
      if (d.brand.isNotEmpty) _Fact('Brand', d.brand),
      if (d.vendor.isNotEmpty) _Fact('Made by', d.vendor, hint: 'The company the IEEE registered this MAC address block to'),
      _Fact('Network', d.network.isEmpty ? '—' : d.network),
      if (d.online && d.uptimeSeconds > 0) _Fact('Connected for', formatUptime(d.uptimeSeconds)),
      if (d.firstSeen != null) _Fact('First seen', _date(d.firstSeen!)),
      if (d.lastSeen != null) _Fact('Last seen', d.online ? 'now' : _date(d.lastSeen!)),
    ];
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 120, child: Text(r.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
                Expanded(child: SelectableText(r.value, style: theme.textTheme.bodyMedium)),
                if (r.hint != null) Tooltip(message: r.hint!, child: Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant)),
                if (r.copy)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: r.value));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.label} copied'), duration: const Duration(seconds: 2)));
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static String _date(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.day}/${t.month}/${t.year}  ${two(t.hour)}:${two(t.minute)}';
  }
}

class _Fact {
  const _Fact(this.label, this.value, {this.copy = false, this.hint});

  final String label;
  final String value;
  final bool copy;
  final String? hint;
}
