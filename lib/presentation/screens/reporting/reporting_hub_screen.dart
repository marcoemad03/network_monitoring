import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/route_names.dart';

class ReportingHubScreen extends ConsumerWidget {
  const ReportingHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reporting & Analytics')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reporting & Analytics',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'View logs, generate reports, configure alerts, and manage dashboard widgets',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: GridView(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.3,
                ),
                children: [
                  _FeatureCard(
                    icon: Icons.language,
                    title: 'Web Logs',
                    subtitle: 'Browse and filter HTTP/HTTPS request logs',
                    color: Colors.blue,
                    onTap: () => context.go(RouteNames.webLogs),
                  ),
                  _FeatureCard(
                    icon: Icons.swap_vertical_circle,
                    title: 'Connection Logs',
                    subtitle: 'View TCP/UDP connection history and active connections',
                    color: Colors.teal,
                    onTap: () => context.go(RouteNames.connectionLogs),
                  ),
                  _FeatureCard(
                    icon: Icons.download,
                    title: 'Download Logs',
                    subtitle: 'Track file downloads, transfers, and progress',
                    color: Colors.purple,
                    onTap: () => context.go(RouteNames.downloadLogs),
                  ),
                  _FeatureCard(
                    icon: Icons.analytics,
                    title: 'Reports & Analytics',
                    subtitle: 'Generate reports, view analytics, and export data',
                    color: Colors.orange,
                    onTap: () => context.go(RouteNames.reports),
                  ),
                  _FeatureCard(
                    icon: Icons.notifications_active,
                    title: 'Alert Rules',
                    subtitle: 'Configure alert thresholds, conditions, and channels',
                    color: Colors.red,
                    onTap: () => context.go(RouteNames.alertRules),
                  ),
                  _FeatureCard(
                    icon: Icons.widgets,
                    title: 'Dashboard Widgets',
                    subtitle: 'Manage and customize dashboard display widgets',
                    color: Colors.indigo,
                    onTap: () => context.go(RouteNames.widgets),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
