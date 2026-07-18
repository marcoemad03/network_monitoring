import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/internet/internet_provider.dart';
import '../../router/route_names.dart';
import '../../../domain/entities/internet_policy.dart';

class InternetPolicyListScreen extends ConsumerWidget {
  const InternetPolicyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final policiesAsync = ref.watch(internetPoliciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internet Policies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(internetPoliciesProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'add_policy',
        onPressed: () => context.push(RouteNames.internetPolicyCreate),
        child: const Icon(Icons.add),
      ),
      body: policiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (policies) {
          if (policies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.policy_outlined, size: 64, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('No policies yet', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push(RouteNames.internetPolicyCreate),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Policy'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: policies.length,
            itemBuilder: (context, index) => _PolicyCard(
              policy: policies[index],
              onTap: () => context.push(RouteNames.internetPolicyDetail.replaceAll(':id', policies[index].id)),
            ),
          );
        },
      ),
    );
  }
}

class _PolicyCard extends StatelessWidget {
  final InternetPolicy policy;
  final VoidCallback onTap;

  const _PolicyCard({required this.policy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = switch (policy.policyType) {
      'unlimited' => Colors.green,
      'limited' => Colors.orange,
      'blocked' => Colors.red,
      'filtering' => Colors.blue,
      _ => Colors.grey,
    };
    final typeIcon = switch (policy.policyType) {
      'unlimited' => Icons.speed,
      'limited' => Icons.speed,
      'blocked' => Icons.block,
      'filtering' => Icons.filter_alt,
      _ => Icons.policy,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(typeIcon, color: typeColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(policy.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (policy.department != null) ...[
                          _Tag(label: policy.department!, color: Colors.grey),
                          const SizedBox(width: 8),
                        ],
                        _Tag(label: policy.policyType.toUpperCase(), color: typeColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_limitsText(policy), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _Tag({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  String _limitsText(InternetPolicy p) {
    if (p.policyType == 'unlimited') return 'No limits';
    if (p.policyType == 'blocked') return 'All traffic blocked';
    if (p.uploadLimitBps != null && p.downloadLimitBps != null) {
      return '↑ ${_formatBps(p.uploadLimitBps!)} / ↓ ${_formatBps(p.downloadLimitBps!)}';
    }
    return '';
  }

  String _formatBps(int bps) {
    if (bps >= 1_000_000_000) return '${(bps / 1_000_000_000).toStringAsFixed(1)} Gbps';
    if (bps >= 1_000_000) return '${(bps / 1_000_000).toStringAsFixed(0)} Mbps';
    if (bps >= 1_000) return '${(bps / 1_000).toStringAsFixed(0)} Kbps';
    return '$bps bps';
  }
}
