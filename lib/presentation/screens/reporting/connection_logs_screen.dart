import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../shared/extensions/string_extensions.dart';

class ConnectionLogsScreen extends ConsumerStatefulWidget {
  const ConnectionLogsScreen({super.key});

  @override
  ConsumerState<ConnectionLogsScreen> createState() => _ConnectionLogsScreenState();
}

class _ConnectionLogsScreenState extends ConsumerState<ConnectionLogsScreen> {
  final _deviceController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedProtocol;
  bool _activeOnly = false;

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(connectionLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(connectionLogsProvider);
              ref.invalidate(activeConnectionCountProvider);
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: logsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('--'),
                    data: (logs) => Row(
                      children: [
                        _StatCard(title: 'Total Connections', value: '${logs.length}', color: Colors.blue),
                        const SizedBox(width: 12),
                        _StatCard(title: 'Active', value: '${logs.where((l) => l.isActive).length}', color: Colors.green),
                      ],
                    ),
                  ),
                ),
              ],
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
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      value: _selectedProtocol,
                      decoration: const InputDecoration(
                        labelText: 'Protocol',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                        DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                        DropdownMenuItem(value: 'ICMP', child: Text('ICMP')),
                      ],
                      onChanged: (v) => setState(() => _selectedProtocol = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _deviceController,
                      decoration: const InputDecoration(
                        labelText: 'Device Search',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Active only'),
                    selected: _activeOnly,
                    onSelected: (v) => setState(() => _activeOnly = v),
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
              error: (e, _) => AppErrorWidget(
                message: 'Failed to load connection logs',
                onRetry: () => ref.invalidate(connectionLogsProvider),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_vertical_circle, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No connection logs found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Start Time')),
                      DataColumn(label: Text('Source IP')),
                      DataColumn(label: Text('Dest IP')),
                      DataColumn(label: Text('Protocol')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Bytes')),
                      DataColumn(label: Text('Active')),
                    ],
                    rows: logs.map((log) {
                      final isActive = log.isActive;
                      return DataRow(
                        color: isActive ? WidgetStateProperty.all(Colors.green.withValues(alpha: 0.08)) : null,
                        cells: [
                          DataCell(Text('${log.startTime.day}/${log.startTime.month}/${log.startTime.year} ${log.startTime.hour}:${log.startTime.minute.toString().padLeft(2, '0')}')),
                          DataCell(Text(log.sourceIp)),
                          DataCell(Text(log.destIp)),
                          DataCell(_ProtocolBadge(protocol: log.protocol ?? '')),
                          DataCell(Text(log.isActive ? 'Active' : '${log.durationSeconds}s')),
                          DataCell(Text(formatBytes(log.bytesSent + log.bytesReceived))),
                          DataCell(
                            isActive
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : const Icon(Icons.check_circle, color: Colors.grey, size: 16),
                          ),
                        ],
                      );
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

class _ProtocolBadge extends StatelessWidget {
  final String protocol;

  const _ProtocolBadge({required this.protocol});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(protocol, style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
    );
  }
}
