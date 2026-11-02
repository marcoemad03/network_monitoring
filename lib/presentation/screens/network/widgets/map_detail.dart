import 'package:flutter/material.dart';
import '../../../../data/models/network_map_models.dart';
import 'map_kinds.dart';

/// Everything known about the selected device, with a button to name it and say
/// where it is.
class DeviceDetailPanel extends StatelessWidget {
  const DeviceDetailPanel({super.key, required this.device, required this.port, required this.onClose, required this.onEdit, this.onControl, this.groupName, this.controlText});

  final MapDevice device;
  final MapPort? port;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  /// Opens the block / speed limit dialog; null when the device cannot be controlled.
  final VoidCallback? onControl;
  final String? groupName;

  /// What is set on the device now, for example 'Internet blocked'.
  final String? controlText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = kindStyle(device.kind);
    final dot = statusColor(device);
    final portText = device.port.isEmpty
        ? 'Not found on the router'
        : [
            device.port,
            if (port != null && port!.label.isNotEmpty) '(${port!.label})',
            if (port != null && port!.trunk) '· leads to another switch',
          ].join(' ');
    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                  child: Icon(style.icon, color: style.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: dot)),
                          const SizedBox(width: 6),
                          Text('${style.label} · ${statusLabel(device)}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Close', icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            const SizedBox(height: 12),
            if (onEdit != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 18), label: const Text('Name it / set place')),
                  if (onControl != null) OutlinedButton.icon(onPressed: onControl, icon: const Icon(Icons.speed, size: 18), label: const Text('Block or limit speed')),
                ],
              )
            else
              Text('Registered equipment: change it from the Equipment page.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const Divider(height: 28),
            _Row('IP address', device.ip.isEmpty ? '—' : device.ip),
            _Row('MAC address', device.mac.isEmpty ? '—' : device.mac),
            if (device.hostname.isNotEmpty) _Row('Hostname', device.hostname),
            _Row('Type', device.kindCustom ? '${style.label} (set by you)' : '${style.label}${device.kindReason.isEmpty ? '' : ' — ${device.kindReason}'}'),
            if (device.brand.isNotEmpty || device.vendor.isNotEmpty || device.model.isNotEmpty)
              _Row('Make', [device.brand, device.vendor, device.model].where((s) => s.isNotEmpty).toSet().join(' · ')),
            const Divider(height: 28),
            _Row('Place', device.hasPlace ? '${device.place}${_placeNote(device.placeSource)}' : 'Not set'),
            _Row('Router port', portText),
            if (groupName != null) _Row('Group', groupName!),
            if (controlText != null) _Row('Control', controlText!),
            if (device.wifi != null) _Row('Wi-Fi', [device.wifi!.interfaceName, device.wifi!.ssid, device.wifi!.signal].where((s) => s.isNotEmpty).join(' · ')),
            if (device.network.isNotEmpty) _Row('Network', device.network),
            const Divider(height: 28),
            if (device.online && (device.downloadBps > 0 || device.uploadBps > 0)) _Row('Speed now', '↓ ${formatBps(device.downloadBps)}  ↑ ${formatBps(device.uploadBps)}'),
            if (device.todayBytes > 0) _Row('Used today', formatBytes(device.todayBytes)),
            if (device.pingMs != null) _Row('Ping', '${device.pingMs!.toStringAsFixed(1)} ms'),
            _Row('Last seen', device.online ? 'Now' : agoLabel(device.lastSeen)),
            if (device.critical) const _Row('Registered as', 'Critical equipment'),
            if (device.note.isNotEmpty) _Row('Comment', device.note),
          ],
        ),
      ),
    );
  }

  String _placeNote(PlaceSource s) => switch (s) {
    PlaceSource.custom => ' (set by you)',
    PlaceSource.portLabel => ' (name of its port)',
    PlaceSource.portComment => ' (router port comment)',
    PlaceSource.port => ' (router port)',
    PlaceSource.registered => ' (registered location)',
    PlaceSource.none => '',
  };
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
