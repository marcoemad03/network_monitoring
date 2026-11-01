import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/marco_models.dart';
import '../../providers/marco/marco_provider.dart';
import 'marco_groups_screen.dart' show marcoColor;

class MarcoGroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const MarcoGroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<MarcoGroupDetailScreen> createState() => _MarcoGroupDetailScreenState();
}

class _MarcoGroupDetailScreenState extends ConsumerState<MarcoGroupDetailScreen> {
  static final _clock = RegExp(r'^\d{1,2}:\d{2}$');
  static const _days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

  final _macController = TextEditingController();
  final _downloadController = TextEditingController();
  final _uploadController = TextEditingController();
  final _dailyController = TextEditingController();
  final _monthlyController = TextEditingController();
  final _qosController = TextEditingController();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final Set<String> _blocked = <String>{};
  final Set<String> _scheduleDays = <String>{};
  bool _internetEnabled = true;
  bool _unlimitedSpeed = true;
  bool _draftLoaded = false;
  bool _isSaving = false;

  @override
  void dispose() {
    for (final c in [
      _macController, _downloadController, _uploadController, _dailyController,
      _monthlyController, _qosController, _startController, _endController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _loadDraft(MarcoGroup group) {
    final p = group.policy;
    _internetEnabled = p['internet_enabled'] as bool? ?? true;
    _unlimitedSpeed = p['unlimited_speed'] as bool? ?? true;
    _downloadController.text = p['download_limit_mbps']?.toString() ?? '';
    _uploadController.text = p['upload_limit_mbps']?.toString() ?? '';
    _dailyController.text = p['daily_quota_gb']?.toString() ?? '';
    _monthlyController.text = p['monthly_quota_gb']?.toString() ?? '';
    _qosController.text = p['qos_priority']?.toString() ?? '';
    _startController.text = p['schedule_start_time']?.toString() ?? '';
    _endController.text = p['schedule_end_time']?.toString() ?? '';
    _blocked
      ..clear()
      ..addAll(List<String>.from(p['blocked_websites'] as List? ?? const []));
    _scheduleDays
      ..clear()
      ..addAll(List<String>.from(p['schedule_days'] as List? ?? const []));
    _draftLoaded = true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsAsync = ref.watch(marcoGroupsProvider);
    final platforms = ref.watch(marcoPlatformsProvider).valueOrNull ?? const <MarcoPlatform>[];

    return groupsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Loading group')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(appBar: AppBar(title: const Text('Marco group')), body: Center(child: Text('$e'))),
      data: (result) {
        final matches = result.groups.where((g) => g.id == widget.groupId);
        if (matches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Marco group')),
            body: const Center(child: Text('Group not found')),
          );
        }
        final group = matches.first;
        if (!_draftLoaded) _loadDraft(group);

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                onPressed: _isSaving ? null : () => _savePolicy(group),
                icon: const Icon(Icons.save_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (result.dryRun)
                  Card(
                    color: Colors.orange.withOpacity(0.12),
                    elevation: 0,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Safe mode: policies are saved but not applied to the router.'),
                    ),
                  ),
                _membersCard(theme, group),
                const SizedBox(height: 16),
                _policyCard(theme, group, platforms),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _membersCard(ThemeData theme, MarcoGroup group) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 6, backgroundColor: marcoColor(group.color)),
              const SizedBox(width: 8),
              Expanded(child: Text(group.name, style: theme.textTheme.titleLarge)),
            ]),
            const SizedBox(height: 6),
            Text(
              group.description.isEmpty ? 'No description' : group.description,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text('Devices (managed by MAC address)', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            if (group.members.isEmpty)
              Text('Add MAC addresses to bind devices to this group.', style: theme.textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.members
                    .map((m) => InputChip(
                          avatar: Icon(Icons.circle, size: 10, color: m.isOnline ? Colors.green : Colors.grey),
                          label: Text('${m.label}${m.macAddress == null ? '' : ' • ${m.macAddress}'}'),
                          onDeleted: () => _removeMember(group, m),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _macController,
                    decoration: const InputDecoration(labelText: 'Add MAC address (AA:BB:CC:DD:EE:FF)'),
                    onSubmitted: (_) => _addMac(group),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(onPressed: () => _addMac(group), icon: const Icon(Icons.add), label: const Text('Add')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _policyCard(ThemeData theme, MarcoGroup group, List<MarcoPlatform> platforms) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.policy_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text('Group policies', style: theme.textTheme.titleMedium),
            ]),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Internet enabled'),
              value: _internetEnabled,
              onChanged: (v) => setState(() => _internetEnabled = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Unlimited speed'),
              subtitle: const Text('Turn off to apply the limits below'),
              value: _unlimitedSpeed,
              onChanged: (v) => setState(() => _unlimitedSpeed = v),
            ),
            const SizedBox(height: 6),
            _field(_downloadController, 'Download limit (Mbps)', enabled: !_unlimitedSpeed),
            const SizedBox(height: 8),
            _field(_uploadController, 'Upload limit (Mbps)', enabled: !_unlimitedSpeed),
            const SizedBox(height: 8),
            _field(_dailyController, 'Daily quota (GB)'),
            const SizedBox(height: 8),
            _field(_monthlyController, 'Monthly quota (GB)'),
            const SizedBox(height: 8),
            _field(_qosController, 'QoS priority (1 = highest, 8 = lowest)'),
            const SizedBox(height: 16),
            Text('Block internet during this time window', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _field(_startController, 'From (HH:MM)', keyboardType: TextInputType.datetime)),
              const SizedBox(width: 8),
              Expanded(child: _field(_endController, 'To (HH:MM)', keyboardType: TextInputType.datetime)),
            ]),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: _days
                  .map((d) => FilterChip(
                        label: Text(d),
                        selected: _scheduleDays.contains(d),
                        onSelected: (on) => setState(() => on ? _scheduleDays.add(d) : _scheduleDays.remove(d)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('Blocked websites', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Sites with fixed addresses are blocked by IP range. AI assistants need layer-7 matching on the router.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (platforms.isEmpty)
              const Text('Loading catalog...')
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: platforms
                    .map((p) => FilterChip(
                          label: Text(p.label),
                          selected: _blocked.contains(p.key),
                          onSelected: (on) => setState(() => on ? _blocked.add(p.key) : _blocked.remove(p.key)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : () => _savePolicy(group),
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Apply policies'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {bool enabled = true, TextInputType keyboardType = TextInputType.number}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addMac(MarcoGroup group) async {
    final mac = _macController.text.trim().toUpperCase().replaceAll('-', ':');
    if (mac.isEmpty) return;
    if (!RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$').hasMatch(mac)) {
      _toast('Enter a valid MAC address like AA:BB:CC:DD:EE:FF');
      return;
    }
    try {
      final result = await ref.read(marcoGroupsProvider.notifier).addMembers(group.id, [mac]);
      _macController.clear();
      _toast(result.dryRun ? 'Device added (router writes are disabled)' : 'Device added and policies applied');
    } catch (e) {
      _toast('Could not add device: $e');
    }
  }

  Future<void> _removeMember(MarcoGroup group, MarcoMember member) async {
    try {
      await ref.read(marcoGroupsProvider.notifier).removeMember(group.id, member.deviceId);
    } catch (e) {
      _toast('Could not remove device: $e');
    }
  }

  double? _number(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _savePolicy(MarcoGroup group) async {
    if (_isSaving) return;

    final start = _startController.text.trim();
    final end = _endController.text.trim();
    if ((start.isEmpty) != (end.isEmpty) || (start.isNotEmpty && (!_clock.hasMatch(start) || !_clock.hasMatch(end)))) {
      _toast('Enter both times as HH:MM, or leave both empty');
      return;
    }
    final qos = int.tryParse(_qosController.text.trim());
    if (_qosController.text.trim().isNotEmpty && (qos == null || qos < 1 || qos > 8)) {
      _toast('QoS priority must be between 1 and 8');
      return;
    }
    if (!_unlimitedSpeed && _number(_downloadController) == null && _number(_uploadController) == null) {
      _toast('Enter a download or upload limit, or turn on Unlimited speed');
      return;
    }

    // Start from the stored policy so values this screen does not edit (burst
    // settings) are kept, then overwrite everything the screen manages.
    final policy = Map<String, dynamic>.from(group.policy);
    void put(String key, dynamic value) {
      if (value == null || (value is List && value.isEmpty) || (value is String && value.isEmpty)) {
        policy.remove(key);
      } else {
        policy[key] = value;
      }
    }

    policy['internet_enabled'] = _internetEnabled;
    policy['unlimited_speed'] = _unlimitedSpeed;
    put('download_limit_mbps', _unlimitedSpeed ? null : _number(_downloadController));
    put('upload_limit_mbps', _unlimitedSpeed ? null : _number(_uploadController));
    put('daily_quota_gb', _number(_dailyController));
    put('monthly_quota_gb', _number(_monthlyController));
    put('qos_priority', qos);
    put('schedule_start_time', start);
    put('schedule_end_time', end);
    put('schedule_days', _scheduleDays.toList());
    put('blocked_websites', _blocked.toList());

    setState(() => _isSaving = true);
    try {
      final result = await ref.read(marcoGroupsProvider.notifier).updatePolicy(group.id, policy);
      _toast(result.dryRun ? 'Policies saved. Router writes are disabled, nothing was changed on the router.' : 'Policies applied');
    } catch (e) {
      _toast('Could not apply policies: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
