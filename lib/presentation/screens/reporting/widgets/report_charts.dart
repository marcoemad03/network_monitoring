import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/utils/data_format.dart';
import '../../../../data/models/usage_report_models.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sun 1 Nov".
String dayLabel(DateTime d) => '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// Rounds a chart's top up to a value with a tidy step (1, 2, 5 x 10^n).
double niceCeiling(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 5 ? 5 : 10));
  return nice * exp;
}

/// What the axis shows for a value in bytes, in the unit that suits the chart.
({double divisor, String unit}) axisUnit(double maxBytes) {
  if (maxBytes >= 1e12) return (divisor: 1e12, unit: 'TB');
  if (maxBytes >= 1e9) return (divisor: 1e9, unit: 'GB');
  if (maxBytes >= 1e6) return (divisor: 1e6, unit: 'MB');
  return (divisor: 1e3, unit: 'KB');
}

class Swatch extends StatelessWidget {
  const Swatch({super.key, required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

/// Internet traffic per day, download and upload stacked. Hover or tap a bar for
/// the exact figures, including what the devices accounted for.
class DailyUsageChart extends StatelessWidget {
  const DailyUsageChart({super.key, required this.days});
  final List<DayPoint> days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final down = theme.colorScheme.primary;
    final up = theme.colorScheme.tertiary;
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxBytes = days.map((d) => d.wanTotal).fold(0, math.max).toDouble();
    final unit = axisUnit(maxBytes);
    final maxY = niceCeiling(math.max(maxBytes, 1) / unit.divisor * 1.1);
    final every = days.length <= 10 ? 1 : (days.length <= 16 ? 2 : (days.length <= 31 ? 5 : 15));
    final barWidth = days.length <= 10 ? 28.0 : (days.length <= 31 ? 14.0 : 6.0);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: 'Internet traffic per day. Total ${formatBytes(days.fold(0, (a, d) => a + d.wanTotal))}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
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
                      reservedSize: 52,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          v == 0 ? '0' : '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${unit.unit}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelSmall?.copyWith(color: muted),
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i < 0 || i >= days.length || i % every != 0) return const SizedBox.shrink();
                        final d = days[i].day;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            days.length <= 10 ? '${_weekdays[d.weekday - 1]}\n${d.day}' : '${d.day} ${_months[d.month - 1]}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(color: muted, height: 1.2),
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
                        '${dayLabel(d.day)}\n'
                        'Internet ${formatBytes(d.wanTotal)}\n'
                        'Download ${formatBytes(d.wanDown)}\n'
                        'Upload ${formatBytes(d.wanUp)}\n'
                        'Devices ${formatBytes(d.deviceDown + d.deviceUp)} (${d.activeDevices} active)',
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
                          toY: days[i].wanTotal / unit.divisor,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          rodStackItems: [
                            BarChartRodStackItem(0, days[i].wanDown / unit.divisor, down),
                            BarChartRodStackItem(days[i].wanDown / unit.divisor, days[i].wanTotal / unit.divisor, up),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 18, children: [Swatch(color: down, label: 'Download'), Swatch(color: up, label: 'Upload')]),
        ],
      ),
    );
  }
}

/// Internet traffic by hour of the day over the whole period. The busiest hour is
/// drawn in the accent color and named, so it does not rely on color alone.
class HourlyUsageChart extends StatelessWidget {
  const HourlyUsageChart({super.key, required this.hours});
  final List<HourPoint> hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final maxBytes = hours.map((h) => h.total).fold(0, math.max).toDouble();
    final unit = axisUnit(maxBytes);
    final maxY = niceCeiling(math.max(maxBytes, 1) / unit.divisor * 1.1);
    var busiest = -1;
    for (final h in hours) {
      if (h.total > 0 && (busiest < 0 || h.total > hours[busiest].total)) busiest = h.hour;
    }
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Semantics(
      label: busiest < 0 ? 'Traffic by hour of the day. No traffic measured.' : 'Traffic by hour of the day. Busiest hour $busiest:00.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 220,
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
                      reservedSize: 52,
                      interval: maxY / 4,
                      getTitlesWidget: (v, meta) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          v == 0 ? '0' : '${v >= 10 ? v.toStringAsFixed(0) : v.toStringAsFixed(1)} ${unit.unit}',
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
                        final h = v.toInt();
                        if (h % 3 != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(h.toString().padLeft(2, '0'), style: theme.textTheme.labelSmall?.copyWith(color: muted)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, __) {
                      final h = hours[group.x];
                      return BarTooltipItem(
                        '${h.hour.toString().padLeft(2, '0')}:00 to ${((h.hour + 1) % 24).toString().padLeft(2, '0')}:00\n'
                        'Total ${formatBytes(h.total)}\n'
                        'Download ${formatBytes(h.down)}\n'
                        'Upload ${formatBytes(h.up)}\n'
                        'Average ${formatBitrate(h.avgBps)}',
                        const TextStyle(color: Colors.white, fontSize: 12, height: 1.35),
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (final h in hours)
                    BarChartGroupData(
                      x: h.hour,
                      barRods: [
                        BarChartRodData(
                          toY: h.total / unit.divisor,
                          width: 9,
                          color: h.hour == busiest ? theme.colorScheme.tertiary : theme.colorScheme.primary.withValues(alpha: 0.75),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            busiest < 0 ? 'No traffic measured.' : 'Busiest hour: ${busiest.toString().padLeft(2, '0')}:00 to ${((busiest + 1) % 24).toString().padLeft(2, '0')}:00',
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
