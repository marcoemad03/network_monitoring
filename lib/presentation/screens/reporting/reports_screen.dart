import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/data_format.dart';
import '../../../data/models/usage_report_models.dart';
import '../../providers/reporting/usage_report_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';
import '../network/widgets/map_kinds.dart';
import 'widgets/report_charts.dart';
import 'widgets/report_widgets.dart';

/// Reports and analytics: how much internet was used, by whom, when, and what
/// else happened, for any period. Everything comes from what the NMS server has
/// recorded; building a report never touches the router.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _exporting = false;

  Future<void> _pickDates() async {
    final range = ref.read(reportRangeProvider);
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(start: range.from, end: range.to),
      helpText: 'Choose the days to report on',
      saveText: 'Show report',
    );
    if (picked == null || !mounted) return;
    ref.read(reportRangeProvider.notifier).custom(picked.start, picked.end);
  }

  Future<void> _export(String view, String what) async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    final range = ref.read(reportRangeProvider);
    setState(() => _exporting = true);
    try {
      final file = await ref.read(usageReportRemoteProvider).export(range.from, range.to, view);
      final path = await ref.read(reportFileSaverProvider)(file);
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text('Saved $what to $path'),
          action: Platform.isWindows
              ? SnackBarAction(label: 'Show in folder', onPressed: () => Process.run('explorer.exe', ['/select,', path]))
              : null,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(reportRangeProvider);
    final report = ref.watch(usageReportProvider);
    final data = report.valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Save as a spreadsheet (CSV)',
            enabled: data != null && !_exporting,
            icon: _exporting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.download),
            onSelected: (v) {
              const names = {'devices': 'the devices list', 'daily': 'the daily totals', 'hourly': 'the hourly totals', 'kinds': 'usage by type', 'places': 'usage by place'};
              _export(v, names[v] ?? v);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'devices', child: ListTile(dense: true, leading: Icon(Icons.devices), title: Text('All devices'))),
              PopupMenuItem(value: 'daily', child: ListTile(dense: true, leading: Icon(Icons.calendar_view_day), title: Text('Totals per day'))),
              PopupMenuItem(value: 'hourly', child: ListTile(dense: true, leading: Icon(Icons.schedule), title: Text('Totals per hour of day'))),
              PopupMenuItem(value: 'kinds', child: ListTile(dense: true, leading: Icon(Icons.category_outlined), title: Text('By device type'))),
              PopupMenuItem(value: 'places', child: ListTile(dense: true, leading: Icon(Icons.place_outlined), title: Text('By place'))),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: report.isLoading && data != null ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(usageReportProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: PeriodBar(range: range, onPreset: ref.read(reportRangeProvider.notifier).choose, onCustom: _pickDates),
            ),
          ),
          Expanded(
            child: report.when(
              skipLoadingOnRefresh: true,
              loading: () => const _Loading(),
              error: (e, _) => data == null ? _Failed(message: e.toString(), onRetry: () => ref.invalidate(usageReportProvider)) : _Body(report: data, staleReason: e.toString()),
              data: (r) => _Body(report: r),
            ),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(children: [Expanded(child: SkeletonBox(height: 120)), SizedBox(width: 12), Expanded(child: SkeletonBox(height: 120)), SizedBox(width: 12), Expanded(child: SkeletonBox(height: 120))]),
          SizedBox(height: 16),
          SkeletonBox(height: 280),
          SizedBox(height: 16),
          SkeletonBox(height: 320),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyNotice(icon: Icons.cloud_off, title: 'The report could not be built', detail: message),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ],
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.report, this.staleReason});
  final UsageReport report;
  final String? staleReason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final days = report.period.days;
    final updated = report.generatedAt;
    final hh = '${updated.hour.toString().padLeft(2, '0')}:${updated.minute.toString().padLeft(2, '0')}';

    Widget cardDaily() => DashCard(
      title: 'Internet per day',
      icon: Icons.bar_chart,
      subtitle: 'Tap a bar for the exact figures',
      child: DailyUsageChart(days: report.daily),
    );
    Widget cardHourly() => DashCard(
      title: 'Busiest hours',
      icon: Icons.schedule,
      subtitle: days == 1 ? 'Traffic in each hour of the day' : 'All $days days added together, by hour of the day',
      child: HourlyUsageChart(hours: report.hourly),
    );

    final empty = report.coverage.noData;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${periodText(report.period)} · ${days == 1 ? '1 day' : '$days days'}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('Updated $hh', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
              if (staleReason != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: toneStyle(context, StatusTone.error).background, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [const Icon(Icons.cloud_off, size: 18), const SizedBox(width: 10), Expanded(child: Text('Could not refresh ($staleReason). Showing the report from $hh.'))]),
                ),
              ],
              const SizedBox(height: 12),
              CoverageBanner(coverage: report.coverage),
              if (report.coverage.noData || report.coverage.partial) const SizedBox(height: 12),
              if (!empty) ...[
                KpiGrid(report: report),
                const SizedBox(height: 16),
                if (report.projection != null) ...[_ProjectionCard(projection: report.projection!), const SizedBox(height: 16)],
                InsightsCard(insights: report.insights),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    if (days == 1) return cardHourly();
                    if (box.maxWidth < 1000) return Column(children: [cardDaily(), const SizedBox(height: 16), cardHourly()]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: cardDaily()), const SizedBox(width: 16), Expanded(flex: 2, child: cardHourly())]);
                  },
                ),
                const SizedBox(height: 16),
                TopDevicesCard(
                  report: report,
                  onExport: () => context.findAncestorStateOfType<_ReportsScreenState>()?._export('devices', 'the devices list'),
                  onOpenMap: () => context.go(RouteNames.networkMap),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, box) {
                    final kinds = GroupCard(
                      title: 'By device type',
                      icon: Icons.category_outlined,
                      groups: report.byKind,
                      labelFor: (g) => kindStyle(g.key).label,
                      iconFor: (g) => kindStyle(g.key).icon,
                      onExport: () => context.findAncestorStateOfType<_ReportsScreenState>()?._export('kinds', 'usage by type'),
                    );
                    final places = GroupCard(
                      title: 'By place',
                      icon: Icons.place_outlined,
                      groups: report.byPlace,
                      labelFor: (g) => g.key,
                      onExport: () => context.findAncestorStateOfType<_ReportsScreenState>()?._export('places', 'usage by place'),
                      hint: report.byPlace.length == 1 && report.byPlace.first.key == 'Not set'
                          ? 'No device has a place yet. Set places in the Network Map and they will show here.'
                          : null,
                    );
                    if (box.maxWidth < 900) return Column(children: [kinds, const SizedBox(height: 16), places]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: kinds), const SizedBox(width: 16), Expanded(child: places)]);
                  },
                ),
                const SizedBox(height: 16),
              ],
              HealthCard(
                alerts: report.alerts,
                security: report.security,
                events: report.events,
                onAlerts: () => context.go(RouteNames.alerts),
                onSecurity: () => context.go(RouteNames.security),
              ),
              const SizedBox(height: 16),
              const MeasuredNote(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.projection});
  final ReportProjection projection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = projection.projectedBytes == 0 ? 0.0 : projection.usedBytes / projection.projectedBytes;
    return DashCard(
      title: 'This month so far',
      icon: Icons.trending_up,
      subtitle: '${projection.daysElapsed} of ${projection.daysInMonth} days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShareBar(fraction: fraction, label: '${(fraction * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          Text(
            'Used ${formatBytes(projection.usedBytes)}. At this pace the month ends near ${formatBytes(projection.projectedBytes)}.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
