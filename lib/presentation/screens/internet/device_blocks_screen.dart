import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/internet/internet_provider.dart';
import '../../../domain/entities/device_block.dart';

class DeviceBlocksScreen extends ConsumerWidget {
  const DeviceBlocksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocksAsync = ref.watch(deviceBlocksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Blocks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceBlocksProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'block_device',
        onPressed: () => _showBlockDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: blocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (blocks) {
          if (blocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No blocked devices', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showBlockDialog(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Block a Device'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: blocks.length,
            itemBuilder: (context, index) => _BlockCard(
              block: blocks[index],
              onUnblock: () async {
                final repo = ref.read(internetRepositoryProvider);
                (await repo.unblockDevice(blocks[index].id)).fold(
                  (_) => ref.invalidate(deviceBlocksProvider),
                  (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showBlockDialog(BuildContext context, WidgetRef ref) {
    final macCtrl = TextEditingController();
    final ipCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block Device'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: macCtrl, decoration: const InputDecoration(labelText: 'MAC Address', hintText: 'AA:BB:CC:DD:EE:FF')),
                const SizedBox(height: 16),
                TextField(controller: ipCtrl, decoration: const InputDecoration(labelText: 'IP Address', hintText: '192.168.1.100')),
                const SizedBox(height: 16),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 2),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final repo = ref.read(internetRepositoryProvider);
              final block = DeviceBlock(
                id: '', organizationId: '', deviceId: null,
                macAddress: macCtrl.text.trim().isEmpty ? null : macCtrl.text.trim(),
                ipAddress: ipCtrl.text.trim().isEmpty ? null : ipCtrl.text.trim(),
                reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
                blockedBy: null, blockedAt: DateTime.now(),
                isActive: true,
              );
              (await repo.blockDevice(block)).fold(
                (_) { ref.invalidate(deviceBlocksProvider); Navigator.pop(ctx); },
                (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${f.message}'))),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  final DeviceBlock block;
  final VoidCallback onUnblock;

  const _BlockCard({required this.block, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.block, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(block.macAddress ?? block.ipAddress ?? 'Unknown', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  if (block.reason != null) Text(block.reason!, style: theme.textTheme.bodySmall),
                  Text('Blocked: ${_formatDate(block.blockedAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onUnblock,
              style: FilledButton.styleFrom(backgroundColor: Colors.green.withValues(alpha: 0.1)),
              child: const Text('Unblock', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) => '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
