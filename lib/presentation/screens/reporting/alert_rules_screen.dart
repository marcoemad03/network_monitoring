import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';
import '../../widgets/common/app_error_widget.dart';

class AlertRulesScreen extends ConsumerStatefulWidget {
  const AlertRulesScreen({super.key});

  @override
  ConsumerState<AlertRulesScreen> createState() => _AlertRulesScreenState();
}

class _AlertRulesScreenState extends ConsumerState<AlertRulesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(alertRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showRuleDialog(null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(alertRulesProvider),
          ),
        ],
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => AppErrorWidget(
          message: 'Failed to load alert rules',
          onRetry: () => ref.invalidate(alertRulesProvider),
        ),
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_active_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No alert rules', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Create rules to get notified about network events', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showRuleDialog(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Rule'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              final severityColor = _severityColor(rule.severity);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rule.name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              rule.severity[0].toUpperCase() + rule.severity.substring(1),
                              style: TextStyle(fontSize: 11, color: severityColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: rule.isActive,
                            onChanged: (v) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Toggle active requires backend connection')),
                              );
                            },
                          ),
                        ],
                      ),
                      if (rule.description != null && rule.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(rule.description!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(label: '${rule.metric} ${rule.condition} ${rule.threshold}'),
                          const SizedBox(width: 8),
                          _InfoChip(label: '${rule.durationMinutes} min'),
                          const SizedBox(width: 8),
                          _InfoChip(label: 'Cooldown: ${rule.cooldownMinutes} min'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...rule.channels.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _InfoChip(label: c),
                          )),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => _showRuleDialog(rule),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outlined, size: 18, color: Colors.red),
                            onPressed: () => _confirmDelete(rule.id, rule.name),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  void _confirmDelete(String id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Rule'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Delete requires backend connection')),
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showRuleDialog(dynamic existingRule) {
    final isEditing = existingRule != null;
    final nameController = TextEditingController(text: isEditing ? existingRule.name : '');
    final descController = TextEditingController(text: isEditing ? existingRule.description ?? '' : '');
    final thresholdController = TextEditingController(text: isEditing ? '${existingRule.threshold}' : '');
    final durationController = TextEditingController(text: isEditing ? '${existingRule.durationMinutes}' : '');
    final cooldownController = TextEditingController(text: isEditing ? '${existingRule.cooldownMinutes}' : '');

    String selectedMetric = isEditing ? existingRule.metric : 'cpu_usage';
    String selectedCondition = isEditing ? existingRule.condition : '>';
    String selectedSeverity = isEditing ? existingRule.severity : 'warning';
    List<String> selectedChannels = isEditing ? List<String>.from(existingRule.channels) : ['email'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Alert Rule' : 'Create Alert Rule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedMetric,
                  decoration: const InputDecoration(labelText: 'Metric'),
                  items: const [
                    DropdownMenuItem(value: 'cpu_usage', child: Text('CPU Usage')),
                    DropdownMenuItem(value: 'memory_usage', child: Text('Memory Usage')),
                    DropdownMenuItem(value: 'bandwidth_usage', child: Text('Bandwidth Usage')),
                    DropdownMenuItem(value: 'connection_count', child: Text('Connection Count')),
                    DropdownMenuItem(value: 'error_rate', child: Text('Error Rate')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedMetric = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: selectedCondition,
                        decoration: const InputDecoration(labelText: 'Condition'),
                        items: const [
                          DropdownMenuItem(value: '>', child: Text('>')),
                          DropdownMenuItem(value: '<', child: Text('<')),
                          DropdownMenuItem(value: '>=', child: Text('>=')),
                          DropdownMenuItem(value: '<=', child: Text('<=')),
                          DropdownMenuItem(value: '==', child: Text('==')),
                        ],
                        onChanged: (v) => setDialogState(() => selectedCondition = v!),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: thresholdController,
                        decoration: const InputDecoration(labelText: 'Threshold'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: durationController,
                        decoration: const InputDecoration(labelText: 'Duration (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: cooldownController,
                        decoration: const InputDecoration(labelText: 'Cooldown (min)'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSeverity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: const [
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedSeverity = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<List<String>>(
                  value: selectedChannels,
                  decoration: const InputDecoration(labelText: 'Channels'),
                  items: const [
                    DropdownMenuItem(value: ['email'], child: Text('Email')),
                    DropdownMenuItem(value: ['slack'], child: Text('Slack')),
                    DropdownMenuItem(value: ['webhook'], child: Text('Webhook')),
                    DropdownMenuItem(value: ['email', 'slack'], child: Text('Email + Slack')),
                    DropdownMenuItem(value: ['email', 'webhook'], child: Text('Email + Webhook')),
                    DropdownMenuItem(value: ['all'], child: Text('All Channels')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedChannels = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEditing ? 'Update requires backend connection' : 'Create requires backend connection')),
                );
                Navigator.of(ctx).pop();
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;

  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}
