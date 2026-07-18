import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Summary'),
            Tab(text: 'Reports'),
            Tab(text: 'Exports'),
            Tab(text: 'Top Lists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(),
          _ReportsTab(),
          _ExportsTab(),
          _TopListsTab(),
        ],
      ),
    );
  }
}

class _SummaryTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(analyticsSummaryProvider);
    final bandwidthAsync = ref.watch(bandwidthOverTimeProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            const Text('Failed to load analytics'),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(analyticsSummaryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (summary) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _AnalyticsCard(title: 'Total Web Logs', value: '${summary?.totalWebLogs ?? 0}', icon: Icons.language, color: Colors.blue),
                _AnalyticsCard(title: 'Total Connections', value: '${summary?.totalConnections ?? 0}', icon: Icons.swap_vertical_circle, color: Colors.teal),
                _AnalyticsCard(title: 'Total Downloads', value: '${summary?.totalDownloads ?? 0}', icon: Icons.download, color: Colors.purple),
                _AnalyticsCard(title: 'Total Bandwidth', value: _formatBytes(summary?.totalBandwidthBytes ?? 0), icon: Icons.speed, color: Colors.orange),
                _AnalyticsCard(title: 'Unread Notifications', value: '${summary?.unreadNotifications ?? 0}', icon: Icons.notifications_active, color: Colors.red),
              ],
            ),
            const SizedBox(height: 24),
            Text('Bandwidth Over Time', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            bandwidthAsync.when(
              loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
              error: (_, __) => const SizedBox(height: 200, child: Center(child: Text('Failed to load bandwidth data'))),
              data: (data) => SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: data.asMap().entries.map((entry) {
                    final maxVal = data.fold<int>(0, (a, b) => a > b.bytesSent + b.bytesReceived ? a : b.bytesSent + b.bytesReceived);
                    final val = entry.value.bytesSent + entry.value.bytesReceived;
                    final heightFraction = maxVal > 0 ? val / maxVal : 0.0;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              _formatBytes(val),
                              style: theme.textTheme.labelSmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: heightFraction * 160,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.7),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${entry.value.timestamp.hour}:${entry.value.timestamp.minute.toString().padLeft(2, '0')}',
                              style: theme.textTheme.labelSmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Top Bandwidth Consumers', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ref.watch(topBandwidthConsumersProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Failed to load top consumers')),
              data: (consumers) => Column(
                children: consumers.map((c) => ListTile(
                  leading: CircleAvatar(child: Text('${consumers.indexOf(c) + 1}')),
                  title: Text(c.deviceName),
                  trailing: Text(_formatBytes(c.totalBytes)),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _AnalyticsCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 200,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends ConsumerState<_ReportsTab> {
  String _selectedType = 'summary';
  DateTime? _periodFrom;
  DateTime? _periodTo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reportsAsync = ref.watch(reportsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate Report', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(labelText: 'Report Type'),
                    items: const [
                      DropdownMenuItem(value: 'summary', child: Text('Summary Report')),
                      DropdownMenuItem(value: 'bandwidth', child: Text('Bandwidth Report')),
                      DropdownMenuItem(value: 'security', child: Text('Security Report')),
                      DropdownMenuItem(value: 'compliance', child: Text('Compliance Report')),
                    ],
                    onChanged: (v) => setState(() => _selectedType = v!),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Period From',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          readOnly: true,
                          controller: TextEditingController(text: _periodFrom != null ? '${_periodFrom!.day}/${_periodFrom!.month}/${_periodFrom!.year}' : ''),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _periodFrom = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Period To',
                            prefixIcon: Icon(Icons.calendar_today, size: 18),
                          ),
                          readOnly: true,
                          controller: TextEditingController(text: _periodTo != null ? '${_periodTo!.day}/${_periodTo!.month}/${_periodTo!.year}' : ''),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setState(() => _periodTo = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report generation requires backend connection')),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Generate Report'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Cached Reports', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          reportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load reports')),
            data: (reports) {
              if (reports.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No cached reports', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                );
              }
              return Column(
                children: reports.map((r) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: Text(r.reportType),
                    subtitle: Text('${r.periodStart.day}/${r.periodStart.month}/${r.periodStart.year} - ${r.generatedAt.day}/${r.generatedAt.month}/${r.generatedAt.year}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.download), onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Download requires backend connection')),
                          );
                        }),
                        IconButton(icon: const Icon(Icons.file_copy_outlined), onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Export requires backend connection')),
                          );
                        }),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExportsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exportsAsync = ref.watch(exportsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('New export requires backend connection')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New Export'),
          ),
          const SizedBox(height: 16),
          exportsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48),
                  const SizedBox(height: 16),
                  Text('Failed to load exports'),
                ],
              ),
            ),
            data: (exports) {
              if (exports.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.file_download_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No exports yet', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: exports.map((e) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(_exportIcon(e.format)),
                    title: Text('${e.reportType} - ${e.format}'),
                    subtitle: Row(
                      children: [
                        _StatusBadge(status: e.status),
                        const SizedBox(width: 8),
                        Text(e.generatedAt != null ? '${e.generatedAt!.day}/${e.generatedAt!.month}/${e.generatedAt!.year}' : ''),
                      ],
                    ),
                    trailing: e.status == 'completed'
                        ? IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Download requires backend connection')),
                              );
                            },
                          )
                        : null,
                  ),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _exportIcon(String format) {
    switch (format.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'csv':
        return Icons.table_chart;
      case 'xlsx':
        return Icons.grid_on;
      default:
        return Icons.file_present;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
      case 'processing':
        color = Colors.blue;
      case 'failed':
        color = Colors.red;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status[0].toUpperCase() + status.substring(1),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _TopListsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Top Websites'),
              Tab(text: 'Top Users'),
              Tab(text: 'Departments'),
              Tab(text: 'Bandwidth'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _TopListContent(provider: topWebsitesProvider, label: 'websites'),
                _TopListContent(provider: topUsersProvider, label: 'users'),
                _TopListContent(provider: departmentReportsProvider, label: 'departments'),
                _TopListContent(provider: topBandwidthConsumersProvider, label: 'bandwidth entries'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopListContent extends ConsumerWidget {
  final dynamic provider;
  final String label;

  const _TopListContent({required this.provider, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncData = ref.watch(provider);

    return asyncData.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 16),
            Text('Failed to load $label'),
          ],
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list_alt, size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                Text('No $label found', style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  child: Text('${index + 1}', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ),
                title: Text(item.toString()),
                trailing: const Text(''),
              ),
            );
          },
        );
      },
    );
  }

}
