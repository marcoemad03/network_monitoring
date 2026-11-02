import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/marco_models.dart';
import '../../../../data/models/network_map_models.dart';
import '../../../providers/marco/marco_details_provider.dart';
import '../../../providers/network/network_map_provider.dart';
import '../../network/widgets/map_kinds.dart';
import 'marco_style.dart';

final _macPattern = RegExp(r'^([0-9A-F]{2}:){5}[0-9A-F]{2}$');

/// Pick the devices to put in a group from everything the router sees. Returns the
/// MAC addresses chosen, or null when cancelled.
Future<List<String>?> showAddDevicesDialog(BuildContext context, {required MarcoGroup group}) {
  return showDialog<List<String>>(context: context, builder: (_) => AddDevicesDialog(group: group));
}

class AddDevicesDialog extends ConsumerStatefulWidget {
  const AddDevicesDialog({super.key, required this.group});
  final MarcoGroup group;

  @override
  ConsumerState<AddDevicesDialog> createState() => _AddDevicesDialogState();
}

class _AddDevicesDialogState extends ConsumerState<AddDevicesDialog> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _manual = TextEditingController();
  final Set<String> _selected = {};
  final Set<String> _kinds = {};
  bool _onlineOnly = true;
  bool _ungroupedOnly = false;
  String _query = '';
  String? _manualError;

  @override
  void dispose() {
    _search.dispose();
    _manual.dispose();
    super.dispose();
  }

  bool _matches(MapDevice d, Map<String, MarcoGroup> groups) {
    if (!d.editable || d.source == 'router') return false;
    if (_onlineOnly && !d.online) return false;
    if (_kinds.isNotEmpty && !_kinds.contains(d.kind)) return false;
    final g = groups[d.mac.toUpperCase()];
    if (_ungroupedOnly && g != null) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [d.name, d.ip, d.mac, d.place, d.vendor, d.brand, kindStyle(d.kind).label].join(' ').toLowerCase().contains(q);
  }

  void _addManual() {
    final mac = _manual.text.trim().toUpperCase().replaceAll('-', ':');
    if (!_macPattern.hasMatch(mac)) {
      setState(() => _manualError = 'Use the form AA:BB:CC:DD:EE:FF');
      return;
    }
    setState(() {
      _selected.add(mac);
      _manual.clear();
      _manualError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = ref.watch(networkMapProvider);
    final data = map.data;
    final groups = ref.watch(marcoGroupByMacMapProvider);
    final visible = data == null ? <MapDevice>[] : data.devices.where((d) => _matches(d, groups)).toList();
    final here = {for (final m in widget.group.members) (m.macAddress ?? '').toUpperCase()};
    final moving = _selected.where((m) => groups[m] != null && groups[m]!.id != widget.group.id).length;
    final kindsPresent = data == null ? <String>[] : [for (final k in mapKindOrder) if ((data.summary.byKind[k] ?? 0) > 0) k];
    final size = MediaQuery.sizeOf(context);

    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(radius: 14, backgroundColor: marcoColor(widget.group.color), child: Icon(marcoIcon(widget.group.icon), size: 16, color: Colors.white)),
          const SizedBox(width: 10),
          Expanded(child: Text('Add devices to ${widget.group.name}', overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: (size.height * 0.68).clamp(360.0, 640.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: 'Search by name, IP, MAC, place or type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                FilterChip(label: const Text('Online now'), selected: _onlineOnly, onSelected: (v) => setState(() => _onlineOnly = v), visualDensity: VisualDensity.compact),
                FilterChip(label: const Text('Not in a group'), selected: _ungroupedOnly, onSelected: (v) => setState(() => _ungroupedOnly = v), visualDensity: VisualDensity.compact),
                for (final k in kindsPresent)
                  FilterChip(
                    avatar: Icon(kindStyle(k).icon, size: 16, color: kindStyle(k).color),
                    label: Text(kindStyle(k).label),
                    selected: _kinds.contains(k),
                    onSelected: (on) => setState(() => on ? _kinds.add(k) : _kinds.remove(k)),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${visible.length} shown · ${_selected.length} selected', style: theme.textTheme.labelMedium),
                const Spacer(),
                TextButton(
                  onPressed: visible.isEmpty
                      ? null
                      : () => setState(() {
                            for (final d in visible) {
                              if (!here.contains(d.mac.toUpperCase())) _selected.add(d.mac.toUpperCase());
                            }
                          }),
                  child: const Text('Select all shown'),
                ),
                TextButton(onPressed: _selected.isEmpty ? null : () => setState(_selected.clear), child: const Text('Clear')),
              ],
            ),
            const Divider(height: 1),
            Expanded(child: _body(theme, map, data, visible, groups, here)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Add by MAC address'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manual,
                        decoration: InputDecoration(isDense: true, hintText: 'AA:BB:CC:DD:EE:FF', errorText: _manualError, border: const OutlineInputBorder()),
                        onSubmitted: (_) => _addManual(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(onPressed: _addManual, child: const Text('Add')),
                  ],
                ),
              ],
            ),
            if (moving > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, size: 16, color: theme.colorScheme.tertiary),
                    const SizedBox(width: 6),
                    Expanded(child: Text('$moving device${moving == 1 ? '' : 's'} will leave ${moving == 1 ? 'its' : 'their'} current group. A device can be in one group.', style: theme.textTheme.bodySmall)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()..sort()),
          icon: const Icon(Icons.add),
          label: Text(_selected.isEmpty ? 'Add devices' : 'Add ${_selected.length} device${_selected.length == 1 ? '' : 's'}'),
        ),
      ],
    );
  }

  Widget _body(ThemeData theme, NetworkMapState map, NetworkMapData? data, List<MapDevice> visible, Map<String, MarcoGroup> groups, Set<String> here) {
    if (data == null) {
      if (map.loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('${map.fetchError ?? 'The device list could not be loaded.'} You can still add a device by its MAC address below.', textAlign: TextAlign.center),
        ),
      );
    }
    if (visible.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(data.devices.isEmpty ? 'The router has not reported any device yet.' : 'No device matches. Change the search or the filters.', textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      itemCount: visible.length,
      itemExtent: 60,
      itemBuilder: (context, i) {
        final d = visible[i];
        final mac = d.mac.toUpperCase();
        final style = kindStyle(d.kind);
        final current = groups[mac];
        final already = here.contains(mac);
        final checked = already || _selected.contains(mac);
        return InkWell(
          key: ValueKey(mac),
          onTap: already ? null : () => setState(() => _selected.contains(mac) ? _selected.remove(mac) : _selected.add(mac)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Checkbox(value: checked, onChanged: already ? null : (v) => setState(() => v == true ? _selected.add(mac) : _selected.remove(mac))),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: style.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
                  child: Icon(style.icon, size: 19, color: style.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                          const SizedBox(width: 6),
                          Tooltip(message: statusLabel(d), child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor(d)))),
                        ],
                      ),
                      Text(
                        [if (d.ip.isNotEmpty) d.ip, style.label, if (d.hasPlace) d.place].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (already)
                  Text('In this group', style: theme.textTheme.labelMedium)
                else if (current != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: CircleAvatar(radius: 5, backgroundColor: marcoColor(current.color)),
                    label: Text(current.name, overflow: TextOverflow.ellipsis),
                  )
                else
                  Text('No group', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(width: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
