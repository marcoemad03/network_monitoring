import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/asset_providers.dart';
import '../../router/route_names.dart';

class PolicyListScreen extends ConsumerWidget {
  const PolicyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Policies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync with MikroTik',
            onPressed: () async {
              await ref.read(assetRepositoryProvider).syncPolicies();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sync started')),
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.assetPolicyDetail('create')),
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        future: repo.getPolicies(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final result = snapshot.data;
          if (result == null) {
            return const Center(child: Text('Error loading policies'));
          }
          return result.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (policies) {
              if (policies.isEmpty) {
                return const Center(child: Text('No policies created yet'));
              }
              return ListView.builder(
                itemCount: policies.length,
                itemBuilder: (context, index) {
                  final p = policies[index];
                  return ListTile(
                    leading: Icon(
                      p.isActive ? Icons.check_circle : Icons.cancel,
                      color: p.isActive ? Colors.green : Colors.red,
                    ),
                    title: Text(p.name),
                    subtitle: Text('${p.policyType} | ${p.description ?? ""}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push(RouteNames.assetPolicyDetail(p.id)),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deletePolicy(context, ref, p.id),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _deletePolicy(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Policy'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(assetRepositoryProvider).deletePolicy(id);
      ref.invalidate(assetRepositoryProvider);
    }
  }
}
