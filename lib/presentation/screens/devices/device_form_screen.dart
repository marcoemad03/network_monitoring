import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/device.dart';
import '../../providers/device/device_provider.dart';
import '../../providers/equipment/equipment_provider.dart';
import '../../router/route_names.dart';

/// Equipment types a person may register. "Unknown" and "Phone" are left out:
/// those are devices the network discovers by itself.
const _registrable = [
  DeviceType.router,
  DeviceType.switch_,
  DeviceType.accessPoint,
  DeviceType.firewall,
  DeviceType.server,
  DeviceType.printer,
  DeviceType.medicalDevice,
  DeviceType.camera,
  DeviceType.iot,
  DeviceType.workstation,
];

/// Adds a device or edits an existing one, and saves it to the server.
class DeviceFormScreen extends ConsumerStatefulWidget {
  final String? deviceId;

  const DeviceFormScreen({super.key, this.deviceId});

  @override
  ConsumerState<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends ConsumerState<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _hostname = TextEditingController();
  final _ip = TextEditingController();
  final _mac = TextEditingController();
  final _vendor = TextEditingController();
  final _model = TextEditingController();
  final _location = TextEditingController();
  final _department = TextEditingController();
  final _notes = TextEditingController();

  DeviceType _type = DeviceType.switch_;
  bool _critical = false;
  bool _monitored = true;
  bool _saving = false;
  bool _loaded = false;
  Device? _existing;
  String? _error;

  bool get _editing => widget.deviceId != null;

  @override
  void dispose() {
    for (final c in [_name, _hostname, _ip, _mac, _vendor, _model, _location, _department, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Device d) {
    _existing = d;
    _name.text = d.name;
    _hostname.text = d.hostname ?? '';
    _ip.text = d.ipAddress;
    _mac.text = d.macAddress ?? '';
    _vendor.text = d.vendor ?? '';
    _model.text = d.model ?? '';
    _location.text = d.location ?? '';
    _department.text = d.department ?? '';
    _notes.text = d.notes ?? '';
    _type = d.type;
    _critical = d.isCritical;
    _monitored = d.isMonitored;
    _loaded = true;
  }

  String? _nullIfEmpty(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final now = DateTime.now();
    final base = _existing;
    final device = Device(
      id: base?.id ?? '',
      name: _name.text.trim(),
      hostname: _nullIfEmpty(_hostname),
      ipAddress: _ip.text.trim(),
      macAddress: _nullIfEmpty(_mac),
      type: _type,
      status: base?.status ?? DeviceStatus.unknown,
      vendor: _nullIfEmpty(_vendor),
      model: _nullIfEmpty(_model),
      location: _nullIfEmpty(_location),
      department: _nullIfEmpty(_department),
      notes: _nullIfEmpty(_notes),
      customFields: base?.customFields ?? const {},
      firstSeen: base?.firstSeen ?? now,
      lastSeen: base?.lastSeen ?? now,
      isCritical: _critical,
      isMonitored: _monitored,
      createdAt: base?.createdAt ?? now,
      updatedAt: now,
    );

    final result = _editing
        ? await ref.read(updateDeviceUseCaseProvider)(device)
        : await ref.read(createDeviceUseCaseProvider)(device);
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
      (saved) {
        ref.invalidate(equipmentFeedProvider);
        ref.invalidate(deviceDetailProvider(saved.id));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editing ? 'Changes saved' : '"${saved.name}" added')));
        if (_editing) {
          context.pop();
        } else {
          context.pushReplacement(RouteNames.deviceDetail.replaceAll(':id', saved.id));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_editing && !_loaded) {
      final async = ref.watch(deviceDetailProvider(widget.deviceId!));
      return Scaffold(
        appBar: AppBar(title: const Text('Edit device')),
        body: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _LoadFailed(onRetry: () => ref.invalidate(deviceDetailProvider(widget.deviceId!))),
          data: (device) {
            if (device == null) return _LoadFailed(onRetry: () => ref.invalidate(deviceDetailProvider(widget.deviceId!)));
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_loaded) setState(() => _fill(device));
            });
            return const Center(child: CircularProgressIndicator());
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit device' : 'Add device'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) _ErrorBanner(message: _error!),
                _section(theme, 'Basic information', [
                  TextFormField(
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Name *', prefixIcon: Icon(Icons.label_outline), border: OutlineInputBorder()),
                    validator: (v) => Validators.validateRequired(v, 'The name'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ip,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'IP address *',
                      helperText: 'The address the NMS pings to see if it is up',
                      prefixIcon: Icon(Icons.lan_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: Validators.validateIpAddress,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<DeviceType>(
                    initialValue: _registrable.contains(_type) ? _type : null,
                    decoration: const InputDecoration(labelText: 'Type *', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                    items: [for (final t in _registrable) DropdownMenuItem(value: t, child: Text(t.label))],
                    validator: (v) => v == null ? 'Choose the type' : null,
                    onChanged: (v) => setState(() => _type = v ?? _type),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _mac,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'MAC address', hintText: 'AA:BB:CC:DD:EE:FF', prefixIcon: Icon(Icons.fingerprint), border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.validateMacAddress(v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _hostname,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Host name', prefixIcon: Icon(Icons.computer_outlined), border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.trim().isEmpty) ? null : Validators.validateHostname(v),
                  ),
                ]),
                _section(theme, 'Hardware', [
                  Row(children: [
                    Expanded(child: TextFormField(controller: _vendor, decoration: const InputDecoration(labelText: 'Vendor', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Model', border: OutlineInputBorder()))),
                  ]),
                ]),
                _section(theme, 'Where it is', [
                  TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location', hintText: 'Building, floor, room', prefixIcon: Icon(Icons.place_outlined), border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextFormField(controller: _department, decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment_outlined), border: OutlineInputBorder())),
                ]),
                _section(theme, 'Monitoring', [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Monitor this device'),
                    subtitle: const Text('Ping it regularly and raise an alert when it stops answering'),
                    value: _monitored,
                    onChanged: (v) => setState(() => _monitored = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Critical device'),
                    subtitle: const Text('Shown first, and its alerts are marked as critical'),
                    value: _critical,
                    onChanged: (v) => setState(() => _critical = v),
                  ),
                ]),
                _section(theme, 'Notes', [
                  TextFormField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true, border: OutlineInputBorder()),
                  ),
                ]),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: scheme.onErrorContainer))),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 40),
          const SizedBox(height: 12),
          const Text('Could not load the device'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
