import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/asset_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Group Detail')),
      body: FutureBuilder(
        future: Future.wait([repo.getGroup(groupId), repo.getGroupDeviceIds(groupId)]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data;
          if (results == null || results.length < 2) {
            return const Center(child: Text('Error loading'));
          }
          final groupResult = results[0] as dynamic;
          final devicesResult = results[1] as dynamic;
          return groupResult.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (group) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(group.name, style: Theme.of(context).textTheme.titleLarge),
                        if (group.description != null) Text(group.description!),
                        const SizedBox(height: 8),
                        Text('Created: ${group.createdAt.toLocal().toString().split('.')[0]}'),
                      ],
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Devices in Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: devicesResult.fold(
                      (failure) => Center(child: Text('Error: ${failure.message}')),
                      (deviceIds) {
                        if (deviceIds.isEmpty) {
                          return const Center(child: Text('No devices assigned'));
                        }
                        return ListView.builder(
                          itemCount: deviceIds.length,
                          itemBuilder: (context, index) => ListTile(
                            title: Text(deviceIds[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              onPressed: () {
                                ref.read(assetRepositoryProvider).removeDeviceFromGroup(groupId, deviceIds[index]);
                                ref.invalidate(assetRepositoryProvider);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAssignDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Assign Devices'),
      ),
    );
  }

  void _showAssignDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Assign Devices'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Device IDs (comma separated)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ids = ctrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              if (ids.isNotEmpty) {
                await ref.read(assetRepositoryProvider).assignDevicesToGroup(groupId, ids);
                ref.invalidate(assetRepositoryProvider);
              }
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}
