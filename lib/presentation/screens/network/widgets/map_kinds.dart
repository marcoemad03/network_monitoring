import 'package:flutter/material.dart';
import '../../../../data/models/network_map_models.dart';

/// How a kind of device is drawn and named on the map.
class KindStyle {
  final IconData icon;
  final String label;
  final Color color;
  const KindStyle(this.icon, this.label, this.color);
}

/// Kinds in the order the filter lists them.
const mapKindOrder = <String>[
  'router',
  'firewall',
  'switch',
  'access_point',
  'network',
  'server',
  'medical',
  'computer',
  'printer',
  'phone',
  'tablet',
  'camera',
  'tv',
  'iot',
  'unknown',
];

KindStyle kindStyle(String kind) => switch (kind) {
  'router' => const KindStyle(Icons.router, 'Router', Color(0xFF1565C0)),
  'firewall' => const KindStyle(Icons.shield, 'Firewall', Color(0xFFC62828)),
  'switch' => const KindStyle(Icons.lan, 'Switch', Color(0xFF00897B)),
  'access_point' => const KindStyle(Icons.wifi, 'Access point', Color(0xFF4A148C)),
  'network' => const KindStyle(Icons.hub, 'Network equipment', Color(0xFF00695C)),
  'server' => const KindStyle(Icons.dns, 'Server', Color(0xFFE65100)),
  'medical' => const KindStyle(Icons.medical_services, 'Medical device', Color(0xFFC51162)),
  'computer' => const KindStyle(Icons.desktop_windows, 'Computer', Color(0xFF6A1B9A)),
  'printer' => const KindStyle(Icons.print, 'Printer', Color(0xFF283593)),
  'phone' => const KindStyle(Icons.smartphone, 'Phone', Color(0xFF2E7D32)),
  'tablet' => const KindStyle(Icons.tablet_mac, 'Tablet', Color(0xFF558B2F)),
  'camera' => const KindStyle(Icons.videocam, 'Camera', Color(0xFF37474F)),
  'tv' => const KindStyle(Icons.tv, 'TV', Color(0xFF5D4037)),
  'iot' => const KindStyle(Icons.sensors, 'Smart device', Color(0xFFF57F17)),
  _ => const KindStyle(Icons.device_unknown, 'Unknown', Color(0xFF78909C)),
};

/// Green for online, amber for degraded, red for a registered device that is down,
/// grey for a device that is simply not here right now.
Color statusColor(MapDevice d) {
  if (d.online && d.status == 'degraded') return const Color(0xFFF9A825);
  if (d.online) return const Color(0xFF2E7D32);
  if (d.source == 'equipment') return const Color(0xFFC62828);
  return const Color(0xFF9E9E9E);
}

String statusLabel(MapDevice d) {
  if (d.online && d.status == 'degraded') return 'Degraded';
  if (d.online) return 'Online';
  if (d.source == 'equipment') return 'Down';
  return 'Offline';
}

/// "Where": the place, else the port, else a plain "not set".
String whereLabel(MapDevice d) {
  if (d.hasPlace) return d.place;
  if (d.port.isNotEmpty) return d.port;
  return '';
}

String formatBps(int bps) {
  if (bps >= 1000000000) return '${(bps / 1e9).toStringAsFixed(1)} Gbps';
  if (bps >= 1000000) return '${(bps / 1e6).toStringAsFixed(1)} Mbps';
  if (bps >= 1000) return '${(bps / 1e3).toStringAsFixed(0)} kbps';
  return '$bps bps';
}

String formatBytes(int bytes) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
}

String agoLabel(DateTime? t) {
  if (t == null) return 'never';
  final s = DateTime.now().difference(t).inSeconds;
  if (s < 10) return 'just now';
  if (s < 60) return '${s}s ago';
  if (s < 3600) return '${s ~/ 60} min ago';
  if (s < 86400) return '${s ~/ 3600} h ago';
  return '${s ~/ 86400} d ago';
}
