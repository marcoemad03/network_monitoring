import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/user_role.dart';
import '../../../domain/entities/user.dart';
import '../../../data/repositories/auth_repository_impl.dart';
import '../../../core/di/injection_container.dart';
import '../../providers/auth/auth_provider.dart';

final _userListProvider = FutureProvider.family<List<User>, int>((ref, page) async {
  final repo = ref.watch(_userRepoProvider);
  final result = await repo.getUsers(page: page, limit: 20);
  return result.fold((_) => [], (users) => users);
});

final _userRepoProvider = Provider<AuthRepositoryImpl>((ref) {
  return ref.watch(authRepositoryProvider);
});

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  int _page = 1;
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_userListProvider(_page));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => _showUserDialog(context, null),
            tooltip: 'Add User',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (v) => setState(() {
                _search = v;
                _page = 1;
              }),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No users found', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length + 1,
                  itemBuilder: (context, index) {
                    if (index == users.length) {
                      return const SizedBox(height: 80);
                    }
                    return _UserListTile(
                      user: users[index],
                      onEdit: () => _showUserDialog(context, users[index]),
                      onDelete: () => _confirmDelete(context, users[index]),
                      onResetPassword: () => _showResetPasswordDialog(context, users[index]),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDialog(BuildContext context, User? user) {
    final nameController = TextEditingController(text: user?.displayName ?? '');
    final emailController = TextEditingController(text: user?.email ?? '');
    final usernameController = TextEditingController(text: user?.username ?? '');
    final passwordController = TextEditingController();
    final role = ValueNotifier<String>(user?.role.value ?? UserRole.readOnly.value);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user != null ? 'Edit User' : 'Add User'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person)),
                  enabled: user == null,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Display Name', prefixIcon: Icon(Icons.badge)),
                ),
                const SizedBox(height: 12),
                if (user == null)
                  TextField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
                    obscureText: true,
                  ),
                if (user == null) const SizedBox(height: 12),
                ValueListenableBuilder<String>(
                  valueListenable: role,
                  builder: (context, v, _) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.shield)),
                    value: v,
                    items: UserRole.values
                        .map((r) => DropdownMenuItem(value: r.value, child: Text(r.label)))
                        .toList(),
                    onChanged: (val) => role.value = val ?? UserRole.readOnly.value,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              nameController.dispose();
              emailController.dispose();
              usernameController.dispose();
              passwordController.dispose();
              final repo = ref.read(_userRepoProvider);
              if (user != null) {
                await repo.updateUser(
                  id: user.id,
                  username: usernameController.text,
                  email: emailController.text,
                  displayName: nameController.text,
                  role: role.value,
                );
              } else {
                await repo.createUser(
                  username: usernameController.text,
                  email: emailController.text,
                  password: passwordController.text,
                  role: role.value,
                  displayName: nameController.text,
                );
              }
              ref.invalidate(_userListProvider);
            },
            child: Text(user != null ? 'Save' : 'Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete "${user.displayName ?? user.username}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(_userRepoProvider).deleteUser(user.id);
              ref.invalidate(_userListProvider);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showResetPasswordDialog(BuildContext context, User user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Password'),
        content: SizedBox(
          width: 350,
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock)),
            obscureText: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              controller.dispose();
              if (controller.text.length >= 8) {
                await ref.read(_userRepoProvider).adminResetPassword(user.id, controller.text);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password reset sent')),
                  );
                }
              }
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final User user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onResetPassword;

  const _UserListTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.errorContainer,
          child: Icon(
            Icons.person,
            color: user.isActive ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
        title: Text(user.displayName ?? user.username),
        subtitle: Text(
          '${user.email}  •  ${user.role.label}${!user.isActive ? '  •  Inactive' : ''}',
          style: theme.textTheme.bodySmall,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'edit':
                onEdit();
              case 'reset':
                onResetPassword();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Edit'))),
            const PopupMenuItem(value: 'reset', child: ListTile(leading: Icon(Icons.lock_reset), title: Text('Reset Password'))),
            const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
          ],
        ),
      ),
    );
  }
}
