import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/enums/device_type.dart';
import '../../../core/enums/device_status.dart';
import '../../../core/utils/validators.dart';

class DeviceFormScreen extends ConsumerStatefulWidget {
  final String? deviceId;

  const DeviceFormScreen({super.key, this.deviceId});

  @override
  ConsumerState<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends ConsumerState<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostnameController = TextEditingController();
  final _ipController = TextEditingController();
  final _macController = TextEditingController();
  final _vendorController = TextEditingController();
  final _modelController = TextEditingController();
  final _locationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _notesController = TextEditingController();

  DeviceType _selectedType = DeviceType.unknown;
  DeviceStatus _selectedStatus = DeviceStatus.unknown;
  bool _isCritical = false;
  bool _isMonitored = true;
  bool _isSaving = false;

  bool get isEditing => widget.deviceId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _ipController.dispose();
    _macController.dispose();
    _vendorController.dispose();
    _modelController.dispose();
    _locationController.dispose();
    _departmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isSaving = false);

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Device' : 'Add Device'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(theme, 'Basic Information', [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name *',
                  prefixIcon: Icon(Icons.devices),
                ),
                validator: (v) => Validators.validateRequired(v, 'Device name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _hostnameController,
                decoration: const InputDecoration(
                  labelText: 'Hostname',
                  prefixIcon: Icon(Icons.computer),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Network Configuration', [
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP Address *',
                  prefixIcon: Icon(Icons.lan),
                ),
                keyboardType: TextInputType.text,
                validator: (v) {
                  final err = Validators.validateRequired(v, 'IP address');
                  if (err != null) return err;
                  return Validators.validateIpAddress(v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _macController,
                decoration: const InputDecoration(
                  labelText: 'MAC Address',
                  prefixIcon: Icon(Icons.cable),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return null;
                  return Validators.validateMacAddress(v);
                },
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Classification', [
              DropdownButtonFormField<DeviceType>(
                decoration: const InputDecoration(
                  labelText: 'Device Type',
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedType,
                items: DeviceType.values
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v ?? DeviceType.unknown),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DeviceStatus>(
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.circle),
                ),
                value: _selectedStatus,
                items: DeviceStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.label),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedStatus = v ?? DeviceStatus.unknown),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Hardware Details', [
              TextFormField(
                controller: _vendorController,
                decoration: const InputDecoration(
                  labelText: 'Vendor',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  prefixIcon: Icon(Icons.tag),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Location', [
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Settings', [
              SwitchListTile(
                title: const Text('Critical Device'),
                subtitle: const Text('Mark as critical infrastructure'),
                value: _isCritical,
                onChanged: (v) => setState(() => _isCritical = v),
                secondary: const Icon(Icons.warning_amber),
              ),
              SwitchListTile(
                title: const Text('Monitoring Enabled'),
                subtitle: const Text('Actively monitor this device'),
                value: _isMonitored,
                onChanged: (v) => setState(() => _isMonitored = v),
                secondary: const Icon(Icons.visibility),
              ),
            ]),
            const SizedBox(height: 12),
            _buildSection(theme, 'Notes', [
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
              ),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
