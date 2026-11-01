import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../../data/models/equipment_models.dart';

/// Which equipment to list by its state.
enum EquipmentStateFilter {
  all('All'),
  online('Online'),
  attention('Needs attention'),
  maintenance('Maintenance');

  const EquipmentStateFilter(this.label);
  final String label;
}

bool matchesState(EquipmentItem e, EquipmentStateFilter f) => switch (f) {
      EquipmentStateFilter.all => true,
      EquipmentStateFilter.online => e.status == DeviceStatus.online,
      EquipmentStateFilter.attention => e.needsAttention,
      EquipmentStateFilter.maintenance => e.status == DeviceStatus.maintenance,
    };

/// Filters and orders the equipment: what needs attention first (critical
/// devices before the rest), then pinned ones, then by name.
List<EquipmentItem> applyEquipmentFilters(
  List<EquipmentItem> all, {
  String query = '',
  DeviceType? type,
  EquipmentStateFilter state = EquipmentStateFilter.all,
}) {
  final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  final result = all.where((e) {
    if (type != null && e.type != type) return false;
    if (!matchesState(e, state)) return false;
    if (terms.isEmpty) return true;
    final haystack = [e.name, e.ipAddress, e.vendor, e.model, e.location, e.type.label].join(' ').toLowerCase();
    return terms.every(haystack.contains);
  }).toList();

  int rank(EquipmentItem e) {
    if (e.needsAttention) return e.isCritical ? 0 : 1;
    if (e.isPinned) return 2;
    return 3;
  }

  result.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return result;
}

/// How many devices of each type, biggest first.
List<MapEntry<DeviceType, int>> equipmentTypeCounts(List<EquipmentItem> all) {
  final counts = <DeviceType, int>{};
  for (final e in all) {
    counts[e.type] = (counts[e.type] ?? 0) + 1;
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
