import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/wan_usage_models.dart';
import 'dash_card.dart';

/// The router's own load, measured on the router.
class RouterHealthCard extends StatelessWidget {
  const RouterHealthCard({super.key, required this.data, required this.loading});

  final WanUsage? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final usage = data;
    final router = usage?.router;
    return DashCard(
      title: 'Router',
      icon: Icons.router_outlined,
      trailing: usage == null || !usage.available
          ? null
          : StatusPill(
              tone: usage.linkRunning ? StatusTone.ok : StatusTone.error,
              label: usage.linkRunning ? 'Internet link up' : 'Internet link down',
            ),
      child: usage == null
          ? (loading
              ? const Column(children: [SkeletonBox(height: 14), SizedBox(height: 14), SkeletonBox(height: 14)])
              : const EmptyNotice(icon: Icons.cloud_off, title: 'No data yet'))
          : router == null
              ? const EmptyNotice(icon: Icons.router_outlined, title: 'Router not connected', detail: 'No readings available.')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoadBar(label: 'CPU', percent: router.cpuLoadPercent.toDouble()),
                    const SizedBox(height: 14),
                    _LoadBar(label: 'Memory', percent: router.memoryUsedPercent),
                    const SizedBox(height: 16),
                    _Fact(icon: Icons.schedule, label: 'Running for', value: formatUptime(router.uptimeSeconds)),
                    if (router.board.isNotEmpty) _Fact(icon: Icons.memory, label: 'Model', value: router.board),
                    if (router.version.isNotEmpty) _Fact(icon: Icons.system_update_alt, label: 'RouterOS', value: router.version),
                  ],
                ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.label, required this.percent});

  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = percent >= 90 ? StatusTone.error : percent >= 70 ? StatusTone.warning : StatusTone.ok;
    final style = toneStyle(context, tone);
    final state = percent >= 90 ? 'Critical' : percent >= 70 ? 'High' : 'Normal';
    return Semantics(
      label: '$label ${percent.round()} percent, $state',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label, style: theme.textTheme.labelLarge),
                const Spacer(),
                Text('${percent.round()}%', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                // The state is written out, so the bar color is not the only signal.
                Text(state, style: theme.textTheme.labelMedium?.copyWith(color: style.foreground, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                color: style.foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, textAlign: TextAlign.end, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
