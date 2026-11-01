import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/data_format.dart';
import '../../../data/models/wan_usage_models.dart';
import '../../providers/dashboard/wan_provider.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';
import 'widgets/daily_usage_card.dart';
import 'widgets/dash_card.dart';
import 'widgets/network_status_card.dart';
import 'widgets/router_health_card.dart';
import 'widgets/speed_card.dart';
import 'widgets/usage_card.dart';

/// Live view of the internet link and the network. Every number comes from a
/// measurement: the router's interface counters for speed and usage, the
/// router's resource readings for its health, and the NMS database for devices
/// and alerts. Nothing is simulated; when a source is missing the screen says so.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wan = ref.watch(wanUsageProvider);
    final summary = ref.watch(dashboardSummaryProvider);
    final feed = wan.valueOrNull;
    final usage = feed?.data;
    final loadingWan = wan.isLoading && feed == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Flexible(child: Center(child: _FreshnessPill(feed: feed, loading: loadingWan))),
          IconButton(
            tooltip: 'Refresh now',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(wanUsageProvider);
              ref.invalidate(dashboardSummaryProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(wanUsageProvider);
          ref.invalidate(dashboardSummaryProvider);
          await ref.read(wanUsageProvider.future);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(width < 700 ? 12 : 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1400),
                  child: _Sections(
                    width: width,
                    usage: usage,
                    loadingWan: loadingWan,
                    summary: summary.valueOrNull,
                    loadingSummary: summary.isLoading && summary.valueOrNull == null,
                    summaryError: summary.hasError ? 'Could not load device status.' : null,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({
    required this.width,
    required this.usage,
    required this.loadingWan,
    required this.summary,
    required this.loadingSummary,
    required this.summaryError,
  });

  final double width;
  final WanUsage? usage;
  final bool loadingWan;
  final dynamic summary;
  final bool loadingSummary;
  final String? summaryError;

  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final speed = SpeedCard(data: usage, loading: loadingWan);
    final router = RouterHealthCard(data: usage, loading: loadingWan);
    final today = UsageCard(
      title: 'Used today',
      icon: Icons.today,
      data: usage,
      loading: loadingWan,
      period: (u) => u.today,
      footnote: _todayNote(usage),
    );
    final month = UsageCard(
      title: 'Used this month',
      icon: Icons.calendar_month,
      data: usage,
      loading: loadingWan,
      period: (u) => u.month,
      footnote: _monthNote(usage),
    );
    final network = NetworkStatusCard(
      summary: summary,
      loading: loadingSummary,
      error: summaryError,
      onDevices: () => context.go(RouteNames.deviceInfrastructure),
      onClients: () => context.go(RouteNames.devices),
      onAlerts: () => context.go(RouteNames.alerts),
    );
    final daily = DailyUsageCard(data: usage, loading: loadingWan);
    final actions = _QuickActions();

    if (width >= 1100) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: speed),
              const SizedBox(width: _gap),
              Expanded(flex: 2, child: router),
            ],
          ),
          const SizedBox(height: _gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: today),
              const SizedBox(width: _gap),
              Expanded(child: month),
              const SizedBox(width: _gap),
              Expanded(child: network),
            ],
          ),
          const SizedBox(height: _gap),
          daily,
          const SizedBox(height: _gap),
          actions,
        ],
      );
    }
    if (width >= 700) {
      return Column(
        children: [
          speed,
          const SizedBox(height: _gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: router),
              const SizedBox(width: _gap),
              Expanded(child: network),
            ],
          ),
          const SizedBox(height: _gap),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: today),
              const SizedBox(width: _gap),
              Expanded(child: month),
            ],
          ),
          const SizedBox(height: _gap),
          daily,
          const SizedBox(height: _gap),
          actions,
        ],
      );
    }
    return Column(
      children: [
        speed,
        const SizedBox(height: _gap),
        today,
        const SizedBox(height: _gap),
        month,
        const SizedBox(height: _gap),
        router,
        const SizedBox(height: _gap),
        network,
        const SizedBox(height: _gap),
        daily,
        const SizedBox(height: _gap),
        actions,
      ],
    );
  }

  /// Usage can only be counted from when the NMS started measuring. Say so
  /// instead of presenting a partial total as the whole day or month.
  static String? _todayNote(WanUsage? u) {
    final since = u?.trackingSince;
    if (since == null) return null;
    final now = DateTime.now();
    if (since.year == now.year && since.month == now.month && since.day == now.day) {
      final h = since.hour.toString().padLeft(2, '0');
      final m = since.minute.toString().padLeft(2, '0');
      return 'Counting started at $h:$m today. Earlier traffic is not included.';
    }
    return null;
  }

  static String? _monthNote(WanUsage? u) {
    if (u == null) return null;
    final lines = <String>[];
    final since = u.trackingSince;
    final now = DateTime.now();
    if (since != null && since.year == now.year && since.month == now.month) {
      lines.add('Counting started on ${since.day}/${since.month}. Earlier traffic is not included.');
    }
    final boot = u.sinceBoot;
    if (boot != null && boot.totalBytes > 0) {
      lines.add('Router counter since it restarted (${formatUptime(boot.uptimeSeconds)} ago): '
          '${formatBytes(boot.totalBytes)} (${formatBytes(boot.downloadBytes)} down, ${formatBytes(boot.uploadBytes)} up).');
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
}

/// Tells how fresh the numbers are, with an icon and words rather than color only.
class _FreshnessPill extends StatelessWidget {
  const _FreshnessPill({required this.feed, required this.loading});

  final WanFeed? feed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    }
    final f = feed;
    final data = f?.data;
    final updated = data?.current?.updatedAt;
    final age = updated == null ? null : DateTime.now().difference(updated);

    if (f != null && f.fetchError != null) {
      return StatusPill(
        tone: StatusTone.error,
        label: data == null ? 'Server unreachable' : 'Server unreachable · showing data from ${formatAge(age ?? Duration.zero)}',
        tooltip: f.fetchError,
      );
    }
    if (data == null) return const StatusPill(tone: StatusTone.neutral, label: 'Connecting…');
    if (!data.available) {
      return StatusPill(tone: StatusTone.error, label: 'Router not connected', tooltip: data.error);
    }
    if (data.stale) {
      return StatusPill(
        tone: StatusTone.warning,
        label: 'Out of date · last reading ${formatAge(age ?? Duration.zero)}',
        tooltip: data.error ?? 'The router has not answered recently.',
      );
    }
    if (data.error != null) {
      return StatusPill(tone: StatusTone.warning, label: 'Router poll failing', tooltip: data.error);
    }
    return StatusPill(tone: StatusTone.ok, icon: Icons.sensors, label: 'Live · updated ${formatAge(age ?? Duration.zero)}');
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => context.push(RouteNames.deviceCreate),
            icon: const Icon(Icons.add),
            label: const Text('Add device'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go(RouteNames.networkScan),
            icon: const Icon(Icons.radar),
            label: const Text('Scan network'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go(RouteNames.marcoGroups),
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Marco groups'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => context.go(RouteNames.networkMap),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Network map'),
          ),
        ],
      ),
    );
  }
}
