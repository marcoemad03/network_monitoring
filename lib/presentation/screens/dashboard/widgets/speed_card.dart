import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/wan_usage_models.dart';
import 'dash_card.dart';

/// Current internet speed with a chart of the last hour.
class SpeedCard extends StatelessWidget {
  const SpeedCard({super.key, required this.data, required this.loading});

  final WanUsage? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final usage = data;
    return DashCard(
      title: 'Internet speed',
      icon: Icons.speed,
      subtitle: usage?.interfaceName == null ? null : 'Measured on the router link ${usage!.interfaceName}',
      child: _body(context, usage),
    );
  }

  Widget _body(BuildContext context, WanUsage? usage) {
    if (usage == null) {
      return loading
          ? const Column(children: [SkeletonBox(height: 56), SizedBox(height: 16), SkeletonBox(height: 180)])
          : const EmptyNotice(icon: Icons.cloud_off, title: 'No data yet', detail: 'The NMS server has not answered.');
    }
    final current = usage.current;
    if (!usage.available || current == null) {
      return EmptyNotice(
        icon: Icons.router_outlined,
        title: 'Router not connected',
        detail: usage.error ?? 'Connect the MikroTik router to measure internet speed.',
      );
    }
    final theme = Theme.of(context);
    final downColor = theme.colorScheme.primary;
    final upColor = theme.colorScheme.tertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 40,
          runSpacing: 12,
          children: [
            _Metric(
              icon: Icons.south,
              label: 'Download',
              bps: current.downloadBps,
              color: downColor,
              dimmed: usage.stale,
            ),
            _Metric(
              icon: Icons.north,
              label: 'Upload',
              bps: current.uploadBps,
              color: upColor,
              dimmed: usage.stale,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _SpeedChart(usage: usage, downColor: downColor, upColor: upColor),
        const SizedBox(height: 10),
        Row(
          children: [
            _LegendItem(color: downColor, label: 'Download'),
            const SizedBox(width: 18),
            _LegendItem(color: upColor, label: 'Upload', dashed: true),
            const Spacer(),
            Text(
              'Last hour',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.bps, required this.color, required this.dimmed});

  final IconData icon;
  final String label;
  final int bps;
  final Color color;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = splitBitrate(bps);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      label: '$label speed ${formatBitrate(bps)}${dimmed ? ', out of date' : ''}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      parts.value,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: dimmed ? muted : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(parts.unit, style: theme.textTheme.titleSmall?.copyWith(color: muted)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The upload line is dashed in the chart, so the legend does not rely on color alone.
        SizedBox(
          width: 22,
          height: 3,
          child: dashed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(3, (_) => Container(width: 5, height: 3, color: color)),
                )
              : Container(color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _SpeedChart extends StatelessWidget {
  const _SpeedChart({required this.usage, required this.downColor, required this.upColor});

  final WanUsage usage;
  final Color downColor;
  final Color upColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = (usage.live.length >= 3 ? usage.live : usage.lastHour).toList()
      ..sort((a, b) => a.at.compareTo(b.at));

    if (points.length < 2) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'Collecting data for the chart…',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final now = DateTime.now();
    double xOf(WanPoint p) => p.at.difference(now).inMilliseconds / 60000.0;
    final down = [for (final p in points) FlSpot(xOf(p), p.downloadBps / 1e6)];
    final up = [for (final p in points) FlSpot(xOf(p), p.uploadBps / 1e6)];
    final peak = points.map((p) => math.max(p.downloadBps, p.uploadBps)).reduce(math.max) / 1e6;
    final maxY = _niceCeiling(math.max(peak * 1.2, 1));
    final minX = math.min(down.first.x, -1.0);
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final muted = theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 180,
      child: LineChart(
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
        LineChartData(
          minX: minX,
          maxX: 0,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) => FlLine(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 4,
                getTitlesWidget: (v, meta) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    v == 0 ? '0' : _axisLabel(v),
                    textAlign: TextAlign.right,
                    style: theme.textTheme.labelSmall?.copyWith(color: muted),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (-minX) / 4,
                getTitlesWidget: (v, meta) {
                  final minutes = v.abs();
                  final label = v >= -0.01 ? 'now' : '-${minutes.round()}m';
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.barIndex == 0 ? 'Download' : 'Upload'}  ${formatBitrate(s.y * 1e6)}',
                    TextStyle(color: s.bar.color, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: down,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: downColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: downColor.withValues(alpha: 0.12)),
            ),
            LineChartBarData(
              spots: up,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: upColor,
              barWidth: 2.5,
              dashArray: const [6, 4],
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounds up to a value that gives round grid lines (1, 2, 5, 10, 20, 50, ...).
double _niceCeiling(double v) {
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final n = v / magnitude;
  final step = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
  return step * magnitude;
}

String _axisLabel(double mbps) {
  if (mbps >= 1000) return '${(mbps / 1000).toStringAsFixed(mbps % 1000 == 0 ? 0 : 1)}G';
  if (mbps >= 10) return mbps.toStringAsFixed(0);
  if (mbps >= 1) return mbps.toStringAsFixed(1);
  return mbps.toStringAsFixed(2);
}
