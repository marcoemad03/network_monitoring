import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../router/route_names.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/extensions/datetime_extensions.dart';

final _connectionsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(dioProvider);
  final response = await client.get('/vendors/current/connections');
  return response.data as Map<String, dynamic>;
});

final _dnsCacheProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.watch(dioProvider);
  final response = await client.get('/vendors/current/dns-cache');
  return response.data as Map<String, dynamic>;
});

class ActiveConnectionsScreen extends ConsumerWidget {
  const ActiveConnectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref.watch(_connectionsProvider);
    final dnsCache = ref.watch(_dnsCacheProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Connections'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(_connectionsProvider);
              ref.invalidate(_dnsCacheProvider);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              theme,
              title: 'Active Firewall Connections',
              icon: Icons.lan,
              asyncValue: connections,
              emptyText: 'No active connections found.',
              note: 'Active connections show real-time traffic between devices and external hosts. '
                  'For visited websites (HTTP/HTTPS hostnames), RouterOS cannot decrypt TLS traffic. '
                  'To capture visited domains, enable DNS logging or use Web Proxy with transparent proxy rules.',
              itemBuilder: (data) {
                final list = data['data'] as List<dynamic>? ?? [];
                return Column(
                  children: list.take(50).map((entry) {
                    final e = entry as Map<String, dynamic>;
                    final src = e['src-address']?.toString() ?? '';
                    const dst = 'N/A';
                    final protocol = e['protocol']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      title: Text('$src → $dst', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('Protocol: $protocol', style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildSection(
              theme,
              title: 'DNS Cache',
              icon: Icons.dns,
              asyncValue: dnsCache,
              emptyText: 'No DNS cache entries found.',
              note: 'DNS cache shows recently resolved domain names. '
                  'This data is available only if the MikroTik DNS cache is enabled and populated. '
                  'For complete web browsing history, consider enabling DNS logging or Web Proxy.',
              itemBuilder: (data) {
                final list = data['data'] as List<dynamic>? ?? [];
                return Column(
                  children: list.take(100).map((entry) {
                    final e = entry as Map<String, dynamic>;
                    final name = e['name']?.toString() ?? '';
                    final address = e['address']?.toString() ?? '';
                    return ListTile(
                      dense: true,
                      title: Text(name, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(address, style: const TextStyle(fontSize: 11)),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text('Technical Limitations', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    Text(
                      'RouterOS alone cannot determine the exact visited websites for HTTPS traffic '
                      'because TLS encryption hides the requested hostname in the encrypted payload. '
                      'The following methods are required for full web browsing visibility:\n\n'
                      '1. DNS Logging — Enable DNS query logging on the router to capture all resolved domains.\n'
                      '2. Web Proxy — Configure MikroTik Web Proxy with transparent HTTP proxy rules.\n'
                      '3. Layer7 Firewall Rules — Add Layer7 protocol matchers for specific patterns.\n'
                      '4. TLS Host Matching — RouterOS v7+ supports TLS host matching via certificate inspection.\n'
                      '5. External Monitoring — Deploy a dedicated packet inspection solution.',
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required AsyncValue<Map<String, dynamic>> asyncValue,
    required String emptyText,
    required String note,
    required Widget Function(Map<String, dynamic> data) itemBuilder,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            asyncValue.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: Colors.orange.shade700, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    'This data is not available from RouterOS.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.orange.shade700),
                  ),
                  const SizedBox(height: 4),
                  Text(note, style: theme.textTheme.bodySmall),
                ],
              ),
              data: (data) {
                final list = data['data'] as List<dynamic>? ?? [];
                if (list.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(emptyText, style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(note, style: theme.textTheme.bodySmall),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Showing ${list.length > 50 ? '50 of ' : ''}${list.length} entries', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    itemBuilder(data),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
