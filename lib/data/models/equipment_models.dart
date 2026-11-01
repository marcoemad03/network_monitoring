import '../../core/enums/device_status.dart';
import '../../core/enums/device_type.dart';

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// A registered device (switch, server, medical device...) with the outcome of
/// its latest ping. Ping is the one thing measured for every device.
class EquipmentItem {
  final String id;
  final String name;
  final String ipAddress;
  final DeviceType type;
  final DeviceStatus status;
  final String vendor;
  final String model;
  final String location;
  final bool isCritical;
  final bool isPinned;
  final bool isMonitored;
  final DateTime? lastSeen;
  final double? pingAvgMs;
  final double? pingLossPercent;
  final DateTime? pingAt;

  const EquipmentItem({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.type,
    required this.status,
    this.vendor = '',
    this.model = '',
    this.location = '',
    this.isCritical = false,
    this.isPinned = false,
    this.isMonitored = true,
    this.lastSeen,
    this.pingAvgMs,
    this.pingLossPercent,
    this.pingAt,
  });

  /// True when the device needs someone to look at it.
  bool get needsAttention => isMonitored && (status == DeviceStatus.offline || status == DeviceStatus.degraded);

  factory EquipmentItem.fromJson(Map<String, dynamic> j) => EquipmentItem(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        ipAddress: j['ip_address'] as String? ?? '',
        type: DeviceType.fromValue(j['device_type'] as String? ?? ''),
        status: DeviceStatus.fromValue(j['status'] as String? ?? ''),
        vendor: j['vendor'] as String? ?? '',
        model: j['model'] as String? ?? '',
        location: j['location'] as String? ?? '',
        isCritical: j['is_critical'] as bool? ?? false,
        isPinned: j['is_pinned'] as bool? ?? false,
        isMonitored: j['is_monitored'] as bool? ?? true,
        lastSeen: _date(j['last_seen']),
        pingAvgMs: (j['ping_avg_ms'] as num?)?.toDouble(),
        pingLossPercent: (j['ping_loss_percent'] as num?)?.toDouble(),
        pingAt: _date(j['ping_at']),
      );
}
