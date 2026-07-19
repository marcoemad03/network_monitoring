import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/asset_providers.dart';
import '../../router/route_names.dart';

class FloorMapListScreen extends ConsumerWidget {
  const FloorMapListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Floor Maps')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: repo.getFloorMaps(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Error loading floor maps'));
          }
          return result.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (maps) {
              if (maps.isEmpty) {
                return const Center(child: Text('No floor maps yet'));
              }
              return ListView.builder(
                itemCount: maps.length,
                itemBuilder: (context, index) {
                  final map = maps[index];
                  return ListTile(
                    title: Text(map.name),
                    subtitle: Text('${map.width}x${map.height}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push(RouteNames.floorMapEditor(map.id)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteMap(context, ref, map.id),
                        ),
                      ],
                    ),
                    onTap: () => context.push(RouteNames.floorMapDetail(map.id)),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Floor Map'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: pathCtrl, decoration: const InputDecoration(labelText: 'Image URL / Path')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(assetRepositoryProvider).createFloorMap({
                'name': nameCtrl.text,
                'image_path': pathCtrl.text,
              });
              ref.invalidate(assetRepositoryProvider);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _deleteMap(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Floor Map'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(assetRepositoryProvider).deleteFloorMap(id);
      ref.invalidate(assetRepositoryProvider);
    }
  }
}
