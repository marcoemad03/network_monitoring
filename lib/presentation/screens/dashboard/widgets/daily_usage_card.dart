import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/data_format.dart';
import '../../../../data/models/wan_usage_models.dart';
import 'dash_card.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Internet used per day over the last 7 days, download stacked on upload.
class DailyUsageCard extends StatelessWidget {
  const DailyUsageCard({super.key, required this.data, required this.loading});

  final WanUsage? data;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final usage = data;
    return DashCard(
      title: 'Last 7 days',
      icon: Icons.bar_chart,
      subtitle: 'Internet used each day',
      child: usage == null
          ? (loading ? const SkeletonBox(height: 160) : const EmptyNotice(icon: Icons.cloud_off, title: 'No data yet'))
          : !usage.available
              ? const EmptyNotice(icon: Icons.router_outlined, title: 'Not measured', detail: 'Waiting for the router.')
              : _Chart(days: _lastSevenDays(usage.daily)),
    );
  }
}

/// Today and the six days before it; days without samples count as zero.
List<WanDay> _lastSevenDays(List<WanDay> recorded) {
  final today = DateTime.now();
  return [
    for (var i = 6; i >= 0; i--)
      () {
        final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
        final match = recorded.where((d) => d.day.year == day.year && d.day.month == day.month && d.day.day == day.day);
        return WanDay(
          day: day,
          downloadBytes: match.fold(0, (s, d) => s + d.downloadBytes),
          uploadBytes: match.fold(0, (s, d) => s + d.uploadBytes),
        );
      }(),
  ];
}

class _Chart extends StatelessWidget {
  const _Chart({required this.days});

  final List<WanDay> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downColor = theme.colorScheme.primary;
    final upColor = theme.colorScheme.tertiary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxBytes = days.map((d) => d.totalBytes).fold(0, math.max);
    final maxGb = math.max(maxBytes / 1e9, 0.1);
    final maxY = _ceiling(maxGb * 1.2);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 170,
          child: BarChart(
            duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 250),
            BarChartData(
              maxY: maxY,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
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
                        v == 0 ? '0' : '${v.toStringAsFixed(v >= 10 ? 0 : 1)} GB',
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
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      final isToday = i == days.length - 1;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          isToday ? 'Today' : _weekdays[days[i].day.weekday - 1],
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isToday ? theme.colorScheme.onSurface : muted,
                            fontWeight: isToday ? FontWeight.w700 : null,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, __) {
                    final d = days[group.x];
                    return BarTooltipItem(
                      '${_weekdays[d.day.weekday - 1]} ${d.day.day}/${d.day.month}\n'
                      'Total ${formatBytes(d.totalBytes)}\n'
                      'Download ${formatBytes(d.downloadBytes)}\n'
                      'Upload ${formatBytes(d.uploadBytes)}',
                      const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < days.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: days[i].totalBytes / 1e9,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                        rodStackItems: [
                          BarChartRodStackItem(0, days[i].downloadBytes / 1e9, downColor),
                          BarChartRodStackItem(days[i].downloadBytes / 1e9, days[i].totalBytes / 1e9, upColor),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Swatch(color: downColor, label: 'Download'),
            const SizedBox(width: 18),
            _Swatch(color: upColor, label: 'Upload'),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

double _ceiling(double v) {
  final magnitude = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final n = v / magnitude;
  final step = n <= 1 ? 1 : n <= 2 ? 2 : n <= 5 ? 5 : 10;
  return step * magnitude;
}
