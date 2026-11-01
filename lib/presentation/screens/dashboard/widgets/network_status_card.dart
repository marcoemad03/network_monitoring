import 'package:flutter/material.dart';

import '../../../../domain/entities/dashboard_live.dart';
import 'dash_card.dart';

/// Devices, clients and alerts as recorded by the NMS. Each tile opens the
/// screen that explains the number.
class NetworkStatusCard extends StatelessWidget {
  const NetworkStatusCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.error,
    required this.onDevices,
    required this.onClients,
    required this.onAlerts,
  });

  final DashboardLive? summary;
  final bool loading;
  final String? error;
  final VoidCallback onDevices;
  final VoidCallback onClients;
  final VoidCallback onAlerts;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return DashCard(
      title: 'Network',
      icon: Icons.hub_outlined,
      child: s == null
          ? (loading
              ? const Column(children: [SkeletonBox(height: 44), SizedBox(height: 10), SkeletonBox(height: 44)])
              : EmptyNotice(icon: Icons.cloud_off, title: 'No data yet', detail: error))
          : Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _Tile(icon: Icons.check_circle_outline, tone: StatusTone.ok, value: s.onlineDevices, label: 'Online', onTap: onDevices)),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(icon: Icons.cancel_outlined, tone: s.offlineDevices > 0 ? StatusTone.error : StatusTone.neutral, value: s.offlineDevices, label: 'Offline', onTap: onDevices)),
                    const SizedBox(width: 10),
                    Expanded(child: _Tile(icon: Icons.warning_amber_rounded, tone: s.degradedDevices > 0 ? StatusTone.warning : StatusTone.neutral, value: s.degradedDevices, label: 'Degraded', onTap: onDevices)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _Tile(icon: Icons.devices_other, tone: StatusTone.neutral, value: s.activeClients, label: 'Active clients', onTap: onClients)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Tile(
                        icon: Icons.notifications_active_outlined,
                        tone: s.criticalAlerts > 0 ? StatusTone.error : s.openAlerts > 0 ? StatusTone.warning : StatusTone.neutral,
                        value: s.openAlerts,
                        label: s.criticalAlerts > 0 ? 'Open alerts · ${s.criticalAlerts} critical' : 'Open alerts',
                        onTap: onAlerts,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.tone, required this.value, required this.label, required this.onTap});

  final IconData icon;
  final StatusTone tone;
  final int value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = toneStyle(context, tone);
    return Semantics(
      button: true,
      label: '$value $label. Opens the list.',
      child: ExcludeSemantics(
        child: Material(
          color: style.background,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(icon, color: style.foreground, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$value', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: style.foreground)),
                          Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
