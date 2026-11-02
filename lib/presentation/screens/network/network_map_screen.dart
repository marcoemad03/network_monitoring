import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/network_map_models.dart';
import '../../providers/marco/marco_details_provider.dart';
import '../../providers/network/network_map_provider.dart';
import '../marco/widgets/device_control_dialog.dart';
import '../dashboard/widgets/dash_card.dart';
import 'widgets/map_canvas.dart';
import 'widgets/map_detail.dart';
import 'widgets/map_dialogs.dart';
import 'widgets/map_kinds.dart';
import 'widgets/map_list.dart';

enum _View { map, list }

/// Every device on the network: its name, type, address and place, drawn behind the
/// router port it is connected to. Data comes from the NMS server, which reads the
/// router with print commands only.
class NetworkMapScreen extends ConsumerStatefulWidget {
  const NetworkMapScreen({super.key});

  @override
  ConsumerState<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends ConsumerState<NetworkMapScreen> {
  final GlobalKey<MapCanvasState> _canvas = GlobalKey();
  final TextEditingController _search = TextEditingController();
  _View _view = _View.map;
  String _query = '';
  final Set<String> _kinds = {};
  bool _showOffline = false;
  bool _onlyUnplaced = false;
  String? _selectedId;
  final Set<String> _checked = {};
  MapSort _sort = MapSort.ip;
  bool _ascending = true;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MapDevice> _filter(NetworkMapData data) {
    final q = _query.trim().toLowerCase();
    return data.devices.where((d) {
      if (!_showOffline && !d.online) return false;
      if (_kinds.isNotEmpty && !_kinds.contains(d.kind)) return false;
      if (_onlyUnplaced && d.hasPlace) return false;
      if (q.isEmpty) return true;
      final hay = [d.name, d.ip, d.mac, d.place, d.port, d.hostname, d.brand, d.vendor, d.model, kindStyle(d.kind).label].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  List<String> _knownPlaces(NetworkMapData data) =>
      ({for (final d in data.devices) if (d.placeSource == PlaceSource.custom) d.place}.toList()..sort());

  Future<void> _edit(MapDevice d, NetworkMapData data) async {
    final edit = await showEditDeviceDialog(context, d, _knownPlaces(data));
    if (edit == null || !mounted) return;
    if (edit.name == null && edit.kind == null && edit.place == null) return;
    await runSave(context, () => ref.read(networkMapProvider.notifier).saveDevice(d.mac, displayName: edit.name, kind: edit.kind, place: edit.place));
  }

  String? _controlText(MapDevice d) {
    final c = ref.read(marcoOverridesProvider).valueOrNull?[d.mac.toUpperCase()];
    if (c == null) return null;
    if (c.blocked) return 'Internet blocked';
    if (c.limited) return 'Speed limited to ${c.downloadMbps ?? '–'} down / ${c.uploadMbps ?? '–'} up Mbps';
    return null;
  }

  Future<void> _control(MapDevice d) async {
    final c = ref.read(marcoOverridesProvider).valueOrNull?[d.mac.toUpperCase()];
    await showDeviceControlDialog(context, mac: d.mac, name: d.name, ip: d.ip, control: c);
    ref.invalidate(marcoOverridesProvider);
  }

  Future<void> _setPlaceForChecked(NetworkMapData data) async {
    final place = await showSetPlaceDialog(context, _checked.length, _knownPlaces(data));
    if (place == null || !mounted) return;
    final macs = _checked.toList();
    final ok = await runSave(context, () async {
      await ref.read(networkMapProvider.notifier).saveDevicePlaces(macs, place);
    }, done: place.isEmpty ? 'Place removed from ${macs.length} devices' : 'Place saved for ${macs.length} devices');
    if (ok && mounted) setState(_checked.clear);
  }

  Future<void> _namePort(MapPort port) async {
    final label = await showPortLabelDialog(context, port);
    if (label == null || !mounted) return;
    await runSave(context, () => ref.read(networkMapProvider.notifier).savePortLabel(port.name, label));
  }

  void _select(String? id, NetworkMapData data, bool sideBySide) {
    setState(() => _selectedId = id);
    if (id == null || sideBySide) return;
    final d = data.devices.where((x) => x.id == id).firstOrNull;
    if (d == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
          child: DeviceDetailPanel(
            device: d,
            port: data.port(d.port),
            onClose: () => Navigator.pop(ctx),
            groupName: ref.read(marcoGroupByMacMapProvider)[d.mac.toUpperCase()]?.name,
            controlText: _controlText(d),
            onControl: d.editable
                ? () {
                    Navigator.pop(ctx);
                    _control(d);
                  }
                : null,
            onEdit: d.editable
                ? () {
                    Navigator.pop(ctx);
                    _edit(d, data);
                  }
                : null,
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(networkMapProvider);
    final data = state.data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Map'),
        actions: [
          if (_view == _View.map) ...[
            IconButton(tooltip: 'Zoom in', icon: const Icon(Icons.zoom_in), onPressed: () => _canvas.currentState?.zoomBy(1.25)),
            IconButton(tooltip: 'Zoom out', icon: const Icon(Icons.zoom_out), onPressed: () => _canvas.currentState?.zoomBy(0.8)),
            IconButton(tooltip: 'Fit to screen', icon: const Icon(Icons.fit_screen), onPressed: () => _canvas.currentState?.fit()),
          ],
          IconButton(
            tooltip: 'Read the router again',
            icon: state.loading && data != null
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: () => ref.read(networkMapProvider.notifier).refresh(force: true),
          ),
        ],
      ),
      body: data == null ? _empty(state) : _content(state, data),
    );
  }

  Widget _empty(NetworkMapState state) {
    if (state.loading) {
      return const Padding(padding: EdgeInsets.all(24), child: Column(children: [SkeletonBox(height: 48), SizedBox(height: 12), SkeletonBox(height: 320)]));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EmptyNotice(icon: Icons.cloud_off, title: state.fetchError ?? 'Could not load the network map.', detail: 'Check that the NMS server is running.'),
          const SizedBox(height: 8),
          FilledButton.icon(onPressed: () => ref.read(networkMapProvider.notifier).refresh(force: true), icon: const Icon(Icons.refresh), label: const Text('Try again')),
        ],
      ),
    );
  }

  Widget _content(NetworkMapState state, NetworkMapData data) {
    // Watched here so the panel updates when a group or a control changes.
    ref.watch(marcoOverridesProvider);
    final groups = ref.watch(marcoGroupByMacMapProvider);
    final shown = _filter(data);
    final sideBySide = MediaQuery.sizeOf(context).width >= 1000;
    final selected = data.devices.where((d) => d.id == _selectedId).firstOrNull;
    final sorted = [...shown]..sort((a, b) => _ascending ? compareDevices(a, b, _sort) : compareDevices(b, a, _sort));

    return Column(
      children: [
        _Banners(state: state, data: data),
        _SummaryStrip(summary: data.summary, shown: shown.length),
        _Toolbar(
          controller: _search,
          onQuery: (v) => setState(() => _query = v),
          kindsPresent: [for (final k in mapKindOrder) if ((data.summary.byKind[k] ?? 0) > 0) k],
          kindCounts: data.summary.byKind,
          selectedKinds: _kinds,
          onKind: (k, on) => setState(() => on ? _kinds.add(k) : _kinds.remove(k)),
          showOffline: _showOffline,
          offlineCount: data.summary.offline,
          onOffline: (v) => setState(() => _showOffline = v),
          onlyUnplaced: _onlyUnplaced,
          onUnplaced: (v) => setState(() => _onlyUnplaced = v),
          view: _view,
          onView: (v) => setState(() => _view = v),
        ),
        _PortsStrip(ports: data.ports.where((p) => p.physical || p.devices > 0).toList(), onTap: _namePort),
        if (_checked.isNotEmpty)
          Container(
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Text('${_checked.length} selected'),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(onPressed: () => _setPlaceForChecked(data), icon: const Icon(Icons.place_outlined, size: 18), label: const Text('Set place')),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(_checked.clear), child: const Text('Clear')),
              ],
            ),
          ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: shown.isEmpty
                    ? Center(child: EmptyNotice(icon: Icons.search_off, title: 'No device matches', detail: data.devices.isEmpty ? 'The router has not reported any device yet.' : 'Change the search or the filters.'))
                    : (_view == _View.map
                        ? MapCanvas(
                            key: _canvas,
                            data: data,
                            devices: shown,
                            selectedId: _selectedId,
                            onSelect: (id) => _select(id, data, sideBySide),
                            onPortTap: (name) {
                              final p = data.port(name);
                              if (p != null) _namePort(p);
                            },
                          )
                        : MapDeviceList(
                            devices: sorted,
                            sort: _sort,
                            ascending: _ascending,
                            onSort: (s) => setState(() {
                              if (_sort == s) {
                                _ascending = !_ascending;
                              } else {
                                _sort = s;
                                _ascending = true;
                              }
                            }),
                            checked: _checked,
                            onCheck: (d, v) => setState(() => v ? _checked.add(d.mac) : _checked.remove(d.mac)),
                            onCheckAll: (v) => setState(() {
                              if (v) {
                                _checked.addAll(sorted.where((d) => d.editable).map((d) => d.mac));
                              } else {
                                _checked.clear();
                              }
                            }),
                            openedId: _selectedId,
                            onOpen: (id) => _select(id, data, sideBySide),
                          )),
              ),
              if (sideBySide && selected != null)
                SizedBox(
                  width: 380,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
                    child: DeviceDetailPanel(
                      device: selected,
                      port: data.port(selected.port),
                      onClose: () => setState(() => _selectedId = null),
                      groupName: groups[selected.mac.toUpperCase()]?.name,
                      controlText: _controlText(selected),
                      onControl: selected.editable ? () => _control(selected) : null,
                      onEdit: selected.editable ? () => _edit(selected, data) : null,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Says when the picture is old or part of it could not be read.
class _Banners extends StatelessWidget {
  const _Banners({required this.state, required this.data});
  final NetworkMapState state;
  final NetworkMapData data;

  @override
  Widget build(BuildContext context) {
    final messages = <(IconData, String)>[
      if (state.fetchError != null) (Icons.cloud_off, '${state.fetchError} Showing the last map from ${agoLabel(state.fetchedAt)}.'),
      if (data.error != null) (Icons.router, 'Router: ${data.error}'),
      if (data.stale && data.error == null) (Icons.schedule, 'The device list is old (updated ${agoLabel(data.updatedAt)}).'),
      if (data.topologyError != null)
        (Icons.settings_ethernet, 'Ports could not be read (${data.topologyError}). Devices are placed from what was last known.')
      else if (data.topologyNotes.isNotEmpty)
        (Icons.info_outline, 'Not available on this router: ${data.topologyNotes.join(', ')}.'),
    ];
    if (messages.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in messages)
            Row(children: [Icon(m.$1, size: 16), const SizedBox(width: 8), Expanded(child: Text(m.$2, style: theme.textTheme.bodySmall))]),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary, required this.shown});
  final MapSummary summary;
  final int shown;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          StatusPill(tone: StatusTone.neutral, label: '${summary.total} devices'),
          StatusPill(tone: StatusTone.ok, label: '${summary.online} online'),
          if (summary.offline > 0) StatusPill(tone: StatusTone.neutral, label: '${summary.offline} offline'),
          StatusPill(
            tone: summary.unplaced == 0 ? StatusTone.ok : StatusTone.warning,
            label: '${summary.located} with a place · ${summary.unplaced} without',
            tooltip: 'A place is a name you give a device or port, like "Laboratory". Many devices share one router port, so the port alone does not say where each one is.',
          ),
          if (summary.unnamed > 0) StatusPill(tone: StatusTone.warning, label: '${summary.unnamed} without a name', tooltip: 'These devices do not report a name. Give them one so they are easy to recognise.'),
          if (shown != summary.total) StatusPill(tone: StatusTone.neutral, label: 'Showing $shown'),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.onQuery,
    required this.kindsPresent,
    required this.kindCounts,
    required this.selectedKinds,
    required this.onKind,
    required this.showOffline,
    required this.offlineCount,
    required this.onOffline,
    required this.onlyUnplaced,
    required this.onUnplaced,
    required this.view,
    required this.onView,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQuery;
  final List<String> kindsPresent;
  final Map<String, int> kindCounts;
  final Set<String> selectedKinds;
  final void Function(String kind, bool on) onKind;
  final bool showOffline;
  final int offlineCount;
  final ValueChanged<bool> onOffline;
  final bool onlyUnplaced;
  final ValueChanged<bool> onUnplaced;
  final _View view;
  final ValueChanged<_View> onView;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: controller,
                    onChanged: onQuery,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      hintText: 'Search by name, IP, MAC, place or type',
                      border: const OutlineInputBorder(),
                      suffixIcon: controller.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                controller.clear();
                                onQuery('');
                              },
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<_View>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _View.map, icon: Icon(Icons.account_tree_outlined, size: 18), label: Text('Map')),
                  ButtonSegment(value: _View.list, icon: Icon(Icons.table_rows_outlined, size: 18), label: Text('List')),
                ],
                selected: {view},
                onSelectionChanged: (s) => onView(s.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final k in kindsPresent)
                FilterChip(
                  avatar: Icon(kindStyle(k).icon, size: 16, color: kindStyle(k).color),
                  label: Text('${kindStyle(k).label} ${kindCounts[k]}'),
                  selected: selectedKinds.contains(k),
                  onSelected: (on) => onKind(k, on),
                  visualDensity: VisualDensity.compact,
                ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text('Offline ($offlineCount)'),
                selected: showOffline,
                onSelected: onOffline,
                visualDensity: VisualDensity.compact,
              ),
              FilterChip(label: const Text('No place yet'), selected: onlyUnplaced, onSelected: onUnplaced, visualDensity: VisualDensity.compact),
            ],
          ),
        ],
      ),
    );
  }
}

/// The router's ports at a glance. Tapping one lets you name it.
class _PortsStrip extends StatelessWidget {
  const _PortsStrip({required this.ports, required this.onTap});
  final List<MapPort> ports;
  final ValueChanged<MapPort> onTap;

  @override
  Widget build(BuildContext context) {
    if (ports.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final p in ports)
            Padding(
              padding: const EdgeInsets.only(right: 6, bottom: 6),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.circle, size: 10, color: p.running ? const Color(0xFF2E7D32) : theme.colorScheme.outline),
                label: Text(p.devices > 0 ? '${p.title} · ${p.devices}' : p.title),
                tooltip: p.running ? 'Port is up. Tap to name it.' : 'No cable connected. Tap to name it.',
                onPressed: () => onTap(p),
              ),
            ),
        ],
      ),
    );
  }
}
