import 'package:flutter/material.dart';
import '../../../../data/models/network_map_models.dart';
import 'map_kinds.dart';

enum MapSort { name, ip, kind, place, status }

int compareDevices(MapDevice a, MapDevice b, MapSort sort) {
  int natural(String x, String y) => _natural(x, y);
  return switch (sort) {
    MapSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    MapSort.ip => natural(a.ip.isEmpty ? '~' : a.ip, b.ip.isEmpty ? '~' : b.ip),
    MapSort.kind => kindStyle(a.kind).label.compareTo(kindStyle(b.kind).label),
    MapSort.place => (whereLabel(a).isEmpty ? '~' : whereLabel(a).toLowerCase()).compareTo(whereLabel(b).isEmpty ? '~' : whereLabel(b).toLowerCase()),
    MapSort.status => (b.online ? 1 : 0).compareTo(a.online ? 1 : 0),
  };
}

/// "172.16.0.9" before "172.16.0.10".
int _natural(String a, String b) {
  final pa = RegExp(r'\d+|\D+').allMatches(a).map((m) => m.group(0)!).toList();
  final pb = RegExp(r'\d+|\D+').allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

/// Every device in a table: name, type, IP, MAC, place and status, sortable, with
/// tick boxes to set the place of several devices at once.
class MapDeviceList extends StatelessWidget {
  const MapDeviceList({
    super.key,
    required this.devices,
    required this.sort,
    required this.ascending,
    required this.onSort,
    required this.checked,
    required this.onCheck,
    required this.onCheckAll,
    required this.openedId,
    required this.onOpen,
  });

  final List<MapDevice> devices;
  final MapSort sort;
  final bool ascending;
  final ValueChanged<MapSort> onSort;
  final Set<String> checked; // MAC addresses
  final void Function(MapDevice device, bool value) onCheck;
  final ValueChanged<bool> onCheckAll;
  final String? openedId;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = devices.where((d) => d.editable).toList();
    final allChecked = editable.isNotEmpty && editable.every((d) => checked.contains(d.mac));
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        return Column(
          children: [
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      tristate: true,
                      value: allChecked ? true : (checked.isEmpty ? false : null),
                      onChanged: editable.isEmpty ? null : (v) => onCheckAll(v ?? false),
                    ),
                  ),
                  const SizedBox(width: 34),
                  _Head('Name', MapSort.name, sort, ascending, onSort, flex: 5),
                  if (wide) _Head('Type', MapSort.kind, sort, ascending, onSort, flex: 3),
                  _Head('IP address', MapSort.ip, sort, ascending, onSort, flex: 3),
                  if (wide) Expanded(flex: 4, child: Text('MAC address', style: theme.textTheme.labelMedium)),
                  _Head('Place', MapSort.place, sort, ascending, onSort, flex: 4),
                  _Head('Status', MapSort.status, sort, ascending, onSort, flex: 2),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: devices.length,
                itemExtent: 52,
                itemBuilder: (context, i) {
                  final d = devices[i];
                  final style = kindStyle(d.kind);
                  final where = whereLabel(d);
                  final opened = openedId == d.id;
                  return InkWell(
                    onTap: () => onOpen(d.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: opened ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4) : null,
                        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Checkbox(value: checked.contains(d.mac) && d.editable, onChanged: d.editable ? (v) => onCheck(d, v ?? false) : null),
                          ),
                          SizedBox(width: 34, child: Icon(style.icon, size: 20, color: style.color)),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                  if (!wide) Text(style.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ),
                          if (wide) Expanded(flex: 3, child: Text(style.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          Expanded(flex: 3, child: Text(d.ip.isEmpty ? '—' : d.ip, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          if (wide) Expanded(flex: 4, child: Text(d.mac, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)),
                          Expanded(
                            flex: 4,
                            child: Text(
                              where.isEmpty ? 'Not set' : where,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: d.hasPlace ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(d))),
                                const SizedBox(width: 6),
                                Flexible(child: Text(statusLabel(d), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.label, this.sort, this.current, this.ascending, this.onSort, {required this.flex});
  final String label;
  final MapSort sort;
  final MapSort current;
  final bool ascending;
  final ValueChanged<MapSort> onSort;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = sort == current;
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => onSort(sort),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(fontWeight: active ? FontWeight.w700 : null))),
              if (active) Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
