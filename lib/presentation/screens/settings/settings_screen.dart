import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../providers/auth/auth_provider.dart';
import '../../router/route_names.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Theme'),
            subtitle: Text(themeMode.name),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode)),
                ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode)),
                ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.settings_brightness)),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                ref.read(themeProvider.notifier).setThemeMode(selected.first);
              },
            ),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Account'),
          ListTile(
            leading: CircleAvatar(
              child: Text(authState.user?.displayName?.isNotEmpty == true
                  ? authState.user!.displayName![0].toUpperCase()
                  : 'U'),
            ),
            title: Text(authState.user?.displayName ?? authState.user?.username ?? 'User'),
            subtitle: Text(authState.user?.email ?? ''),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text('Active Sessions'),
            subtitle: const Text('Manage your login sessions'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSessionsDialog(context, ref),
          ),
          if (authState.canManagePermissions) ...[
            const Divider(),
            _buildSectionHeader(context, 'Administration'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Permission Management'),
              subtitle: const Text('Manage roles and permissions'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.permissionManagement),
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('User Management'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(RouteNames.userManagement),
            ),
          ],
          const Divider(),
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text(AppConstants.appName),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentCtrl,
                decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline)),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock)),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
                return;
              }
              if (newCtrl.text.length < 8) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 8 characters')));
                return;
              }
              final authRepo = ref.read(authRepositoryProvider);
              final result = await authRepo.changePassword(
                currentPassword: currentCtrl.text,
                newPassword: newCtrl.text,
              );
              currentCtrl.dispose();
              newCtrl.dispose();
              confirmCtrl.dispose();
              Navigator.pop(ctx);
              result.fold(
                (failure) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
                  }
                },
                (_) async {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully')));
                  }
                  final repo = ref.read(authProvider.notifier);
                  await repo.logout();
                  if (context.mounted) context.go(RouteNames.login);
                },
              );
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _showSessionsDialog(BuildContext context, WidgetRef ref) {
    final repo = ref.read(authRepositoryProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Sessions'),
        content: FutureBuilder(
          future: repo.getSessions(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
            }
            final sessions = snapshot.data?.getOrElse(() => []) ?? [];
            if (sessions.isEmpty) {
              return const Text('No active sessions');
            }
            return SizedBox(
              width: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: sessions.length,
                itemBuilder: (context, index) {
                  final s = sessions[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.devices, size: 20),
                    title: Text(s.userAgent ?? 'Unknown device', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${s.ipAddress ?? 'Unknown IP'}  •  ${_formatDate(s.lastActivity)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.logout, size: 18),
                      onPressed: () async {
                        await repo.revokeSession(s.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSessionsDialog(context, ref);
                      },
                    ),
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await repo.revokeAllSessions();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Revoke All'),
          ),
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
