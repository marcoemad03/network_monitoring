import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/client_inventory_models.dart';
import '../../dashboard/widgets/dash_card.dart';
import 'kind_visuals.dart';

/// How wide the list is, which decides the columns shown.
enum ClientLayout { full, compact, card }

ClientLayout layoutFor(double width) => width >= 1180
    ? ClientLayout.full
    : width >= 860
        ? ClientLayout.compact
        : ClientLayout.card;

const _rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 10);

/// Column titles of the wide layouts.
class ClientHeaderRow extends StatelessWidget {
  const ClientHeaderRow({super.key, required this.layout});

  final ClientLayout layout;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        );
    Widget cell(String text, int flex) => Expanded(flex: flex, child: Text(text, style: style));
    return Padding(
      padding: _rowPadding,
      child: Row(
        children: [
          const SizedBox(width: 56),
          cell('Device', 28),
          cell('Address', 20),
          cell('Speed now', 18),
          cell('Used today', 20),
          if (layout == ClientLayout.full) cell('Comment', 26),
          cell('Status', 14),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

/// One device in the wide table.
class ClientTableRow extends StatelessWidget {
  const ClientTableRow({
    super.key,
    required this.device,
    required this.layout,
    required this.maxToday,
    required this.groupName,
    required this.onTap,
  });

  final ClientDevice device;
  final ClientLayout layout;
  final int maxToday;
  final String? groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: _semanticLabel(),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: _rowPadding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                KindAvatar(device: device),
                const SizedBox(width: 12),
                Expanded(flex: 28, child: _NameCell(device: device, groupName: groupName)),
                Expanded(
                  flex: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.ip.isEmpty ? 'no address' : device.ip, style: _mono(theme)),
                      Text(device.mac, style: _mono(theme)?.copyWith(color: muted, fontSize: 11)),
                    ],
                  ),
                ),
                Expanded(flex: 18, child: _SpeedCell(device: device)),
                Expanded(flex: 20, child: UsageCell(device: device, maxToday: maxToday)),
                if (layout == ClientLayout.full) Expanded(flex: 26, child: CommentText(device: device)),
                Expanded(flex: 14, child: StatusText(device: device)),
                Icon(Icons.chevron_right, color: muted),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semanticLabel() {
    final status = device.online ? 'online' : 'offline';
    final used = device.hasCounters || device.todayTotal > 0 ? ', used ${formatBytes(device.todayTotal)} today' : '';
    return '${device.displayName}, ${device.kind.label}, $status$used. Opens details.';
  }
}

/// One device in the narrow card list.
class ClientCard extends StatelessWidget {
  const ClientCard({super.key, required this.device, required this.maxToday, required this.groupName, required this.onTap});

  final ClientDevice device;
  final int maxToday;
  final String? groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  KindAvatar(device: device),
                  const SizedBox(width: 12),
                  Expanded(child: _NameCell(device: device, groupName: groupName)),
                  StatusText(device: device),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: Text('${device.ip.isEmpty ? 'no address' : device.ip}  ·  ${device.mac}', style: _mono(theme)?.copyWith(fontSize: 11))),
                ],
              ),
              const SizedBox(height: 8),
              UsageCell(device: device, maxToday: maxToday),
              if (device.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                CommentText(device: device),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

TextStyle? _mono(ThemeData theme) => theme.textTheme.bodySmall?.copyWith(fontFamilyFallback: const ['Consolas', 'monospace']);

/// Round icon of the device kind, with a dot for online/offline.
class KindAvatar extends StatelessWidget {
  const KindAvatar({super.key, required this.device, this.size = 44});

  final ClientDevice device;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final online = device.online;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: online ? scheme.primaryContainer : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(size / 3),
            ),
            child: Icon(kindIcon(device.kind), color: online ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green.shade600 : scheme.outline,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({required this.device, required this.groupName});

  final ClientDevice device;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final detail = [
      device.kind == ClientKind.unknown ? 'Unknown type' : device.kind.label,
      if (device.brand.isNotEmpty) device.brand,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(device.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        Row(
          children: [
            Flexible(child: Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: muted))),
            if (device.confidence == 'low' && !device.kindIsCustom) ...[
              const SizedBox(width: 4),
              Tooltip(message: '${confidenceLabel(device.confidence)}: ${device.kindReason}', child: Icon(Icons.help_outline, size: 14, color: muted)),
            ],
          ],
        ),
        if (groupName != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: StatusPill(tone: StatusTone.neutral, icon: Icons.groups_outlined, label: groupName!),
          ),
      ],
    );
  }
}

class _SpeedCell extends StatelessWidget {
  const _SpeedCell({required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!device.online) return Text('offline', style: theme.textTheme.bodySmall?.copyWith(color: muted));
    if (!device.hasCounters) {
      return Tooltip(message: 'Speed is measured only for devices connected through the hotspot.', child: Text('not measured', style: theme.textTheme.bodySmall?.copyWith(color: muted)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.south, size: 13, color: theme.colorScheme.primary), const SizedBox(width: 4), Text(formatBitrate(device.downloadBps), style: theme.textTheme.bodyMedium)]),
        Row(children: [Icon(Icons.north, size: 13, color: theme.colorScheme.tertiary), const SizedBox(width: 4), Text(formatBitrate(device.uploadBps), style: theme.textTheme.bodySmall?.copyWith(color: muted))]),
      ],
    );
  }
}

/// Today's usage with a bar sized against the busiest device.
class UsageCell extends StatelessWidget {
  const UsageCell({super.key, required this.device, required this.maxToday});

  final ClientDevice device;
  final int maxToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!device.hasCounters && device.todayTotal == 0) {
      return Tooltip(
        message: 'Usage is measured only for devices connected through the hotspot.',
        child: Text('not measured', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      );
    }
    final fraction = maxToday == 0 ? 0.0 : (device.todayTotal / maxToday).clamp(0.0, 1.0);
    return Tooltip(
      message: 'Today: ${formatBytes(device.todayDownload)} down, ${formatBytes(device.todayUpload)} up\nThis month: ${formatBytes(device.monthTotal)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(device.todayTotal == 0 ? '0 B' : formatBytes(device.todayTotal), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 5,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentText extends StatelessWidget {
  const CommentText({super.key, required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (device.comment.isEmpty) {
      return Text('No comment', style: theme.textTheme.bodySmall?.copyWith(color: muted.withValues(alpha: 0.7)));
    }
    return Row(
      children: [
        if (device.commentIsFromRouter)
          Tooltip(message: 'Comment written on the router', child: Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.router_outlined, size: 14, color: muted)))
        else
          Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.sticky_note_2_outlined, size: 14, color: theme.colorScheme.primary)),
        Expanded(child: Text(device.comment, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

class StatusText extends StatelessWidget {
  const StatusText({super.key, required this.device});

  final ClientDevice device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (device.online) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Online', style: theme.textTheme.labelLarge?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.w700)),
          if (device.uptimeSeconds > 0) Text('for ${formatUptime(device.uptimeSeconds)}', style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      );
    }
    final seen = device.lastSeen;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Offline', style: theme.textTheme.labelLarge?.copyWith(color: muted, fontWeight: FontWeight.w700)),
        if (seen != null) Text(formatAge(DateTime.now().difference(seen)), style: theme.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}
