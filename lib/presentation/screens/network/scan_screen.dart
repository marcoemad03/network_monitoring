import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/validators.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subnetController = TextEditingController();
  final _nameController = TextEditingController();
  final _portRangeController = TextEditingController();
  String _selectedScanType = 'ping';
  bool _isScanning = false;

  @override
  void dispose() {
    _subnetController.dispose();
    _nameController.dispose();
    _portRangeController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Network Scan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Network Scan',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Scan Name',
                          prefixIcon: Icon(Icons.label),
                          hintText: 'e.g., Morning Scan - Building A',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _subnetController,
                        decoration: const InputDecoration(
                          labelText: 'Target Subnet *',
                          prefixIcon: Icon(Icons.lan),
                          hintText: 'e.g., 192.168.1.0/24',
                        ),
                        validator: (v) {
                          final err =
                              Validators.validateRequired(v, 'Target subnet');
                          if (err != null) return err;
                          return Validators.validateSubnet(v);
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Scan Type',
                          prefixIcon: Icon(Icons.category),
                        ),
                        value: _selectedScanType,
                        items: const [
                          DropdownMenuItem(
                              value: 'ping', child: Text('Ping Sweep')),
                          DropdownMenuItem(
                              value: 'arp', child: Text('ARP Scan')),
                          DropdownMenuItem(
                              value: 'port', child: Text('Port Scan')),
                          DropdownMenuItem(
                              value: 'snmp', child: Text('SNMP Scan')),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedScanType = v ?? 'ping'),
                      ),
                      if (_selectedScanType == 'port') ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _portRangeController,
                          decoration: const InputDecoration(
                            labelText: 'Port Range',
                            prefixIcon: Icon(Icons.settings_ethernet),
                            hintText: 'e.g., 1-1024 or 22,80,443',
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isScanning ? null : _startScan,
                          icon: _isScanning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.play_arrow),
                          label: Text(_isScanning
                              ? 'Scanning...'
                              : 'Start Scan'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_isScanning) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Progress',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _StatChip(
                              label: 'Hosts Found', value: '0'),
                          _StatChip(
                              label: 'Active', value: '0'),
                          _StatChip(
                              label: 'Duration', value: '0s'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Recent Scans',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('No recent scans'),
                subtitle: const Text('Start a scan to see history'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
