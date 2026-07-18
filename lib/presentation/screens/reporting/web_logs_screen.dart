import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';

class WebLogsScreen extends ConsumerStatefulWidget {
  const WebLogsScreen({super.key});

  @override
  ConsumerState<WebLogsScreen> createState() => _WebLogsScreenState();
}

class _WebLogsScreenState extends ConsumerState<WebLogsScreen> {
  final _domainController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedCategory;
  bool _blockedOnly = false;
  int _rowsPerPage = 15;

  @override
  void dispose() {
    _domainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(webLogStatsProvider);
    final logsAsync = ref.watch(webLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Web Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(webLogsProvider);
              ref.invalidate(webLogStatsProvider);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          statsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (stats) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  _StatCard(title: 'Total', value: '${stats.total}', color: Colors.blue),
                  const SizedBox(width: 12),
                  _StatCard(title: 'Blocked', value: '${stats.blocked}', color: Colors.red),
                  const SizedBox(width: 12),
                  _StatCard(title: 'Unique Domains', value: '${stats.uniqueDomains}', color: Colors.teal),
                  const SizedBox(width: 12),
                  _StatCard(title: 'Bandwidth', value: _formatBytes(stats.totalBandwidth), color: Colors.purple),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'From',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      readOnly: true,
                      controller: TextEditingController(text: _fromDate != null ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}' : ''),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'To',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      readOnly: true,
                      controller: TextEditingController(text: _toDate != null ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}' : ''),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _domainController,
                      decoration: const InputDecoration(
                        labelText: 'Domain',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'social_media', child: Text('Social Media')),
                        DropdownMenuItem(value: 'streaming', child: Text('Streaming')),
                        DropdownMenuItem(value: 'news', child: Text('News')),
                        DropdownMenuItem(value: 'shopping', child: Text('Shopping')),
                        DropdownMenuItem(value: 'productivity', child: Text('Productivity')),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Blocked only'),
                    selected: _blockedOnly,
                    onSelected: (v) => setState(() => _blockedOnly = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Expanded(
            child: logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load web logs'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(webLogsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.language, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No web logs found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    rowsPerPage: rowsPerPage(logs.length, _rowsPerPage),
                    onRowsPerPageChanged: (v) {
                      if (v != null) setState(() => _rowsPerPage = v);
                    },
                    sortAscending: true,
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('URL')),
                      DataColumn(label: Text('Domain')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Blocked')),
                    ],
                    rows: logs.map((log) {
                      return DataRow(cells: [
                        DataCell(Text('${log.timestamp.day}/${log.timestamp.month}/${log.timestamp.year} ${log.timestamp.hour}:${log.timestamp.minute.toString().padLeft(2, '0')}')),
                        DataCell(Text(log.url.length > 40 ? '${log.url.substring(0, 40)}...' : log.url)),
                        DataCell(Text(log.domain)),
                        DataCell(_CategoryBadge(label: log.category)),
                        DataCell(_StatusBadge(code: log.statusCode)),
                        DataCell(Text(_formatBytes(log.bytes))),
                        DataCell(Text('${log.duration}ms')),
                        DataCell(
                          log.isBlocked
                              ? const Icon(Icons.block, color: Colors.red, size: 18)
                              : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        ),
                      ]);
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  int rowsPerPage(int total, int pageSize) {
    return pageSize > total ? total : pageSize;
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String label;

  const _CategoryBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final int code;

  const _StatusBadge({required this.code});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (code >= 200 && code < 300) {
      color = Colors.green;
    } else if (code >= 300 && code < 400) {
      color = Colors.blue;
    } else if (code >= 400 && code < 500) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text('$code', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
