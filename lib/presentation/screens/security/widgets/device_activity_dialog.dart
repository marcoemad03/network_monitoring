import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/security_models.dart';
import '../../../providers/security/security_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../devices/widgets/kind_visuals.dart';
import '../../sites/widgets/device_sites.dart';
import '../../sites/widgets/site_widgets.dart' show DeviceKindChip;
import 'security_widgets.dart';

/// What one device is connected to, from the latest scan.
class DeviceActivityDialog extends ConsumerWidget {
  const DeviceActivityDialog({super.key, required this.deviceKey, required this.name, required this.findings});

  final String deviceKey;
  final String name;
  final List<SecurityFinding> findings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(securityDeviceProvider(deviceKey));
    final narrow = MediaQuery.sizeOf(context).width < 700;

    final body = detail.when(
      loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Padding(
        padding: EdgeInsets.all(24),
        child: EmptyNotice(icon: Icons.search_off, title: 'No scan has seen this device', detail: 'It was not connected through the router when the last scan ran, or no scan has been taken yet.'),
      ),
      data: (d) => _Content(detail: d, findings: findings),
    );

    final close = TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'));
    if (narrow) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(title: Text(name, overflow: TextOverflow.ellipsis), leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: () => Navigator.of(context).pop())),
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: body),
        ),
      );
    }
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 820),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 20, 24, 8), child: body)),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(10), child: Align(alignment: Alignment.centerRight, child: close)),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.detail, required this.findings});

  final DeviceDetail detail;
  final List<SecurityFinding> findings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final d = detail.device;
    final mine = findings.where((f) => f.deviceKey == d.key || f.ip == d.ip).toList();
    final age = DateTime.now().difference(detail.scan.takenAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: theme.colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)),
              child: Icon(kindIcon(ClientKind.parse(d.kind)), color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(child: Text(d.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                    const SizedBox(width: 10),
                    DeviceKindChip(kind: d.kind),
                  ]),
                  SelectableText('${d.ip}${d.mac.isEmpty ? '' : '  ·  ${d.mac}'}', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'As of the scan ${formatAge(age)}: ${d.connections} open connections to ${d.destinations} destinations, ↓ ${formatBytes(d.downloadBytes)} received and ↑ ${formatBytes(d.uploadBytes)} sent over those connections.',
          style: theme.textTheme.bodyMedium,
        ),
        if (mine.isNotEmpty) ...[
          const SizedBox(height: 16),
          _heading(theme, 'Findings'),
          for (final f in mine) Padding(padding: const EdgeInsets.only(bottom: 8), child: FindingTile(finding: f)),
        ],
        const SizedBox(height: 16),
        _heading(theme, 'Websites in the last 24 hours'),
        DeviceSitesSection(deviceKey: d.mac.isNotEmpty ? d.mac : d.ip),
        const SizedBox(height: 16),
        _heading(theme, 'Open right now'),
        if (d.top.isEmpty)
          Text('No connections were open.', style: theme.textTheme.bodySmall?.copyWith(color: muted))
        else
          DestinationRanking(items: d.top.take(12).toList(), byData: true),
        if (d.flows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _heading(theme, 'Busiest connections'),
          _FlowTable(flows: d.flows.take(25).toList()),
        ],
        if (detail.scan.restored)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('This scan was restored after a restart, so the list of single connections is not available. Scan again to see it.', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
          ),
        const SizedBox(height: 16),
        _heading(theme, 'Seen over the last 7 days'),
        if (detail.history.isEmpty)
          Text('Not enough scans yet. Each scan adds to this list.', style: theme.textTheme.bodySmall?.copyWith(color: muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final h in detail.history)
                Chip(
                  avatar: Icon(labelIcon(h.kind), size: 16),
                  label: Text('${h.label}  ·  ${h.scans} scan${h.scans == 1 ? '' : 's'}'),
                ),
            ],
          ),
        const SizedBox(height: 12),
        Text(
          'Only destinations are recorded, never page addresses or content. Opening this view is written to the audit log.',
          style: theme.textTheme.bodySmall?.copyWith(color: muted),
        ),
      ],
    );
  }

  Widget _heading(ThemeData theme, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Semantics(header: true, child: Text(text, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
      );
}

class _FlowTable extends StatelessWidget {
  const _FlowTable({required this.flows});

  final List<FlowLine> flows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamilyFallback: const ['Consolas', 'monospace']);
    final head = theme.textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w700);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(flex: 4, child: Text('Destination', style: head)),
            Expanded(flex: 4, child: Text('What it is', style: head)),
            Expanded(flex: 3, child: Text('Data', style: head)),
          ]),
        ),
        for (final f in flows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(flex: 4, child: SelectableText('${f.protocol.toUpperCase()} ${f.destination}:${f.port}', style: mono)),
                Expanded(
                  flex: 4,
                  child: Row(children: [
                    Icon(labelIcon(f.kind), size: 14, color: muted),
                    const SizedBox(width: 6),
                    Flexible(child: Text(f.app.isNotEmpty && f.kind == LabelKind.other ? f.app : f.label, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                  ]),
                ),
                Expanded(flex: 3, child: Text('↓ ${formatBytes(f.downloadBytes)}  ↑ ${formatBytes(f.uploadBytes)}', style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
      ],
    );
  }
}
