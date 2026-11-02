import 'package:flutter/material.dart';
import '../../../../core/utils/data_format.dart';
import '../../../../data/models/usage_report_models.dart';
import '../../../providers/reporting/usage_report_provider.dart';
import '../../dashboard/widgets/dash_card.dart';
import '../../network/widgets/map_kinds.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
String longDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "27 Oct to 2 Nov 2026" or "2 Nov 2026" for a single day.
String periodText(ReportPeriod p) =>
    p.from == p.to ? longDate(p.from) : '${p.from.year == p.to.year ? shortDate(p.from) : longDate(p.from)} to ${longDate(p.to)}';

/// Choose the days a report covers.
class PeriodBar extends StatelessWidget {
  const PeriodBar({super.key, required this.range, required this.onPreset, required this.onCustom});
  final ReportRange range;
  final ValueChanged<ReportPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final p in ReportPreset.values.where((p) => p != ReportPreset.custom))
          ChoiceChip(label: Text(p.label), selected: range.preset == p, onSelected: (_) => onPreset(p)),
        ChoiceChip(
          avatar: const Icon(Icons.date_range, size: 18),
          label: Text(range.preset == ReportPreset.custom ? periodText(ReportPeriod(from: range.from, to: range.to, days: range.days)) : 'Pick dates'),
          selected: range.preset == ReportPreset.custom,
          onSelected: (_) => onCustom(),
        ),
      ],
    );
  }
}

/// Says when part of the period was not measured, or nothing was.
class CoverageBanner extends StatelessWidget {
  const CoverageBanner({super.key, required this.coverage});
  final ReportCoverage coverage;

  @override
  Widget build(BuildContext context) {
    if (!coverage.noData && !coverage.partial) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final tone = toneStyle(context, coverage.noData ? StatusTone.neutral : StatusTone.warning);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(coverage.noData ? Icons.hourglass_empty : tone.icon, size: 20, color: tone.foreground),
          const SizedBox(width: 10),
          Expanded(child: Text(coverage.note, style: theme.textTheme.bodyMedium?.copyWith(color: tone.foreground))),
        ],
      ),
    );
  }
}

/// A headline number with how it compares with the period before.
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.icon, required this.label, required this.value, this.unit, this.detail, this.change, this.changeAgainst});
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final String? detail;
  final double? change;
  final String? changeAgainst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: 8),
            Semantics(
              label: '$label: $value ${unit ?? ''}',
              child: Text.rich(
                TextSpan(
                  text: value,
                  style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                  children: [if (unit != null) TextSpan(text: ' $unit', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))],
                ),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(detail!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
            if (change != null) ...[
              const SizedBox(height: 8),
              ChangeChip(change: change!, against: changeAgainst),
            ],
          ],
        ),
      ),
    );
  }
}

/// "▲ 23% vs previous 7 days". More traffic is not good or bad by itself, so the
/// chip is neutral and says up or down in words and with an arrow.
class ChangeChip extends StatelessWidget {
  const ChangeChip({super.key, required this.change, this.against});
  final double change;
  final String? against;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final flat = change.abs() < 1;
    final icon = flat ? Icons.drag_handle : (change > 0 ? Icons.arrow_upward : Icons.arrow_downward);
    final word = flat ? 'about the same as' : (change > 0 ? 'up' : 'down');
    final text = flat ? 'Same as ${against ?? 'before'}' : '${change.abs().toStringAsFixed(0)}% ${change > 0 ? 'more' : 'less'} than ${against ?? 'before'}';
    return Semantics(
      label: '$word ${flat ? '' : '${change.abs().toStringAsFixed(0)} percent '}${against ?? ''}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(child: Text(text, style: theme.textTheme.labelMedium, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}

/// The four headline numbers.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.report});
  final UsageReport report;

  @override
  Widget build(BuildContext context) {
    final t = report.totals;
    final c = report.compare;
    final against = report.period.days == 1 ? 'the day before' : 'the ${report.period.days} days before';
    final total = splitBytes(t.wanTotal);
    final avg = splitBytes(t.avgPerDay);
    final cards = [
      KpiCard(
        icon: Icons.public,
        label: 'Internet used',
        value: total.value,
        unit: total.unit,
        detail: '↓ ${formatBytes(t.wanDown)}   ↑ ${formatBytes(t.wanUp)}',
        change: c.wanChangePct,
        changeAgainst: against,
      ),
      KpiCard(
        icon: Icons.calendar_view_day,
        label: report.period.days == 1 ? 'Average per hour' : 'Average per day',
        value: report.period.days == 1 ? splitBytes(t.wanTotal / 24).value : avg.value,
        unit: report.period.days == 1 ? splitBytes(t.wanTotal / 24).unit : avg.unit,
        detail: report.period.days == 1 ? 'over 24 hours' : 'over ${report.period.days} days',
      ),
      KpiCard(
        icon: Icons.devices,
        label: 'Devices that used internet',
        value: '${t.activeDevices}',
        detail: t.newDevices > 0 ? '${t.newDevices} new on the network' : 'none new on the network',
        change: c.deviceChangePct,
        changeAgainst: against,
      ),
      KpiCard(
        icon: Icons.speed,
        label: 'Fastest moment',
        value: splitBitrate(t.peakDownBps).value,
        unit: splitBitrate(t.peakDownBps).unit,
        detail: 'download   (upload peak ${formatBitrate(t.peakUpBps)})',
      ),
    ];
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1000 ? 4 : (box.maxWidth >= 560 ? 2 : 1);
        const gap = 12.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in cards) SizedBox(width: w, child: c)]);
      },
    );
  }
}

/// A few sentences worth reading, found from the numbers.
class InsightsCard extends StatelessWidget {
  const InsightsCard({super.key, required this.insights});
  final List<ReportInsight> insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashCard(
      title: 'What stands out',
      icon: Icons.lightbulb_outline,
      child: insights.isEmpty
          ? Text('Nothing unusual in this period.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final i in insights)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(i.warning ? Icons.warning_amber_rounded : Icons.info_outline, size: 18, color: i.warning ? toneStyle(context, StatusTone.warning).foreground : theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(i.text, style: theme.textTheme.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// The biggest users of the period.
class TopDevicesCard extends StatelessWidget {
  const TopDevicesCard({super.key, required this.report, required this.onExport, required this.onOpenMap});
  final UsageReport report;
  final VoidCallback onExport;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final devices = report.topDevices;
    final maxTotal = devices.isEmpty ? 1 : devices.first.total;
    return DashCard(
      title: 'Top devices',
      icon: Icons.leaderboard_outlined,
      subtitle: devices.isEmpty
          ? null
          : 'Showing ${devices.length} of ${report.deviceCount} devices that used internet · ${formatBytes(report.totals.deviceTotal)} together',
      trailing: devices.isEmpty ? null : TextButton.icon(onPressed: onExport, icon: const Icon(Icons.download, size: 18), label: const Text('Export all')),
      child: devices.isEmpty
          ? const EmptyNotice(icon: Icons.devices_other, title: 'No device used the internet in this period', detail: 'Usage is counted for devices the router sees on the hotspot.')
          : LayoutBuilder(
              builder: (context, box) {
                final wide = box.maxWidth >= 760;
                return Column(
                  children: [
                    for (final d in devices) _DeviceRow(device: d, maxTotal: maxTotal, wide: wide),
                    if (devices.any((d) => d.unnamed))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onOpenMap,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Name devices in the Network Map'),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.device, required this.maxTotal, required this.wide});
  final ReportDevice device;
  final int maxTotal;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle(device.kind);
    final where = [if (device.place.isNotEmpty) device.place, if (device.ip.isNotEmpty) device.ip].join(' · ');
    return Semantics(
      label: '${device.rank}. ${device.name}, ${style.label}, ${formatBytes(device.total)}, ${device.sharePct.toStringAsFixed(0)} percent',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 28, child: Text('${device.rank}', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
              child: Icon(style.icon, size: 19, color: style.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: wide ? 4 : 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      if (device.online) ...[
                        const SizedBox(width: 6),
                        Tooltip(message: 'Online now', child: Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF2E7D32)))),
                      ],
                    ],
                  ),
                  Text(where.isEmpty ? style.label : '${style.label} · $where', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (wide)
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ShareBar(fraction: maxTotal == 0 ? 0 : device.total / maxTotal, label: '${device.sharePct.toStringAsFixed(device.sharePct < 10 ? 1 : 0)}%'),
                ),
              ),
            SizedBox(
              width: wide ? 150 : 96,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatBytes(device.total), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  Text('↓ ${formatBytes(device.down)}  ↑ ${formatBytes(device.up)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bar that fills to [fraction], with its percentage written next to it.
class ShareBar extends StatelessWidget {
  const ShareBar({super.key, required this.fraction, required this.label, this.color});
  final double fraction;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              color: color ?? theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 40, child: Text(label, textAlign: TextAlign.right, style: theme.textTheme.labelMedium)),
      ],
    );
  }
}

/// Traffic split by device type or by place.
class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.title, required this.icon, required this.groups, required this.labelFor, this.iconFor, this.onExport, this.hint});
  final String title;
  final IconData icon;
  final List<ReportGroup> groups;
  final String Function(ReportGroup) labelFor;
  final IconData? Function(ReportGroup)? iconFor;
  final VoidCallback? onExport;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DashCard(
      title: title,
      icon: icon,
      trailing: groups.isEmpty || onExport == null ? null : IconButton(tooltip: 'Export $title', icon: const Icon(Icons.download, size: 20), onPressed: onExport),
      child: groups.isEmpty
          ? const EmptyNotice(icon: Icons.pie_chart_outline, title: 'Nothing to split yet')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final g in groups.take(8))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        if (iconFor?.call(g) != null) ...[Icon(iconFor!(g), size: 18, color: theme.colorScheme.onSurfaceVariant), const SizedBox(width: 8)],
                        Expanded(
                          flex: 3,
                          child: Text('${labelFor(g)} · ${g.devices}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                        ),
                        Expanded(flex: 3, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: ShareBar(fraction: g.sharePct / 100, label: '${g.sharePct.toStringAsFixed(g.sharePct < 10 ? 1 : 0)}%'))),
                        SizedBox(width: 70, child: Text(formatBytes(g.total), textAlign: TextAlign.right, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                if (groups.length > 8) Padding(padding: const EdgeInsets.only(top: 4), child: Text('+ ${groups.length - 8} more (in the export)', style: theme.textTheme.bodySmall)),
                if (hint != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(hint!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
              ],
            ),
    );
  }
}

const _severityOrder = ['critical', 'high', 'medium', 'low', 'info'];

/// Alerts raised in the period and the latest security scan.
class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.alerts, required this.security, required this.events, required this.onAlerts, required this.onSecurity});
  final ReportAlerts alerts;
  final ReportSecurity? security;
  final List<ReportEvent> events;
  final VoidCallback onAlerts;
  final VoidCallback onSecurity;

  Widget _counts(BuildContext context, Map<String, int> by) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final s in _severityOrder)
          if ((by[s] ?? 0) > 0)
            StatusPill(
              tone: s == 'critical' || s == 'high' ? StatusTone.error : (s == 'medium' ? StatusTone.warning : StatusTone.neutral),
              label: '${by[s]} ${s[0].toUpperCase()}${s.substring(1)}',
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return DashCard(
      title: 'Alerts and security',
      icon: Icons.shield_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alerts in this period', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          if (alerts.total == 0)
            Text('No alerts were raised.', style: muted)
          else ...[
            _counts(context, alerts.bySeverity),
            const SizedBox(height: 6),
            Text('${alerts.total} raised, ${alerts.open} still open', style: muted),
          ],
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onAlerts, child: const Text('Open alerts'))),
          const Divider(height: 20),
          Text('Latest security scan', style: theme.textTheme.labelLarge),
          const SizedBox(height: 6),
          if (security == null)
            Text('No scan has been run yet.', style: muted)
          else ...[
            if (security!.findings == 0) Text('Nothing needs attention.', style: muted) else _counts(context, security!.bySeverity),
            const SizedBox(height: 6),
            Text('Scanned ${longDate(security!.takenAt)} at ${security!.takenAt.hour.toString().padLeft(2, '0')}:${security!.takenAt.minute.toString().padLeft(2, '0')}', style: muted),
          ],
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onSecurity, child: const Text('Open security'))),
          if (events.isNotEmpty) ...[
            const Divider(height: 20),
            Text('Device events', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final e in events.take(5)) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [Expanded(child: Text(e.type.replaceAll('_', ' '))), Text('${e.count}', style: theme.textTheme.labelLarge)])),
          ],
        ],
      ),
    );
  }
}

/// Plain-words notes on where the numbers come from.
class MeasuredNote extends StatelessWidget {
  const MeasuredNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.help_outline),
        title: Text('How these numbers are measured', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Internet used is read from the byte counters of the router port that faces the internet, about every 30 seconds. It counts every device, wired or wireless.', style: style),
          const SizedBox(height: 8),
          Text('Devices are counted from the router\'s hotspot counters, per device, and added up once a minute. They can add up to less than the internet total because some traffic is not attributed to a device.', style: style),
          const SizedBox(height: 8),
          Text('Days are calendar days on the server. Measuring only happens while the NMS server is running, so a day the server was off has gaps, shown as empty rather than zero.', style: style),
          const SizedBox(height: 8),
          Text('Sizes use decimal units (1 GB = 1000 MB), the way internet providers count. The report does not record which websites were visited.', style: style),
        ],
      ),
    );
  }
}
