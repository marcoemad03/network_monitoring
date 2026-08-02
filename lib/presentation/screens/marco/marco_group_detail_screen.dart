import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/services/marco_state_service.dart';

class MarcoGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const MarcoGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<MarcoGroupDetailScreen> createState() => _MarcoGroupDetailScreenState();
}

class _MarcoGroupDetailScreenState extends ConsumerState<MarcoGroupDetailScreen> {
  MarcoStateService? _service;
  MarcoGroup _group = MarcoGroup(
    id: '',
    name: 'Unknown',
    description: '',
    color: 'blue',
    icon: 'group',
    macAddresses: const [],
    policy: const {},
    createdAt: DateTime(2024),
  );
  final _macController = TextEditingController();
  final _downloadController = TextEditingController();
  final _uploadController = TextEditingController();
  final _dailyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _scheduleController = TextEditingController();
  final _qosController = TextEditingController();
  final List<String> _selectedCategories = <String>[];
  final Map<String, dynamic> _draftPolicy = <String, dynamic>{};
  bool _isSaving = false;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final prefs = ref.read(sharedPreferencesProvider);
    _service = MarcoStateService(prefs);
    await _service!.load();

    _group = _service!.groups.firstWhere(
      (entry) => entry.id == widget.groupId,
      orElse: () => MarcoGroup(
        id: '',
        name: 'Unknown',
        description: '',
        color: 'blue',
        icon: 'group',
        macAddresses: const [],
        policy: const {},
        createdAt: DateTime(2024),
      ),
    );

    _draftPolicy
      ..clear()
      ..addAll(Map<String, dynamic>.from(_group.policy));

    _selectedCategories
      ..clear()
      ..addAll(
        List<String>.from(
          (_group.policy['website_categories'] as List<dynamic>?)
                  ?.whereType<String>() ??
              const <String>[],
        ),
      );

    _downloadController.text = _draftPolicy['download_limit_mbps']?.toString() ?? '';
    _uploadController.text = _draftPolicy['upload_limit_mbps']?.toString() ?? '';
    _dailyController.text = _draftPolicy['daily_quota_gb']?.toString() ?? '';
    _monthlyController.text = _draftPolicy['monthly_quota_gb']?.toString() ?? '';
    _scheduleController.text = _draftPolicy['working_hours']?.toString() ?? '';
    _qosController.text = _draftPolicy['qos_priority']?.toString() ?? '';

    if (mounted) {
      setState(() => _isReady = true);
    }
  }

  @override
  void dispose() {
    _macController.dispose();
    _downloadController.dispose();
    _uploadController.dispose();
    _dailyController.dispose();
    _monthlyController.dispose();
    _scheduleController.dispose();
    _qosController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final service = _service;
    final group = _group.id.isNotEmpty
        ? _group
        : (service?.groups.firstWhere((entry) => entry.id == widget.groupId, orElse: () => _group) ?? _group);
    final policy = Map<String, dynamic>.from(_draftPolicy.isEmpty ? group.policy : _draftPolicy);

    if (!_isReady) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading group')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveGroup,
            icon: const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 6),
                    Text(
                      group.description.isEmpty ? 'No description' : group.description,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    Text('Managed by MAC address', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 10),
                    if (group.macAddresses.isEmpty)
                      Text('Add MACs to bind this group to devices.', style: theme.textTheme.bodySmall)
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.macAddresses.map((mac) => Chip(label: Text(mac))).toList(),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _macController,
                            decoration: const InputDecoration(labelText: 'Add MAC address'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _addMac,
                          icon: const Icon(Icons.add),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.policy_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Group policies', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Internet enabled'),
                      value: policy['internet_enabled'] as bool? ?? true,
                      onChanged: (value) => _updatePolicy('internet_enabled', value),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Unlimited speed'),
                      value: policy['unlimited_speed'] as bool? ?? true,
                      onChanged: (value) => _updatePolicy('unlimited_speed', value),
                    ),
                    const SizedBox(height: 6),
                    _PolicyField(
                      controller: _downloadController,
                      label: 'Download limit (Mbps)',
                      onChanged: (value) => _updatePolicy('download_limit_mbps', double.tryParse(value)),
                    ),
                    const SizedBox(height: 8),
                    _PolicyField(
                      controller: _uploadController,
                      label: 'Upload limit (Mbps)',
                      onChanged: (value) => _updatePolicy('upload_limit_mbps', double.tryParse(value)),
                    ),
                    const SizedBox(height: 8),
                    _PolicyField(
                      controller: _dailyController,
                      label: 'Daily quota (GB)',
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _updatePolicy('daily_quota_gb', double.tryParse(value)),
                    ),
                    const SizedBox(height: 8),
                    _PolicyField(
                      controller: _monthlyController,
                      label: 'Monthly quota (GB)',
                      keyboardType: TextInputType.number,
                      onChanged: (value) => _updatePolicy('monthly_quota_gb', double.tryParse(value)),
                    ),
                    const SizedBox(height: 8),
                    _PolicyField(
                      controller: _scheduleController,
                      label: 'Working hours schedule',
                      onChanged: (value) => _updatePolicy('working_hours', value),
                    ),
                    const SizedBox(height: 8),
                    _PolicyField(
                      controller: _qosController,
                      label: 'QoS priority',
                      onChanged: (value) => _updatePolicy('qos_priority', value),
                    ),
                    const SizedBox(height: 12),
                    Text('Website categories', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categoryOptions.map((option) {
                            final selected = _selectedCategories.contains(option);
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(option),
                                selected: selected,
                                onSelected: (active) {
                                  setState(() {
                                    if (active) {
                                      _selectedCategories.add(option);
                                    } else {
                                      _selectedCategories.remove(option);
                                    }
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _saveGroup,
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isSaving ? 'Saving...' : 'Apply policies'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMac() async {
    final mac = _macController.text.trim();
    if (mac.isEmpty) return;

    final service = _service;
    if (service == null) return;

    final group = _group.id.isNotEmpty ? _group : service.groups.firstWhere((entry) => entry.id == widget.groupId, orElse: () => _group);
    final updated = List<String>.from(group.macAddresses)..add(mac);
    await service.saveGroup(
      MarcoGroup(
        id: group.id,
        name: group.name,
        description: group.description,
        color: group.color,
        icon: group.icon,
        macAddresses: updated,
        policy: group.policy,
        createdAt: group.createdAt,
      ),
    );
    _macController.clear();
    await service.load();
    if (mounted) {
      setState(() {
        _group = service.groups.firstWhere((entry) => entry.id == widget.groupId, orElse: () => _group);
      });
    }
  }

  void _updatePolicy(String key, dynamic value) {
    setState(() {
      _draftPolicy[key] = value;
    });
  }

  Future<void> _saveGroup() async {
    if (_isSaving) return;

    final service = _service;
    if (service == null) return;

    setState(() => _isSaving = true);
    final group = _group.id.isNotEmpty ? _group : service.groups.firstWhere((entry) => entry.id == widget.groupId, orElse: () => _group);
    final current = Map<String, dynamic>.from(_draftPolicy);
    current['website_categories'] = List<String>.from(_selectedCategories);

    await service.saveGroup(
      MarcoGroup(
        id: group.id,
        name: group.name,
        description: group.description,
        color: group.color,
        icon: group.icon,
        macAddresses: group.macAddresses,
        policy: current,
        createdAt: group.createdAt,
      ),
    );
    await service.load();

    if (mounted) {
      setState(() {
        _group = service.groups.firstWhere((entry) => entry.id == widget.groupId, orElse: () => _group);
        _draftPolicy
          ..clear()
          ..addAll(Map<String, dynamic>.from(_group.policy));
        _selectedCategories
          ..clear()
          ..addAll(
            List<String>.from(
              (_group.policy['website_categories'] as List<dynamic>?)
                      ?.whereType<String>() ??
                  const <String>[],
            ),
          );
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Policies saved successfully')));
    }
  }

  static const List<String> _categoryOptions = [
    'YouTube', 'Facebook', 'Instagram', 'TikTok', 'X',
    'Netflix', 'Disney+', 'Shahid',
    'ChatGPT', 'Gemini', 'Claude', 'Copilot',
    'Torrent', 'Mega', 'MediaFire',
    'Steam', 'Epic Games', 'PlayStation', 'Xbox',
  ];
}

class _PolicyField extends StatelessWidget {
  const _PolicyField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.keyboardType = TextInputType.number,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
  }
}
