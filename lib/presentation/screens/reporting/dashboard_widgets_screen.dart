import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reporting/reporting_provider.dart';

class DashboardWidgetsScreen extends ConsumerStatefulWidget {
  const DashboardWidgetsScreen({super.key});

  @override
  ConsumerState<DashboardWidgetsScreen> createState() => _DashboardWidgetsScreenState();
}

class _DashboardWidgetsScreenState extends ConsumerState<DashboardWidgetsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widgetsAsync = ref.watch(dashboardWidgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Widgets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showWidgetDialog(context, null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardWidgetsProvider),
          ),
        ],
      ),
      body: widgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load widgets'),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => ref.invalidate(dashboardWidgetsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (widgets) {
          if (widgets.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.widgets_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No dashboard widgets', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showWidgetDialog(context, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Widget'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widgets.length,
            itemBuilder: (context, index) {
              final widget = widgets[index];
              final isFirst = index == 0;
              final isLast = index == widgets.length - 1;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _WidgetInfoChip(
                                  label: widget.type,
                                  icon: Icons.category_outlined,
                                ),
                                const SizedBox(width: 8),
                                _WidgetInfoChip(
                                  label: '${widget.width} x ${widget.height}',
                                  icon: Icons.aspect_ratio,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: isFirst ? null : () => _moveWidget(index, index - 1),
                            tooltip: 'Move up',
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: isLast ? null : () => _moveWidget(index, index + 1),
                            tooltip: 'Move down',
                          ),
                          Switch(
                            value: widget.isVisible,
                            onChanged: (v) => _toggleVisibility(widget.id, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showWidgetDialog(context, widget),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outlined, color: Colors.red),
                            onPressed: () => _confirmDelete(widget.id, widget.title),
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

  void _moveWidget(int from, int to) {
    ref.read(dashboardWidgetsProvider.notifier).reorder(from, to);
  }

  void _toggleVisibility(String id, bool visible) {
    ref.read(dashboardWidgetsProvider.notifier).toggleVisibility(id, visible);
  }

  void _confirmDelete(String id, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Widget'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(dashboardWidgetsProvider.notifier).delete(id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showWidgetDialog(BuildContext context, dynamic existingWidget) {
    final isEditing = existingWidget != null;
    final titleController = TextEditingController(text: isEditing ? existingWidget.title : '');
    final configController = TextEditingController(text: isEditing ? existingWidget.config : '');
    String selectedType = isEditing ? existingWidget.type : 'chart';
    int width = isEditing ? existingWidget.width : 2;
    int height = isEditing ? existingWidget.height : 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Widget' : 'Add Widget'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Widget Type'),
                  items: const [
                    DropdownMenuItem(value: 'chart', child: Text('Chart')),
                    DropdownMenuItem(value: 'stats', child: Text('Stats')),
                    DropdownMenuItem(value: 'table', child: Text('Table')),
                    DropdownMenuItem(value: 'list', child: Text('List')),
                  ],
                  onChanged: (v) => setDialogState(() => selectedType = v!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: width,
                        decoration: const InputDecoration(labelText: 'Width'),
                        items: [1, 2, 3, 4]
                            .map((w) => DropdownMenuItem(value: w, child: Text('$w'))),
                        onChanged: (v) => setDialogState(() => width = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: height,
                        decoration: const InputDecoration(labelText: 'Height'),
                        items: [1, 2, 3]
                            .map((h) => DropdownMenuItem(value: h, child: Text('$h'))),
                        onChanged: (v) => setDialogState(() => height = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: configController,
                  decoration: const InputDecoration(labelText: 'Config (JSON)', hintText: '{}'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (isEditing) {
                  ref.read(dashboardWidgetsProvider.notifier).update(
                    existingWidget.id,
                    titleController.text,
                    selectedType,
                    width,
                    height,
                    configController.text,
                  );
                } else {
                  ref.read(dashboardWidgetsProvider.notifier).create(
                    titleController.text,
                    selectedType,
                    width,
                    height,
                    configController.text,
                  );
                }
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

class _WidgetInfoChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _WidgetInfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
