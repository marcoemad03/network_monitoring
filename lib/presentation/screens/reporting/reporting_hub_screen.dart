import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/data_format.dart';
import '../../providers/reporting/usage_report_provider.dart';
import '../../router/route_names.dart';
import '../dashboard/widgets/dash_card.dart';

/// Where the reporting tools are, and which of them have data behind them today.
class ReportingHubScreen extends ConsumerWidget {
  const ReportingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(usageReportProvider);
    final live = report.valueOrNull;
    final liveLine = live == null
        ? (report.hasError ? 'Could not be read right now' : 'Reading the latest numbers...')
        : live.coverage.noData
        ? 'Nothing measured in the last 7 days'
        : '${formatBytes(live.totals.wanTotal)} used in the last 7 days · ${live.totals.activeDevices} devices';

    return Scaffold(
      appBar: AppBar(title: const Text('Reporting & Analytics')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('Reporting & Analytics', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Pick a tool. Each card says whether it has real data behind it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              const _SectionTitle('Ready to use'),
              _Cards(
                cards: [
                  _Tool(
                    icon: Icons.analytics,
                    title: 'Reports & Analytics',
                    subtitle: 'Internet use by day and hour, top devices, device types, places, alerts. Save any view as a spreadsheet.',
                    status: liveLine,
                    tone: StatusTone.ok,
                    onTap: () => context.go(RouteNames.reports),
                  ),
                  _Tool(
                    icon: Icons.language,
                    title: 'Websites',
                    subtitle: 'Which websites devices open, by name and logo, once a DNS source is connected.',
                    status: 'Needs a DNS source',
                    tone: StatusTone.neutral,
                    onTap: () => context.go(RouteNames.securitySites),
                  ),
                  _Tool(
                    icon: Icons.shield_outlined,
                    title: 'Security scan',
                    subtitle: 'What each device is connected to right now, with findings worth a look.',
                    status: 'Live from the router',
                    tone: StatusTone.ok,
                    onTap: () => context.go(RouteNames.security),
                  ),
                  _Tool(
                    icon: Icons.notifications_active_outlined,
                    title: 'Alerts',
                    subtitle: 'Open and past alerts about devices and the network.',
                    status: 'Live',
                    tone: StatusTone.ok,
                    onTap: () => context.go(RouteNames.alerts),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Not recording yet'),
              _Cards(
                cards: [
                  _Tool(
                    icon: Icons.swap_vertical_circle_outlined,
                    title: 'Connection Logs',
                    subtitle: 'History of network connections. Nothing writes this log yet; the Security scan shows live connections instead.',
                    status: 'No data source',
                    tone: StatusTone.warning,
                    onTap: () => context.go(RouteNames.connectionLogs),
                  ),
                  _Tool(
                    icon: Icons.history,
                    title: 'Web Logs',
                    subtitle: 'Request-by-request web history. Nothing writes this log; Websites is the working replacement.',
                    status: 'No data source',
                    tone: StatusTone.warning,
                    onTap: () => context.go(RouteNames.webLogs),
                  ),
                  _Tool(
                    icon: Icons.download_outlined,
                    title: 'Download Logs',
                    subtitle: 'File downloads. The router cannot see file names, so this cannot be filled.',
                    status: 'Not possible with this router',
                    tone: StatusTone.warning,
                    onTap: () => context.go(RouteNames.downloadLogs),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Saved settings only'),
              _Cards(
                cards: [
                  _Tool(
                    icon: Icons.rule,
                    title: 'Alert Rules',
                    subtitle: 'Rules can be saved, but nothing checks them yet, so they raise no alerts.',
                    status: 'Not checked yet',
                    tone: StatusTone.warning,
                    onTap: () => context.go(RouteNames.alertRules),
                  ),
                  _Tool(
                    icon: Icons.widgets_outlined,
                    title: 'Dashboard Widgets',
                    subtitle: 'Widget layouts can be saved. The main dashboard does not use them yet.',
                    status: 'Not used yet',
                    tone: StatusTone.warning,
                    onTap: () => context.go(RouteNames.widgets),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
    );
  }
}

class _Tool {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final StatusTone tone;
  final VoidCallback onTap;
  const _Tool({required this.icon, required this.title, required this.subtitle, required this.status, required this.tone, required this.onTap});
}

class _Cards extends StatelessWidget {
  const _Cards({required this.cards});
  final List<_Tool> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
        const gap = 14.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in cards) SizedBox(width: w, child: _ToolCard(tool: c))]);
      },
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.tool});
  final _Tool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6))),
      child: InkWell(
        onTap: tool.onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Icon(tool.icon, color: theme.colorScheme.primary),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward, size: 18, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 14),
              Text(tool.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(tool.subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
              const SizedBox(height: 12),
              StatusPill(tone: tool.tone, label: tool.status),
            ],
          ),
        ),
      ),
    );
  }
}
