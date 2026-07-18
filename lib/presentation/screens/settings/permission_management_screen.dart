import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/permission.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../core/di/injection_container.dart';
import '../../providers/auth/auth_provider.dart';

final _rolesWithPermissionsProvider = FutureProvider<List<RoleWithPermissions>>((ref) async {
  final repo = ref.watch(_authRepoProvider);
  final result = await repo.getAllRolesWithPermissions();
  return result.fold((_) => [], (r) => r);
});

final _allPermissionsProvider = FutureProvider<List<Permission>>((ref) async {
  final repo = ref.watch(_authRepoProvider);
  final result = await repo.getPermissions();
  return result.fold((_) => [], (p) => p);
});

final _authRepoProvider = Provider<AuthRepositoryImpl>((ref) {
  return ref.watch(authRepositoryProvider);
});

class PermissionManagementScreen extends ConsumerWidget {
  const PermissionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(_rolesWithPermissionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Permission Management')),
      body: rolesAsync.when(
        data: (roles) {
          if (roles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.admin_panel_settings_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No roles configured', style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: roles.length,
            itemBuilder: (context, index) {
              final rwp = roles[index];
              final grouped = <String, List<Permission>>{};
              for (final perm in rwp.permissions) {
                grouped.putIfAbsent(perm.module, () => []).add(perm);
              }
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: rwp.role.isSystemRole
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.secondaryContainer,
                    child: Icon(Icons.shield, color: rwp.role.isSystemRole
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary),
                  ),
                  title: Text(rwp.role.name, style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    '${rwp.role.slug}  •  Level ${rwp.role.permissionLevel}${rwp.role.isSystemRole ? '  •  System' : ''}',
                    style: theme.textTheme.bodySmall,
                  ),
                  children: [
                    if (!rwp.role.isSystemRole)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: () => _showEditPermissionsDialog(context, ref, rwp),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit Permissions'),
                            ),
                          ],
                        ),
                      ),
                    ...grouped.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.key.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: entry.value.map((p) => Chip(
                              avatar: Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                              label: Text(p.name, style: const TextStyle(fontSize: 12)),
                              visualDensity: VisualDensity.compact,
                            )).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    )),
                    const SizedBox(height: 8),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _showEditPermissionsDialog(BuildContext context, WidgetRef ref, RoleWithPermissions rwp) {
    final selectedIds = rwp.permissions.map((p) => p.id).toSet();
    final allPermsAsync = ref.read(_allPermissionsProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Permissions for ${rwp.role.name}'),
              content: SizedBox(
                width: 500,
                child: allPermsAsync.when(
                  data: (allPerms) {
                    final grouped = <String, List<Permission>>{};
                    for (final p in allPerms) {
                      grouped.putIfAbsent(p.module, () => []).add(p);
                    }
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: grouped.entries.map((entry) => Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.key.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ...entry.value.map((perm) => CheckboxListTile(
                              dense: true,
                              title: Text(perm.name, style: const TextStyle(fontSize: 14)),
                              subtitle: perm.description != null ? Text(perm.description!, style: const TextStyle(fontSize: 11)) : null,
                              value: selectedIds.contains(perm.id),
                              onChanged: (checked) async {
                                final repo = ref.read(_authRepoProvider);
                                if (checked == true) {
                                  await repo.assignPermission(rwp.role.id, perm.id);
                                  selectedIds.add(perm.id);
                                } else {
                                  await repo.removePermission(rwp.role.id, perm.id);
                                  selectedIds.remove(perm.id);
                                }
                                setDialogState(() {});
                              },
                            )),
                          ],
                        )).toList(),
                      ),
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
              actions: [
                FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
              ],
            );
          },
        );
      },
    );
  }
}
