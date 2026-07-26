import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/internet/internet_provider.dart';
import '../../../domain/entities/vendor_integration.dart';

class VendorIntegrationsScreen extends ConsumerWidget {
  const VendorIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final vendorsAsync = ref.watch(vendorIntegrationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Integrations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(vendorIntegrationsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_vendor',
        onPressed: () => _showVendorDialog(context, ref, null),
        child: const Icon(Icons.add),
      ),
      body: vendorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (vendors) {
          if (vendors.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_sync_outlined,
                    size: 64,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text('No integrations', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showVendorDialog(context, ref, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Integration'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: vendors.length,
            itemBuilder:
                (context, index) => _VendorCard(
                  vendor: vendors[index],
                  onEdit: () => _showVendorDialog(context, ref, vendors[index]),
                  onDelete: () async {
                    final repo = ref.read(internetRepositoryProvider);
                    final result = await repo.deleteVendorIntegration(
                      vendors[index].id,
                    );
                    result.fold(
                      (f) => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${f.message}')),
                      ),
                      (_) => ref.invalidate(vendorIntegrationsProvider),
                    );
                  },
                  onTest: () async {
                    final repo = ref.read(internetRepositoryProvider);
                    final result = await repo.testVendorConnection(
                      vendors[index].id,
                    );
                    result.fold(
                      (f) => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Test failed: ${f.message}'),
                          backgroundColor: Colors.red,
                        ),
                      ),
                      (_) => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Connection successful'),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    );
                  },
                  onSync: () async {
                    final repo = ref.read(internetRepositoryProvider);
                    final result = await repo.syncVendor(vendors[index].id);
                    result.fold(
                      (f) => ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sync failed: ${f.message}'),
                          backgroundColor: Colors.red,
                        ),
                      ),
                      (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Sync initiated'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                        ref.invalidate(vendorIntegrationsProvider);
                      },
                    );
                  },
                ),
          );
        },
      ),
    );
  }

  void _showVendorDialog(
    BuildContext context,
    WidgetRef ref,
    VendorIntegration? existing,
  ) {
    final nameCtrl = TextEditingController(text: existing?.name);
    final urlCtrl = TextEditingController(text: existing?.baseUrl);
    final userCtrl = TextEditingController(text: existing?.username);
    final apiKeyCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var vendorType = existing?.vendorType ?? 'mikrotik';
    var isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setDialogState) => AlertDialog(
                  title: Text(
                    existing == null
                        ? 'Add Vendor Integration'
                        : 'Edit Integration',
                  ),
                  content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: vendorType,
                            decoration: const InputDecoration(
                              labelText: 'Vendor',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'mikrotik',
                                child: Text('MikroTik'),
                              ),
                              DropdownMenuItem(
                                value: 'pfsense',
                                child: Text('pfSense'),
                              ),
                              DropdownMenuItem(
                                value: 'opnsense',
                                child: Text('OPNsense'),
                              ),
                              DropdownMenuItem(
                                value: 'cisco',
                                child: Text('Cisco'),
                              ),
                              DropdownMenuItem(
                                value: 'unifi',
                                child: Text('UniFi'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null)
                                setDialogState(() => vendorType = v);
                            },
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: urlCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Base URL',
                              hintText: 'https://192.168.1.1',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: userCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Username',
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  existing != null
                                      ? 'New Password (leave empty to keep)'
                                      : 'Password',
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: apiKeyCtrl,
                            decoration: InputDecoration(
                              labelText:
                                  existing != null ? 'New API Key' : 'API Key',
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: const Text('Active'),
                            value: isActive,
                            onChanged:
                                (v) => setDialogState(() => isActive = v),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        final repo = ref.read(internetRepositoryProvider);
                        final integration = VendorIntegration(
                          id: existing?.id ?? '',
                          organizationId: existing?.organizationId ?? '',
                          vendorType: vendorType,
                          name: nameCtrl.text.trim(),
                          baseUrl: urlCtrl.text.trim(),
                          username:
                              userCtrl.text.trim().isEmpty
                                  ? null
                                  : userCtrl.text.trim(),
                          password:
                              passCtrl.text.isEmpty ? null : passCtrl.text,
                          apiKey:
                              apiKeyCtrl.text.isEmpty ? null : apiKeyCtrl.text,
                          apiVersion: existing?.apiVersion,
                          isActive: isActive,
                          lastSyncAt: existing?.lastSyncAt,
                          lastSyncStatus: existing?.lastSyncStatus,
                          errorMessage: existing?.errorMessage,
                          createdAt: existing?.createdAt ?? DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        final result =
                            existing == null
                                ? await repo.createVendorIntegration(
                                  integration,
                                )
                                : await repo.updateVendorIntegration(
                                  integration,
                                );
                        result.fold(
                          (f) => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${f.message}')),
                          ),
                          (_) {
                            ref.invalidate(vendorIntegrationsProvider);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }
}

class _VendorCard extends StatelessWidget {
  final VendorIntegration vendor;
  final VoidCallback onEdit, onDelete, onTest, onSync;

  const _VendorCard({
    required this.vendor,
    required this.onEdit,
    required this.onDelete,
    required this.onTest,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vendorIcon = switch (vendor.vendorType) {
      'mikrotik' => Icons.router_outlined,
      'pfsense' => Icons.shield_outlined,
      'opnsense' => Icons.security_outlined,
      'cisco' => Icons.lan_outlined,
      'unifi' => Icons.wifi_outlined,
      _ => Icons.dns_outlined,
    };
    final statusColor = vendor.isActive ? Colors.green : Colors.grey;
    final syncColor =
        vendor.lastSyncStatus == 'success'
            ? Colors.green
            : vendor.lastSyncStatus == 'failed'
            ? Colors.red
            : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(vendorIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            vendor.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              vendor.vendorType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        vendor.baseUrl,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, size: 18),
                            title: Text('Edit'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'test',
                          child: ListTile(
                            leading: Icon(Icons.wifi_tethering, size: 18),
                            title: Text('Test Connection'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'sync',
                          child: ListTile(
                            leading: Icon(Icons.sync, size: 18),
                            title: Text('Sync'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                            dense: true,
                          ),
                        ),
                      ],
                  onSelected:
                      (v) => switch (v) {
                        'edit' => onEdit(),
                        'test' => onTest(),
                        'sync' => onSync(),
                        'delete' => onDelete(),
                        _ => null,
                      },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 8, color: syncColor),
                const SizedBox(width: 4),
                Text(
                  vendor.lastSyncAt != null
                      ? 'Last sync: ${_formatDate(vendor.lastSyncAt!)}'
                      : 'Never synced',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (vendor.lastSyncStatus != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '(${vendor.lastSyncStatus})',
                    style: TextStyle(fontSize: 11, color: syncColor),
                  ),
                ],
              ],
            ),
            if (vendor.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                vendor.errorMessage!,
                style: TextStyle(fontSize: 11, color: Colors.red.shade300),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
