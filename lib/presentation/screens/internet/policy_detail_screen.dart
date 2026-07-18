import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/internet/internet_provider.dart';
import '../../providers/device/device_provider.dart';
import '../../../domain/entities/internet_policy.dart';
import '../../../domain/entities/bandwidth_rule.dart';
import '../../../domain/entities/filtering_rule.dart';
import '../../../domain/entities/time_schedule.dart';

class InternetPolicyDetailScreen extends ConsumerStatefulWidget {
  final String? policyId;

  const InternetPolicyDetailScreen({super.key, this.policyId});

  @override
  ConsumerState<InternetPolicyDetailScreen> createState() => _InternetPolicyDetailScreenState();
}

class _InternetPolicyDetailScreenState extends ConsumerState<InternetPolicyDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _uploadCtrl = TextEditingController();
  final _downloadCtrl = TextEditingController();
  String _policyType = 'unlimited';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _deptCtrl.dispose();
    _uploadCtrl.dispose();
    _downloadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNew = widget.policyId == null;

    if (isNew) {
      return _buildEditor(theme, null);
    }

    final policyAsync = ref.watch(internetPolicyDetailProvider(widget.policyId!));
    return policyAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (policy) => policy == null
          ? const Scaffold(body: Center(child: Text('Policy not found')))
          : _buildEditor(theme, policy),
    );
  }

  Widget _buildEditor(ThemeData theme, InternetPolicy? policy) {
    if (policy != null && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = policy.name;
      _descCtrl.text = policy.description ?? '';
      _deptCtrl.text = policy.department ?? '';
      if (policy.uploadLimitBps != null) _uploadCtrl.text = policy.uploadLimitBps.toString();
      if (policy.downloadLimitBps != null) _downloadCtrl.text = policy.downloadLimitBps.toString();
      _policyType = policy.policyType;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Create Policy' : policy?.name ?? 'Policy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () => _save(policy),
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'General', icon: Icon(Icons.settings, size: 18)),
              Tab(text: 'Bandwidth', icon: Icon(Icons.speed, size: 18)),
              Tab(text: 'Filtering', icon: Icon(Icons.filter_alt, size: 18)),
              Tab(text: 'Scheduling', icon: Icon(Icons.schedule, size: 18)),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GeneralTab(
                  nameCtrl: _nameCtrl, descCtrl: _descCtrl, deptCtrl: _deptCtrl,
                  uploadCtrl: _uploadCtrl, downloadCtrl: _downloadCtrl,
                  policyType: _policyType, onTypeChanged: (v) => setState(() => _policyType = v),
                ),
                if (isNew)
                  const Center(child: Text('Save the policy first to manage bandwidth rules'))
                else
                  _BandwidthTab(policyId: widget.policyId!),
                if (isNew)
                  const Center(child: Text('Save the policy first to manage filtering rules'))
                else
                  _FilteringTab(policyId: widget.policyId!),
                if (isNew)
                  const Center(child: Text('Save the policy first to manage schedules'))
                else
                  _SchedulingTab(policyId: widget.policyId!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _save(InternetPolicy? existing) async {
    final repo = ref.read(internetRepositoryProvider);
    final policy = InternetPolicy(
      id: existing?.id ?? '',
      organizationId: existing?.organizationId ?? '',
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      department: _deptCtrl.text.trim().isEmpty ? null : _deptCtrl.text.trim(),
      isActive: existing?.isActive ?? true,
      uploadLimitBps: _uploadCtrl.text.isEmpty ? null : int.tryParse(_uploadCtrl.text),
      downloadLimitBps: _downloadCtrl.text.isEmpty ? null : int.tryParse(_downloadCtrl.text),
      policyType: _policyType,
      priority: existing?.priority ?? 500,
      createdBy: existing?.createdBy,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = existing == null
        ? await repo.createPolicy(policy)
        : await repo.updatePolicy(policy);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${failure.message}'))),
      (_) {
        ref.invalidate(internetPoliciesProvider);
        if (existing != null) ref.invalidate(internetPolicyDetailProvider(existing.id));
        Navigator.of(context).pop();
      },
    );
  }
}

class _GeneralTab extends StatelessWidget {
  final TextEditingController nameCtrl, descCtrl, deptCtrl, uploadCtrl, downloadCtrl;
  final String policyType;
  final ValueChanged<String> onTypeChanged;

  const _GeneralTab({
    required this.nameCtrl, required this.descCtrl, required this.deptCtrl,
    required this.uploadCtrl, required this.downloadCtrl,
    required this.policyType, required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Policy Name')),
          const SizedBox(height: 16),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
          const SizedBox(height: 16),
          TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Department')),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: policyType,
            decoration: const InputDecoration(labelText: 'Policy Type'),
            items: const [
              DropdownMenuItem(value: 'unlimited', child: Text('Unlimited')),
              DropdownMenuItem(value: 'limited', child: Text('Limited (Bandwidth)')),
              DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
              DropdownMenuItem(value: 'filtering', child: Text('Filtering')),
            ],
            onChanged: (v) { if (v != null) onTypeChanged(v); },
          ),
          if (policyType == 'limited') ...[
            const SizedBox(height: 24),
            TextFormField(controller: uploadCtrl, decoration: const InputDecoration(labelText: 'Upload Limit (bps)'), keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            TextFormField(controller: downloadCtrl, decoration: const InputDecoration(labelText: 'Download Limit (bps)'), keyboardType: TextInputType.number),
          ],
        ],
      ),
    );
  }
}

class _BandwidthTab extends ConsumerWidget {
  final String policyId;
  const _BandwidthTab({required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(bandwidthRulesProvider(policyId));

    return Scaffold(
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Bandwidth Rules', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showRuleDialog(context, ref, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Rule'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rules.isEmpty
                  ? Center(child: Text('No bandwidth rules', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rules.length,
                      itemBuilder: (context, index) => _BandwidthRuleCard(
                        rule: rules[index],
                        onEdit: () => _showRuleDialog(context, ref, rules[index]),
                        onDelete: () => _deleteRule(ref, rules[index].id),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRuleDialog(BuildContext context, WidgetRef ref, BandwidthRule? existing) {
    final uploadCtrl = TextEditingController(text: existing?.uploadLimitBps?.toString());
    final downloadCtrl = TextEditingController(text: existing?.downloadLimitBps?.toString());
    var ruleType = existing?.ruleType ?? 'permanent';
    var isTemporary = existing?.isTemporary ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Bandwidth Rule' : 'Edit Bandwidth Rule'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: ruleType,
                    decoration: const InputDecoration(labelText: 'Rule Type'),
                    items: const [
                      DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                      DropdownMenuItem(value: 'temporary', child: Text('Temporary')),
                      DropdownMenuItem(value: 'unlimited', child: Text('Unlimited')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => ruleType = v); },
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: uploadCtrl, decoration: const InputDecoration(labelText: 'Upload Limit (bps)'), keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  TextField(controller: downloadCtrl, decoration: const InputDecoration(labelText: 'Download Limit (bps)'), keyboardType: TextInputType.number),
                  if (ruleType == 'temporary') ...[
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Temporary'),
                      value: isTemporary,
                      onChanged: (v) => setDialogState(() => isTemporary = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final repo = ref.read(internetRepositoryProvider);
                final rule = BandwidthRule(
                  id: existing?.id ?? '',
                  policyId: policyId,
                  deviceId: null,
                  userId: null,
                  priority: existing?.priority ?? 500,
                  uploadLimitBps: int.tryParse(uploadCtrl.text),
                  downloadLimitBps: int.tryParse(downloadCtrl.text),
                  ruleType: ruleType,
                  isTemporary: isTemporary,
                  tempExpiresAt: isTemporary ? DateTime.now().add(const Duration(hours: 1)) : null,
                  isActive: true,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                final result = existing == null
                    ? await repo.createBandwidthRule(policyId, rule)
                    : await repo.updateBandwidthRule(rule);
                result.fold(
                  (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
                  (_) { ref.invalidate(bandwidthRulesProvider(policyId)); Navigator.pop(ctx); },
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteRule(WidgetRef ref, String ruleId) async {
    final repo = ref.read(internetRepositoryProvider);
    final result = await repo.deleteBandwidthRule(ruleId);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
      (_) => ref.invalidate(bandwidthRulesProvider(policyId)),
    );
  }
}

class _BandwidthRuleCard extends StatelessWidget {
  final BandwidthRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BandwidthRuleCard({required this.rule, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(rule.ruleType.toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('↑ ${rule.uploadLimitBps?.toString() ?? '∞'} ↓ ${rule.downloadLimitBps?.toString() ?? '∞'} bps'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
            IconButton(icon: Icon(Icons.delete, size: 18, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _FilteringTab extends ConsumerWidget {
  final String policyId;
  const _FilteringTab({required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rulesAsync = ref.watch(filteringRulesProvider(policyId));

    return Scaffold(
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rules) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Filtering Rules', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showFilterDialog(context, ref, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Rule'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: rules.isEmpty
                  ? Center(child: Text('No filtering rules', style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: rules.length,
                      itemBuilder: (context, index) => _FilteringRuleCard(
                        rule: rules[index],
                        onEdit: () => _showFilterDialog(context, ref, rules[index]),
                        onDelete: () async {
                          final repo = ref.read(internetRepositoryProvider);
                          (await repo.deleteFilteringRule(rules[index].id)).fold(
                            (_) => ref.invalidate(filteringRulesProvider(policyId)),
                            (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $f'))),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context, WidgetRef ref, FilteringRule? existing) {
    var ruleType = existing?.ruleType ?? 'website';
    var filterType = existing?.filterType ?? 'block';
    final valueCtrl = TextEditingController(text: existing?.value);
    final descCtrl = TextEditingController(text: existing?.description);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add Filtering Rule' : 'Edit Filtering Rule'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: ruleType, decoration: const InputDecoration(labelText: 'Rule Type'),
                    items: const [
                      DropdownMenuItem(value: 'website', child: Text('Website')),
                      DropdownMenuItem(value: 'category', child: Text('Category')),
                      DropdownMenuItem(value: 'application', child: Text('Application')),
                      DropdownMenuItem(value: 'mac', child: Text('MAC Address')),
                      DropdownMenuItem(value: 'ip', child: Text('IP Address')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => ruleType = v); },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: filterType, decoration: const InputDecoration(labelText: 'Filter Type'),
                    items: const [
                      DropdownMenuItem(value: 'allow', child: Text('Allow')),
                      DropdownMenuItem(value: 'block', child: Text('Block')),
                      DropdownMenuItem(value: 'whitelist', child: Text('Whitelist')),
                      DropdownMenuItem(value: 'blacklist', child: Text('Blacklist')),
                    ],
                    onChanged: (v) { if (v != null) setDialogState(() => filterType = v); },
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: valueCtrl, decoration: InputDecoration(labelText: _valueLabel(ruleType))),
                  const SizedBox(height: 16),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final repo = ref.read(internetRepositoryProvider);
                final rule = FilteringRule(
                  id: existing?.id ?? '',
                  policyId: policyId,
                  ruleType: ruleType,
                  filterType: filterType,
                  value: valueCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  isActive: true,
                  createdAt: existing?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );
                final result = existing == null
                    ? await repo.createFilteringRule(policyId, rule)
                    : await repo.updateFilteringRule(rule);
                result.fold(
                  (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
                  (_) { ref.invalidate(filteringRulesProvider(policyId)); Navigator.pop(ctx); },
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _valueLabel(String type) => switch (type) {
    'website' => 'URL',
    'category' => 'Category Name',
    'application' => 'App Name',
    'mac' => 'MAC Address',
    'ip' => 'IP Address',
    _ => 'Value',
  };
}

class _FilteringRuleCard extends StatelessWidget {
  final FilteringRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FilteringRuleCard({required this.rule, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filterColor = rule.filterType == 'block' || rule.filterType == 'blacklist'
        ? Colors.red : Colors.green;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: filterColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(rule.filterType == 'block' ? Icons.block : Icons.check_circle, color: filterColor, size: 18),
        ),
        title: Text(rule.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text('${rule.ruleType} · ${rule.filterType}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: onEdit),
            IconButton(icon: Icon(Icons.delete, size: 18, color: Colors.red), onPressed: onDelete),
          ],
        ),
      ),
    );
  }
}

class _SchedulingTab extends ConsumerWidget {
  final String policyId;
  const _SchedulingTab({required this.policyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final schedulesAsync = ref.watch(schedulesProvider(policyId));

    return Scaffold(
      body: schedulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (schedules) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Time Schedules', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  FilledButton.tonalIcon(
                    onPressed: () => _showScheduleDialog(context, ref, null),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Schedule'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: schedules.isEmpty
                  ? Center(child: Text('No schedules', style: theme.textTheme.bodyMedium))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: schedules.length,
                      itemBuilder: (context, index) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(_dayName(schedules[index].dayOfWeek), style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('${schedules[index].startTime} - ${schedules[index].endTime}'),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, size: 18, color: Colors.red),
                            onPressed: () async {
                              final repo = ref.read(internetRepositoryProvider);
                              (await repo.deleteSchedule(schedules[index].id)).fold(
                                (_) => ref.invalidate(schedulesProvider(policyId)),
                                (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $f'))),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog(BuildContext context, WidgetRef ref, TimeSchedule? existing) {
    var dayOfWeek = existing?.dayOfWeek ?? 1;
    final startCtrl = TextEditingController(text: existing?.startTime ?? '09:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '17:00');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Schedule'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: dayOfWeek, decoration: const InputDecoration(labelText: 'Day'),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_dayName(i)))),
                  onChanged: (v) { if (v != null) setDialogState(() => dayOfWeek = v); },
                ),
                const SizedBox(height: 16),
                TextField(controller: startCtrl, decoration: const InputDecoration(labelText: 'Start Time (HH:mm)')),
                const SizedBox(height: 16),
                TextField(controller: endCtrl, decoration: const InputDecoration(labelText: 'End Time (HH:mm)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final repo = ref.read(internetRepositoryProvider);
                final schedule = TimeSchedule(
                  id: existing?.id ?? '', policyId: policyId,
                  dayOfWeek: dayOfWeek, startTime: startCtrl.text.trim(), endTime: endCtrl.text.trim(),
                  isActive: true, createdAt: existing?.createdAt ?? DateTime.now(), updatedAt: DateTime.now(),
                );
                final result = existing == null
                    ? await repo.createSchedule(policyId, schedule)
                    : await repo.updateSchedule(schedule);
                result.fold(
                  (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
                  (_) { ref.invalidate(schedulesProvider(policyId)); Navigator.pop(ctx); },
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String _dayName(int day) => ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][day.clamp(0, 6)];
}
