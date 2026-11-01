import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/wan_usage_models.dart';
import 'dash_card.dart';

/// How much internet was used in a period, split into download and upload.
class UsageCard extends StatelessWidget {
  const UsageCard({
    super.key,
    required this.title,
    required this.icon,
    required this.data,
    required this.loading,
    required this.period,
    this.footnote,
  });

  final String title;
  final IconData icon;
  final WanUsage? data;
  final bool loading;
  final WanPeriod Function(WanUsage usage) period;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final usage = data;
    return DashCard(title: title, icon: icon, child: _body(context, usage));
  }

  Widget _body(BuildContext context, WanUsage? usage) {
    if (usage == null) {
      return loading
          ? const Column(children: [SkeletonBox(height: 44), SizedBox(height: 12), SkeletonBox(height: 10)])
          : const EmptyNotice(icon: Icons.cloud_off, title: 'No data yet');
    }
    if (!usage.available) {
      return const EmptyNotice(icon: Icons.router_outlined, title: 'Not measured', detail: 'Waiting for the router.');
    }
    final p = period(usage);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final total = splitBytes(p.totalBytes);
    final downColor = theme.colorScheme.primary;
    final upColor = theme.colorScheme.tertiary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '$title total ${formatBytes(p.totalBytes)}, download ${formatBytes(p.downloadBytes)}, upload ${formatBytes(p.uploadBytes)}',
          child: ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  total.value,
                  style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
                const SizedBox(width: 6),
                Text(total.unit, style: theme.textTheme.titleMedium?.copyWith(color: muted)),
                const SizedBox(width: 8),
                Text('total', style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SplitBar(down: p.downloadBytes, up: p.uploadBytes, downColor: downColor, upColor: upColor),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _Figure(icon: Icons.south, color: downColor, label: 'Download', value: formatBytes(p.downloadBytes))),
            Expanded(child: _Figure(icon: Icons.north, color: upColor, label: 'Upload', value: formatBytes(p.uploadBytes))),
          ],
        ),
        if (p.peakDownloadBps > 0) ...[
          const SizedBox(height: 10),
          Text(
            'Peak speed  ${formatBitrate(p.peakDownloadBps)} down · ${formatBitrate(p.peakUploadBps)} up',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
        if (footnote != null) ...[
          const SizedBox(height: 6),
          Text(footnote!, style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.icon, required this.color, required this.label, required this.value});

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$label  ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              TextSpan(text: value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Download vs upload share of the traffic. The two parts are labelled below,
/// so the colors are only a visual aid.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.down, required this.up, required this.downColor, required this.upColor});

  final int down;
  final int up;
  final Color downColor;
  final Color upColor;

  @override
  Widget build(BuildContext context) {
    final total = down + up;
    final track = Theme.of(context).colorScheme.surfaceContainerHighest;
    if (total == 0) {
      return Container(height: 10, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(5)));
    }
    final downFlex = (down * 1000 / total).round().clamp(1, 999);
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 10,
        child: Row(
          children: [
            Expanded(flex: downFlex, child: ColoredBox(color: downColor)),
            const SizedBox(width: 2),
            Expanded(flex: 1000 - downFlex, child: ColoredBox(color: upColor)),
          ],
        ),
      ),
    );
  }
}
