import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';
import '../../widgets/common/app_error_widget.dart';
import '../../../shared/extensions/string_extensions.dart';

class DownloadLogsScreen extends ConsumerStatefulWidget {
  const DownloadLogsScreen({super.key});

  @override
  ConsumerState<DownloadLogsScreen> createState() => _DownloadLogsScreenState();
}

class _DownloadLogsScreenState extends ConsumerState<DownloadLogsScreen> {
  final _deviceController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  String? _selectedStatus;

  @override
  void dispose() {
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsAsync = ref.watch(downloadLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Download Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(downloadLogsProvider),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('All')),
                        DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                        DropdownMenuItem(value: 'failed', child: Text('Failed')),
                        DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                      ],
                      onChanged: (v) => setState(() => _selectedStatus = v),
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
                message: 'Failed to load download logs',
                onRetry: () => ref.invalidate(downloadLogsProvider),
              ),
              data: (logs) {
                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.download_outlined, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No download logs found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Filename')),
                      DataColumn(label: Text('Size')),
                      DataColumn(label: Text('Protocol')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Duration')),
                      DataColumn(label: Text('Start Time')),
                    ],
                    rows: logs.map((log) {
                      final isInProgress = log.status == 'in_progress';
                      return DataRow(cells: [
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isInProgress)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              Text(log.filename, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        DataCell(Text(formatBytes(log.sizeBytes))),
                        DataCell(_ProtocolBadge(protocol: log.protocol)),
                        DataCell(_StatusBadge(status: log.status)),
                        DataCell(Text(
                          isInProgress ? 'In progress' : '${log.durationSeconds}s',
                        )),
                        DataCell(Text('${log.startTime.day}/${log.startTime.month}/${log.startTime.year} ${log.startTime.hour}:${log.startTime.minute.toString().padLeft(2, '0')}')),
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

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'completed':
        color = Colors.green;
      case 'in_progress':
        color = Colors.blue;
      case 'failed':
        color = Colors.red;
      case 'cancelled':
        color = Colors.grey;
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
        status.replaceAll('_', ' ').split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' '),
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
