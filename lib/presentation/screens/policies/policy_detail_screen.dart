import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/asset_providers.dart';

class PolicyDetailScreen extends ConsumerStatefulWidget {
  final String? policyId;
  const PolicyDetailScreen({super.key, this.policyId});

  @override
  ConsumerState<PolicyDetailScreen> createState() => _PolicyDetailScreenState();
}

class _PolicyDetailScreenState extends ConsumerState<PolicyDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _policyType = 'website_blacklist';
  bool _isActive = true;
  Map<String, dynamic> _config = {};
  bool _isLoading = true;

  static const _policyTypes = [
    'website_blacklist',
    'website_whitelist',
    'bandwidth_limit',
    'upload_limit',
    'download_limit',
    'internet_access',
    'schedule',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.policyId != null && widget.policyId != 'create') {
      _loadPolicy();
    } else {
      _isLoading = false;
    }
  }

  void _loadPolicy() async {
    final result = await ref.read(assetRepositoryProvider).getPolicy(widget.policyId!);
    result.fold(
      (failure) => setState(() => _isLoading = false),
      (policy) {
        _nameCtrl.text = policy.name;
        _descCtrl.text = policy.description ?? '';
        _policyType = policy.policyType;
        _isActive = policy.isActive;
        _config = Map<String, dynamic>.from(policy.config);
        setState(() => _isLoading = false);
      },
    );
  }

  void _save() async {
    final data = {
      'name': _nameCtrl.text,
      'description': _descCtrl.text.isEmpty ? null : _descCtrl.text,
      'policy_type': _policyType,
      'is_active': _isActive,
      'config': _config,
    };

    if (widget.policyId == null || widget.policyId == 'create') {
      await ref.read(assetRepositoryProvider).createPolicy(data);
    } else {
      await ref.read(assetRepositoryProvider).updatePolicy(widget.policyId!, data);
    }
    if (context.mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.policyId == 'create' ? 'Create Policy' : 'Edit Policy'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _policyType,
              decoration: const InputDecoration(labelText: 'Policy Type', border: OutlineInputBorder()),
              items: _policyTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _policyType = v ?? 'website_blacklist'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            Text('Config', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_policyType == 'website_blacklist' || _policyType == 'website_whitelist')
              _DomainListEditor(
                domains: List<String>.from(_config['domains'] ?? []),
                onChanged: (domains) => setState(() => _config['domains'] = domains),
              ),
            if (_policyType == 'bandwidth_limit' || _policyType == 'upload_limit' || _policyType == 'download_limit')
              _BandwidthEditor(
                uploadBps: _config['upload_limit_bps'],
                downloadBps: _config['download_limit_bps'],
                target: _config['target'] as String? ?? '',
                onUploadChanged: (v) => _config['upload_limit_bps'] = v,
                onDownloadChanged: (v) => _config['download_limit_bps'] = v,
                onTargetChanged: (v) => _config['target'] = v,
              ),
            if (_policyType == 'internet_access')
              SwitchListTile(
                title: const Text('Internet Enabled'),
                value: _config['enabled'] as bool? ?? true,
                onChanged: (v) => setState(() => _config['enabled'] = v),
              ),
            if (_policyType == 'schedule')
              _ScheduleEditor(
                startTime: _config['start_time'] as String? ?? '',
                endTime: _config['end_time'] as String? ?? '',
                days: _config['days'] as String? ?? '',
                action: _config['action'] as String? ?? 'drop',
                onStartChanged: (v) => _config['start_time'] = v,
                onEndChanged: (v) => _config['end_time'] = v,
                onDaysChanged: (v) => _config['days'] = v,
                onActionChanged: (v) => _config['action'] = v,
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }
}

class _DomainListEditor extends StatelessWidget {
  final List<String> domains;
  final ValueChanged<List<String>> onChanged;

  const _DomainListEditor({required this.domains, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController();
    return Column(
      children: [
        ...domains.map((d) => ListTile(
          title: Text(d),
          trailing: IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              final updated = List<String>.from(domains)..remove(d);
              onChanged(updated);
            },
          ),
        )),
        Row(
          children: [
            Expanded(child: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Domain', border: OutlineInputBorder()))),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (ctrl.text.isNotEmpty) {
                  onChanged([...domains, ctrl.text]);
                  ctrl.clear();
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _BandwidthEditor extends StatelessWidget {
  final dynamic uploadBps;
  final dynamic downloadBps;
  final String target;
  final ValueChanged<int?> onUploadChanged;
  final ValueChanged<int?> onDownloadChanged;
  final ValueChanged<String> onTargetChanged;

  const _BandwidthEditor({
    required this.uploadBps,
    required this.downloadBps,
    required this.target,
    required this.onUploadChanged,
    required this.onDownloadChanged,
    required this.onTargetChanged,
  });

  @override
  Widget build(BuildContext context) {
    final uploadCtrl = TextEditingController(text: uploadBps?.toString() ?? '');
    final downloadCtrl = TextEditingController(text: downloadBps?.toString() ?? '');
    final targetCtrl = TextEditingController(text: target);

    return Column(
      children: [
        TextField(
          controller: uploadCtrl,
          decoration: const InputDecoration(labelText: 'Upload Limit (bps)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) => onUploadChanged(int.tryParse(v)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: downloadCtrl,
          decoration: const InputDecoration(labelText: 'Download Limit (bps)', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          onChanged: (v) => onDownloadChanged(int.tryParse(v)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: targetCtrl,
          decoration: const InputDecoration(labelText: 'Target (e.g. 192.168.1.0/24)', border: OutlineInputBorder()),
          onChanged: onTargetChanged,
        ),
      ],
    );
  }
}

class _ScheduleEditor extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String days;
  final String action;
  final ValueChanged<String> onStartChanged;
  final ValueChanged<String> onEndChanged;
  final ValueChanged<String> onDaysChanged;
  final ValueChanged<String> onActionChanged;

  const _ScheduleEditor({
    required this.startTime,
    required this.endTime,
    required this.days,
    required this.action,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onDaysChanged,
    required this.onActionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final startCtrl = TextEditingController(text: startTime);
    final endCtrl = TextEditingController(text: endTime);
    final daysCtrl = TextEditingController(text: days);
    final actionCtrl = TextEditingController(text: action);

    return Column(
      children: [
        TextField(
          controller: startCtrl,
          decoration: const InputDecoration(labelText: 'Start Time (e.g. 08:00:00)', border: OutlineInputBorder()),
          onChanged: onStartChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: endCtrl,
          decoration: const InputDecoration(labelText: 'End Time (e.g. 18:00:00)', border: OutlineInputBorder()),
          onChanged: onEndChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: daysCtrl,
          decoration: const InputDecoration(labelText: 'Days (e.g. mon,tue,wed)', border: OutlineInputBorder()),
          onChanged: onDaysChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: actionCtrl,
          decoration: const InputDecoration(labelText: 'Action (accept/drop)', border: OutlineInputBorder()),
          onChanged: onActionChanged,
        ),
      ],
    );
  }
}
