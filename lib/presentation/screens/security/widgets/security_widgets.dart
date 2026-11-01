import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../../../data/models/security_models.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../devices/widgets/kind_visuals.dart';

/// Icon for a destination kind. Always shown next to the kind's name.
IconData labelIcon(LabelKind k) => switch (k) {
      LabelKind.platform => Icons.public,
      LabelKind.provider => Icons.cloud_outlined,
      LabelKind.app => Icons.apps,
      LabelKind.internal => Icons.lan_outlined,
      LabelKind.other => Icons.help_outline,
    };

String labelKindName(LabelKind k) => switch (k) {
      LabelKind.platform => 'Platform',
      LabelKind.provider => 'Provider',
      LabelKind.app => 'Application',
      LabelKind.internal => 'Inside the network',
      LabelKind.other => 'Unidentified host',
    };

StatusTone severityTone(Severity s) => switch (s) {
      Severity.high => StatusTone.error,
      Severity.medium => StatusTone.warning,
      _ => StatusTone.neutral,
    };

IconData severityIcon(Severity s) => switch (s) {
      Severity.high => Icons.gpp_bad_outlined,
      Severity.medium => Icons.warning_amber_rounded,
      _ => Icons.info_outline,
    };

/// A finding: how bad, on which device, what was seen and what to do.
class FindingTile extends StatelessWidget {
  const FindingTile({super.key, required this.finding, this.onOpenDevice});

  final SecurityFinding finding;
  final VoidCallback? onOpenDevice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tone = toneStyle(context, severityTone(finding.severity));
    return Semantics(
      container: true,
      label: '${finding.severity.label} severity. ${finding.title}. Device ${finding.device}.',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tone.background,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: tone.foreground, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusPill(tone: severityTone(finding.severity), icon: severityIcon(finding.severity), label: finding.severity.label),
                Text(finding.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.devices_other, size: 15, color: muted),
                const SizedBox(width: 6),
                Flexible(child: Text('${finding.device}  ·  ${finding.ip}', style: theme.textTheme.bodySmall?.copyWith(color: muted), overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (finding.detail.isNotEmpty) ...[const SizedBox(height: 8), Text(finding.detail, style: theme.textTheme.bodyMedium)],
            if (finding.action.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.arrow_forward, size: 16, color: tone.foreground),
                  const SizedBox(width: 6),
                  Expanded(child: Text(finding.action, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                ],
              ),
            ],
            if (onOpenDevice != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(onPressed: onOpenDevice, icon: const Icon(Icons.open_in_new, size: 16), label: const Text('See this device')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Destinations ranked by data or by the number of devices, as bars.
class DestinationRanking extends StatelessWidget {
  const DestinationRanking({super.key, required this.items, required this.byData, this.empty = 'Nothing to rank yet'});

  final List<DestinationUse> items;
  final bool byData;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (items.isEmpty) return Text(empty, style: theme.textTheme.bodySmall?.copyWith(color: muted));
    double value(DestinationUse d) => byData ? d.totalBytes.toDouble() : d.devices.toDouble();
    final max = items.map(value).fold<double>(0, (a, b) => a > b ? a : b);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Semantics(
              label: '${i + 1}. ${items[i].name}, ${labelKindName(items[i].kind)}, ${formatBytes(items[i].totalBytes)}, ${items[i].devices} devices, ${items[i].connections} connections',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 22, child: Text('${i + 1}', style: theme.textTheme.labelMedium?.copyWith(color: muted))),
                        Tooltip(message: labelKindName(items[i].kind), child: Icon(labelIcon(items[i].kind), size: 16, color: muted)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(items[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                        const SizedBox(width: 8),
                        Text(
                          byData ? formatBytes(items[i].totalBytes) : '${items[i].devices} device${items[i].devices == 1 ? '' : 's'}',
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, top: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: max == 0 ? 0 : value(items[i]) / max,
                                minHeight: 5,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            byData ? '${items[i].devices} device${items[i].devices == 1 ? '' : 's'} · ${items[i].connections} conn.' : '${formatBytes(items[i].totalBytes)} · ${items[i].connections} conn.',
                            style: theme.textTheme.bodySmall?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One device in the activity table.
class DeviceActivityRow extends StatelessWidget {
  const DeviceActivityRow({super.key, required this.device, required this.onTap});

  final DeviceActivity device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final kind = ClientKind.parse(device.kind);
    final risk = device.high > 0 ? StatusTone.error : device.medium > 0 ? StatusTone.warning : null;
    return Semantics(
      button: true,
      label: '${device.name}, ${device.connections} connections, ${formatBytes(device.totalBytes)}'
          '${device.high > 0 ? ', ${device.high} high findings' : ''}${device.medium > 0 ? ', ${device.medium} medium findings' : ''}. Opens details.',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(kindIcon(kind), color: muted),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(device.ip, style: theme.textTheme.bodySmall?.copyWith(color: muted, fontFamilyFallback: const ['Consolas', 'monospace'])),
                    ],
                  ),
                ),
                Expanded(flex: 2, child: Text('${device.connections} connections', style: theme.textTheme.bodyMedium)),
                Expanded(
                  flex: 3,
                  child: Text('↓ ${formatBytes(device.downloadBytes)}   ↑ ${formatBytes(device.uploadBytes)}', style: theme.textTheme.bodyMedium),
                ),
                Expanded(
                  flex: 6,
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final d in device.top.take(3))
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(labelIcon(d.kind), size: 14),
                          label: Text(d.name, overflow: TextOverflow.ellipsis),
                          labelStyle: theme.textTheme.labelSmall,
                          padding: EdgeInsets.zero,
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: risk == null
                      ? Text('Nothing flagged', style: theme.textTheme.bodySmall?.copyWith(color: muted))
                      : StatusPill(
                          tone: risk,
                          icon: risk == StatusTone.error ? Icons.gpp_bad_outlined : Icons.warning_amber_rounded,
                          label: device.high > 0 ? '${device.high} high' : '${device.medium} medium',
                        ),
                ),
                Icon(Icons.chevron_right, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A narrow-screen version of [DeviceActivityRow].
class DeviceActivityCard extends StatelessWidget {
  const DeviceActivityCard({super.key, required this.device, required this.onTap});

  final DeviceActivity device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final risk = device.high > 0 ? StatusTone.error : device.medium > 0 ? StatusTone.warning : null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(kindIcon(ClientKind.parse(device.kind)), color: muted),
                const SizedBox(width: 10),
                Expanded(child: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                if (risk != null) StatusPill(tone: risk, label: device.high > 0 ? '${device.high} high' : '${device.medium} medium'),
              ],
            ),
            const SizedBox(height: 4),
            Text('${device.ip}  ·  ${device.connections} connections  ·  ↓ ${formatBytes(device.downloadBytes)}  ↑ ${formatBytes(device.uploadBytes)}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            if (device.top.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(device.top.take(3).map((d) => d.name).join('  ·  '), style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
