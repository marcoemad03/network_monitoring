/// Human readable units for network speeds and data volumes.
///
/// Decimal units (1 Gbps = 1000 Mbps, 1 GB = 1000 MB) are used on purpose: they
/// match how ISPs state speeds and quotas.
String formatBitrate(num bitsPerSecond) {
  final v = bitsPerSecond.toDouble();
  if (v >= 1e9) return '${_fixed(v / 1e9)} Gbps';
  if (v >= 1e6) return '${_fixed(v / 1e6)} Mbps';
  if (v >= 1e3) return '${_fixed(v / 1e3)} Kbps';
  return '${v.round()} bps';
}

/// Splits a bitrate into a value and a unit so the unit can be styled apart.
({String value, String unit}) splitBitrate(num bitsPerSecond) => _split(formatBitrate(bitsPerSecond));

String formatBytes(num bytes) {
  final v = bytes.toDouble();
  if (v >= 1e12) return '${_fixed(v / 1e12)} TB';
  if (v >= 1e9) return '${_fixed(v / 1e9)} GB';
  if (v >= 1e6) return '${_fixed(v / 1e6)} MB';
  if (v >= 1e3) return '${_fixed(v / 1e3)} KB';
  return '${v.round()} B';
}

({String value, String unit}) splitBytes(num bytes) => _split(formatBytes(bytes));

/// "6d 21h", "3h 12m", "45m", "20s".
String formatUptime(int seconds) {
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${seconds}s';
}

/// "just now", "12s ago", "3m ago", "2h ago".
String formatAge(Duration age) {
  if (age.inSeconds < 5) return 'just now';
  if (age.inSeconds < 60) return '${age.inSeconds}s ago';
  if (age.inMinutes < 60) return '${age.inMinutes}m ago';
  if (age.inHours < 48) return '${age.inHours}h ago';
  return '${age.inDays}d ago';
}

({String value, String unit}) _split(String text) {
  final i = text.indexOf(' ');
  return (value: text.substring(0, i), unit: text.substring(i + 1));
}

String _fixed(double v) {
  if (v >= 100) return v.toStringAsFixed(0);
  if (v >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}
