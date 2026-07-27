import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:go_router/go_router.dart';

import '../../../core/services/marco_state_service.dart';
import '../../../domain/entities/connected_device.dart';
import '../../../shared/extensions/datetime_extensions.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';
import '../../widgets/common/search_input.dart';

enum _ConnectedDeviceSort { name, ip, connection, upload, download, lastSeen }

const _allColumns = [
  'Name', 'Hostname', 'IP', 'MAC', 'Vendor', 'Type', 'Status',
  'LAN/WiFi', 'AP', 'Interface', 'Upload', 'Download', 'Signal',
  'Department', 'Room', 'Notes', 'Group', 'Last Seen',
];

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends ConsumerState<ConnectedDevicesScreen> {
  final _searchController = TextEditingController();
  Timer? _timer;
  String _search = '';
  String _connectionFilter = 'all';
  String _statusFilter = 'all';
  _ConnectedDeviceSort _sort = _ConnectedDeviceSort.ip;
  bool _ascending = true;
  bool _autoRefresh = true;
  int _refreshSeconds = 15;
  final Set<String> _selectedDeviceIds = <String>{};
  Set<String> _visibleColumns = {..._allColumns};

  @override
  void initState() {
    super.initState();
    _scheduleRefresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    if (!_autoRefresh) return;
    _timer = Timer.periodic(Duration(seconds: _refreshSeconds), (_) {
      if (mounted) ref.invalidate(connectedDevicesProvider);
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(connectedDevicesProvider);
    await ref.read(connectedDevicesProvider.future);
  }

  String _groupNameFor(String deviceId) {
    final profile = ref.read(marcoStateServiceProvider).profileFor(deviceId);
    if (profile?.groupId == null) return '';
    final group = ref.read(marcoStateServiceProvider).groups.where((g) => g.id == profile!.groupId).firstOrNull;
    return group?.name ?? '';
  }

  Color _groupColor(String groupName) {
    if (groupName.isEmpty) return Colors.transparent;
    final group = ref.read(marcoStateServiceProvider).groups.where((g) => g.name == groupName).firstOrNull;
    if (group == null) return Colors.grey;
    switch (group.color) {
      case 'blue': return Colors.blue;
      case 'green': return Colors.green;
      case 'orange': return Colors.orange;
      case 'red': return Colors.red;
      case 'purple': return Colors.purple;
      case 'teal': return Colors.teal;
      default: return Colors.grey;
    }
  }

  List<ConnectedDevice> _visibleDevices(List<ConnectedDevice> source) {
    final query = _search.trim().toLowerCase();
    final devices = source.where((device) {
      final matchesSearch = query.isEmpty || [
        device.deviceName, device.hostname, device.ipAddress,
        device.macAddress, device.interfaceName, device.connectedAccessPoint,
        device.vendor, device.deviceType, device.department, device.room,
      ].whereType<String>().any((value) => value.toLowerCase().contains(query));
      final matchesConnection = _connectionFilter == 'all' || device.connectionType.toLowerCase() == _connectionFilter;
      final matchesStatus = _statusFilter == 'all' || (_statusFilter == 'online' ? device.isOnline : !device.isOnline);
      return matchesSearch && matchesConnection && matchesStatus;
    }).toList();
    int compare(ConnectedDevice a, ConnectedDevice b) => switch (_sort) {
      _ConnectedDeviceSort.name => a.deviceName.toLowerCase().compareTo(b.deviceName.toLowerCase()),
      _ConnectedDeviceSort.ip => _ipNumber(a.ipAddress).compareTo(_ipNumber(b.ipAddress)),
      _ConnectedDeviceSort.connection => a.connectionType.compareTo(b.connectionType),
      _ConnectedDeviceSort.upload => (a.currentUploadMbps ?? 0).compareTo(b.currentUploadMbps ?? 0),
      _ConnectedDeviceSort.download => (a.currentDownloadMbps ?? 0).compareTo(b.currentDownloadMbps ?? 0),
      _ConnectedDeviceSort.lastSeen => a.lastSeen.compareTo(b.lastSeen),
    };
    devices.sort((a, b) => _ascending ? compare(a, b) : compare(b, a));
    return devices;
  }

  int _ipNumber(String ip) {
    final parts = ip.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return 0;
    return (parts[0]! << 24) + (parts[1]! << 16) + (parts[2]! << 8) + parts[3]!;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(liveNotificationProvider, (_, __) {});
    final state = ref.watch(connectedDevicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh RouterOS data', onPressed: _refresh),
          PopupMenuButton<int>(
            tooltip: 'Auto refresh interval',
            icon: Icon(_autoRefresh ? Icons.sync : Icons.sync_disabled),
            onSelected: (seconds) => setState(() { _refreshSeconds = seconds; _autoRefresh = true; _scheduleRefresh(); }),
            itemBuilder: (_) => [5, 15, 30, 60].map((seconds) => PopupMenuItem(value: seconds, child: Text('Every $seconds seconds'))).toList(),
          ),
          IconButton(
            icon: const Icon(Icons.lan_outlined),
            tooltip: 'Active Connections',
            onPressed: () => context.push(RouteNames.activeConnections),
          ),
          Switch(value: _autoRefresh, onChanged: (value) => setState(() { _autoRefresh = value; _scheduleRefresh(); })),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Columns',
            icon: const Icon(Icons.view_column),
            onSelected: (col) {
              setState(() {
                if (_visibleColumns.contains(col)) {
                  if (_visibleColumns.length > 1) _visibleColumns.remove(col);
                } else {
                  _visibleColumns.add(col);
                }
              });
            },
            itemBuilder: (_) => _allColumns.map((col) => PopupMenuItem(
              value: col,
              enabled: _visibleColumns.length > 1 || !_visibleColumns.contains(col),
              child: Row(
                children: [
                  Checkbox(value: _visibleColumns.contains(col), onChanged: null),
                  Text(col),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(message: error.toString().replaceFirst('Exception: ', ''), onRetry: _refresh),
        data: (result) {
          unawaited(ref.read(marcoStateServiceProvider).updateDeviceSnapshot(result.devices));
          final devices = _visibleDevices(result.devices);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _ConnectionBanner(status: result.connection, total: result.devices.length)),
                SliverToBoxAdapter(child: _buildToolbar()),
                if (_selectedDeviceIds.isNotEmpty) SliverToBoxAdapter(child: _buildBulkActions()),
                if (!result.connection.reachable)
                  SliverFillRemaining(hasScrollBody: false, child: _RouterUnavailable(code: result.connection.code, message: result.connection.message))
                else if (devices.isEmpty)
                  const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
                else
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder: (context, constraints) => constraints.maxWidth >= 1050 ? _buildTable(devices) : _buildCards(devices),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToolbar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Wrap(
      spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 280, child: SearchInput(
          controller: _searchController, hintText: 'Search name, hostname, IP, MAC...',
          onChanged: (value) => setState(() => _search = value), onClear: () => setState(() => _search = ''),
        )),
        DropdownButton<String>(value: _connectionFilter, items: const [
          DropdownMenuItem(value: 'all', child: Text('All Connections')),
          DropdownMenuItem(value: 'lan', child: Text('LAN')),
          DropdownMenuItem(value: 'wifi', child: Text('WiFi')),
        ], onChanged: (value) => setState(() => _connectionFilter = value ?? 'all')),
        DropdownButton<String>(value: _statusFilter, items: const [
          DropdownMenuItem(value: 'all', child: Text('All Statuses')),
          DropdownMenuItem(value: 'online', child: Text('Online')),
          DropdownMenuItem(value: 'offline', child: Text('Offline')),
        ], onChanged: (value) => setState(() => _statusFilter = value ?? 'all')),
        DropdownButton<_ConnectedDeviceSort>(value: _sort, items: _ConnectedDeviceSort.values.map((v) =>
          DropdownMenuItem(value: v, child: Text('Sort: ${_sortLabel(v)}')),
        ).toList(), onChanged: (value) => setState(() => _sort = value ?? _sort)),
        IconButton(icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward), tooltip: _ascending ? 'Ascending' : 'Descending', onPressed: () => setState(() => _ascending = !_ascending)),
      ],
    ),
  );

  String _sortLabel(_ConnectedDeviceSort value) => switch (value) {
    _ConnectedDeviceSort.name => 'Name',
    _ConnectedDeviceSort.ip => 'IP Address',
    _ConnectedDeviceSort.connection => 'Connection',
    _ConnectedDeviceSort.upload => 'Upload',
    _ConnectedDeviceSort.download => 'Download',
    _ConnectedDeviceSort.lastSeen => 'Last Seen',
  };

  Widget _buildBulkActions() => Container(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(12)),
    child: Wrap(spacing: 8, runSpacing: 8, children: [
      FilledButton.tonalIcon(onPressed: () => _bulkAction('block_internet'), icon: const Icon(Icons.block), label: const Text('Block')),
      FilledButton.tonalIcon(onPressed: () => _bulkAction('unblock_internet'), icon: const Icon(Icons.check_circle), label: const Text('Unblock')),
      FilledButton.tonalIcon(onPressed: () => _bulkAction('pin'), icon: const Icon(Icons.push_pin), label: const Text('Pin')),
      OutlinedButton.icon(onPressed: () => setState(() => _selectedDeviceIds.clear()), icon: const Icon(Icons.clear), label: const Text('Clear')),
    ]),
  );

  Widget _buildTable(List<ConnectedDevice> devices) => Scrollbar(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowHeight: 44,
        columnSpacing: 16,
        columns: [
          const DataColumn(label: Text('')),
          if (_visibleColumns.contains('Name')) const DataColumn(label: Text('Name')),
          if (_visibleColumns.contains('Hostname')) const DataColumn(label: Text('Hostname')),
          if (_visibleColumns.contains('IP')) const DataColumn(label: Text('IP')),
          if (_visibleColumns.contains('MAC')) const DataColumn(label: Text('MAC')),
          if (_visibleColumns.contains('Vendor')) const DataColumn(label: Text('Vendor')),
          if (_visibleColumns.contains('Type')) const DataColumn(label: Text('Type')),
          if (_visibleColumns.contains('Status')) const DataColumn(label: Text('Status')),
          if (_visibleColumns.contains('LAN/WiFi')) const DataColumn(label: Text('LAN/WiFi')),
          if (_visibleColumns.contains('AP')) const DataColumn(label: Text('AP')),
          if (_visibleColumns.contains('Interface')) const DataColumn(label: Text('Interface')),
          if (_visibleColumns.contains('Upload')) const DataColumn(label: Text('Upload')),
          if (_visibleColumns.contains('Download')) const DataColumn(label: Text('Download')),
          if (_visibleColumns.contains('Signal')) const DataColumn(label: Text('Signal')),
          if (_visibleColumns.contains('Department')) const DataColumn(label: Text('Dept')),
          if (_visibleColumns.contains('Room')) const DataColumn(label: Text('Room')),
          if (_visibleColumns.contains('Notes')) const DataColumn(label: Text('Notes')),
          if (_visibleColumns.contains('Group')) const DataColumn(label: Text('Group')),
          if (_visibleColumns.contains('Last Seen')) const DataColumn(label: Text('Last Seen')),
          const DataColumn(label: Text('Actions')),
        ],
        rows: devices.map((device) {
          final groupName = _groupNameFor(device.id);
          final gColor = _groupColor(groupName);
          return DataRow(
            selected: _selectedDeviceIds.contains(device.id),
            onSelectChanged: (_) => _toggleSelection(device.id),
            cells: [
              DataCell(Checkbox(value: _selectedDeviceIds.contains(device.id), onChanged: (_) => _toggleSelection(device.id))),
              if (_visibleColumns.contains('Name')) DataCell(_DeviceName(device: device)),
              if (_visibleColumns.contains('Hostname')) DataCell(Text(device.hostname ?? 'N/A')),
              if (_visibleColumns.contains('IP')) DataCell(_MonoText(device.ipAddress)),
              if (_visibleColumns.contains('MAC')) DataCell(_MonoText(device.macAddress.isEmpty ? 'N/A' : device.macAddress)),
              if (_visibleColumns.contains('Vendor')) DataCell(Text(device.vendor ?? 'N/A')),
              if (_visibleColumns.contains('Type')) DataCell(_typeBadge(device.deviceType)),
              if (_visibleColumns.contains('Status')) DataCell(_StatusChip(online: device.isOnline)),
              if (_visibleColumns.contains('LAN/WiFi')) DataCell(_ConnectionChip(type: device.connectionType)),
              if (_visibleColumns.contains('AP')) DataCell(Text(device.connectedAccessPoint ?? 'N/A')),
              if (_visibleColumns.contains('Interface')) DataCell(Text(device.interfaceName ?? 'N/A')),
              if (_visibleColumns.contains('Upload')) DataCell(Text(_speed(device.currentUploadMbps))),
              if (_visibleColumns.contains('Download')) DataCell(Text(_speed(device.currentDownloadMbps))),
              if (_visibleColumns.contains('Signal')) DataCell(Text(device.signalStrengthDbm != null ? '${device.signalStrengthDbm} dBm' : 'N/A')),
              if (_visibleColumns.contains('Department')) DataCell(Text(device.department ?? 'N/A')),
              if (_visibleColumns.contains('Room')) DataCell(Text(device.room ?? 'N/A')),
              if (_visibleColumns.contains('Notes')) DataCell(Text(device.notes ?? 'N/A')),
              if (_visibleColumns.contains('Group'))
                DataCell(groupName.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: gColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(groupName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gColor)),
                      )
                    : const Text('')),
              if (_visibleColumns.contains('Last Seen')) DataCell(Text(device.lastSeen.timeAgo())),
              DataCell(PopupMenuButton<String>(
                onSelected: (value) => _handleDeviceAction(value, device),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'comment', child: Text('Comment')),
                  const PopupMenuItem(value: 'assign', child: Text('Assign to Marco Group')),
                  const PopupMenuItem(value: 'block_internet', child: Text('Block Internet')),
                  const PopupMenuItem(value: 'unblock_internet', child: Text('Unblock Internet')),
                  const PopupMenuItem(value: 'disconnect', child: Text('Disconnect')),
                  const PopupMenuItem(value: 'limit_speed', child: Text('Limit Speed')),
                  const PopupMenuItem(value: 'details', child: Text('View Details')),
                  const PopupMenuItem(value: 'history', child: Text('View History')),
                  const PopupMenuItem(value: 'pin', child: Text('Pin Device')),
                ],
                child: const Icon(Icons.more_vert),
              )),
            ],
          );
        }).toList(),
      ),
    ),
  );

  Widget _typeBadge(String type) {
    final label = type.replaceAll('_', ' ');
    final color = switch (type) {
      'mobile' => Colors.purple,
      'tablet' => Colors.indigo,
      'laptop' => Colors.blue,
      'desktop' => Colors.blueGrey,
      'printer' => Colors.brown,
      'camera' => Colors.cyan,
      'tv' => Colors.deepPurple,
      'medical_device' => Colors.deepOrange,
      'access_point' => Colors.teal,
      'router' => Colors.blue,
      'switch' => Colors.teal.shade700,
      'server' => Colors.purple,
      'firewall' => Colors.red,
      _ => Colors.grey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildCards(List<ConnectedDevice> devices) => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    itemCount: devices.length,
    itemBuilder: (context, index) {
      final device = devices[index];
      final groupName = _groupNameFor(device.id);
      final gColor = _groupColor(groupName);
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Checkbox(value: _selectedDeviceIds.contains(device.id), onChanged: (_) => _toggleSelection(device.id)),
                Expanded(child: _DeviceName(device: device)),
                _StatusChip(online: device.isOnline),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 12, runSpacing: 8, children: [
                _detail(Icons.language, device.ipAddress, mono: true),
                _detail(Icons.badge_outlined, device.macAddress.isEmpty ? 'N/A' : device.macAddress, mono: true),
                _ConnectionChip(type: device.connectionType),
                _detail(Icons.settings_ethernet, device.interfaceName ?? 'N/A'),
                if (device.connectedAccessPoint != null) _detail(Icons.wifi_tethering, device.connectedAccessPoint!),
                _detail(Icons.upload, _speed(device.currentUploadMbps)),
                _detail(Icons.download, _speed(device.currentDownloadMbps)),
                if (device.vendor != null) _detail(Icons.business, device.vendor!),
                if (device.signalStrengthDbm != null) _detail(Icons.signal_cellular_alt, '${device.signalStrengthDbm} dBm'),
                _detail(Icons.schedule, device.lastSeen.timeAgo()),
              ]),
              if (groupName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: gColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: gColor),
                      const SizedBox(width: 4),
                      Text(groupName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: gColor)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(onPressed: () => _handleDeviceAction('rename', device), icon: const Icon(Icons.edit_outlined), label: const Text('Rename')),
                FilledButton.tonalIcon(onPressed: () => _handleDeviceAction('comment', device), icon: const Icon(Icons.note_alt_outlined), label: const Text('Comment')),
                FilledButton.tonalIcon(onPressed: () => _handleDeviceAction('assign', device), icon: const Icon(Icons.group_add_outlined), label: const Text('Assign')),
                FilledButton.tonalIcon(onPressed: () => _handleDeviceAction('block_internet', device), icon: const Icon(Icons.block), label: const Text('Block')),
              ]),
            ],
          ),
        ),
      );
    },
  );

  void _toggleSelection(String deviceId) {
    setState(() {
      if (_selectedDeviceIds.contains(deviceId)) { _selectedDeviceIds.remove(deviceId); }
      else { _selectedDeviceIds.add(deviceId); }
    });
  }

  Future<void> _bulkAction(String action) async {
    for (final deviceId in _selectedDeviceIds.toList()) {
      final device = (ref.read(connectedDevicesProvider).valueOrNull?.devices ?? []).firstWhere((entry) => entry.id == deviceId, orElse: () => null as dynamic);
      if (device != null) await _handleDeviceAction(action, device);
    }
    if (mounted) setState(() => _selectedDeviceIds.clear());
  }

  Future<void> _handleDeviceAction(String action, ConnectedDevice device) async {
    if (action == 'rename') {
      final controller = TextEditingController(text: device.deviceName);
      final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'New Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ));
      if (result != null && result.isNotEmpty) {
        await ref.read(marcoStateServiceProvider).saveProfile(MarcoDeviceProfile(deviceId: device.id, displayName: result, updatedAt: DateTime.now()));
        await _applyControlAction(device, 'rename', params: {'name': result});
      }
      return;
    }
    if (action == 'comment') {
      final controller = TextEditingController();
      final existing = ref.read(marcoStateServiceProvider).profileFor(device.id);
      if (existing != null) controller.text = existing.comment ?? '';
      final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Comment')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Save')),
        ],
      ));
      if (result != null) {
        final profile = ref.read(marcoStateServiceProvider).profileFor(device.id);
        await ref.read(marcoStateServiceProvider).saveProfile(MarcoDeviceProfile(deviceId: device.id, displayName: profile?.displayName, comment: result, groupId: profile?.groupId, pinned: profile?.pinned ?? false, updatedAt: DateTime.now()));
      }
      return;
    }
    if (action == 'assign') {
      final groups = ref.read(marcoStateServiceProvider).groups;
      if (groups.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create a Marco Group first')));
        return;
      }
      final existingProfile = ref.read(marcoStateServiceProvider).profileFor(device.id);
      final existingGroupId = existingProfile?.groupId;
      final existingGroup = existingGroupId != null ? groups.where((g) => g.id == existingGroupId).firstOrNull : null;

      final selected = await showDialog<String>(context: context, builder: (ctx) => SimpleDialog(
        title: Text(existingGroup != null ? 'Device already belongs to ${existingGroup.name}' : 'Assign to Marco Group'),
        children: [
          if (existingGroup != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Text('What do you want to do?', style: Theme.of(ctx).textTheme.bodySmall),
            ),
          ...groups.where((g) => g.id != existingGroupId).map((group) => SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, group.id),
            child: Row(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: switch (group.color) { 'blue' => Colors.blue, 'green' => Colors.green, 'orange' => Colors.orange, 'red' => Colors.red, _ => Colors.grey },
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(group.name),
            ]),
          )),
          if (existingGroup != null) ...[
            const SizedBox(height: 8),
            const Divider(),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, 'remove_${existingGroupId}'),
              child: const Text('Remove from Group', style: TextStyle(color: Colors.red)),
            ),
          ],
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ));
      if (selected == null || !mounted) return;
      if (selected.startsWith('remove_')) {
        final gid = selected.substring(7);
        final profile = ref.read(marcoStateServiceProvider).profileFor(device.id);
        if (profile?.groupId == gid) {
          await ref.read(marcoStateServiceProvider).saveProfile(MarcoDeviceProfile(
            deviceId: device.id, displayName: profile?.displayName, comment: profile?.comment,
            groupId: null, pinned: profile?.pinned ?? false, updatedAt: DateTime.now(),
          ));
        }
        return;
      }
      final profile = ref.read(marcoStateServiceProvider).profileFor(device.id);
      final msg = existingGroup != null
          ? '${device.deviceName} moved from ${existingGroup.name} to ${groups.firstWhere((g) => g.id == selected).name}'
          : '${device.deviceName} assigned to a Marco Group';
      await ref.read(marcoStateServiceProvider).saveProfile(MarcoDeviceProfile(
        deviceId: device.id, displayName: profile?.displayName, comment: profile?.comment,
        groupId: selected, pinned: profile?.pinned ?? false, updatedAt: DateTime.now(),
      ));
      await ref.read(marcoStateServiceProvider).addNotification(title: 'Device assigned', message: msg, type: 'group_assignment', deviceId: device.id);
      return;
    }
    if (action == 'pin') {
      await ref.read(marcoStateServiceProvider).togglePin(device.id);
      await ref.read(marcoStateServiceProvider).addNotification(title: 'Device pinned', message: '${device.deviceName} is pinned', type: 'pin_device', deviceId: device.id);
      return;
    }
    if (action == 'details') { if (mounted) context.push('/devices/${device.id}'); return; }
    if (action == 'history') { if (mounted) context.push('/devices/${device.id}/events'); return; }
    if (action == 'disconnect') {
      await _applyControlAction(device, 'disconnect');
      await ref.read(marcoStateServiceProvider).addNotification(title: 'Device disconnected', message: '${device.deviceName} was disconnected', type: 'device_disconnected', deviceId: device.id);
      return;
    }
    if (action == 'block_internet') {
      await _applyControlAction(device, 'block_internet');
      await ref.read(marcoStateServiceProvider).addNotification(title: 'Internet blocked', message: '${device.deviceName} internet access blocked', type: 'internet_blocked', deviceId: device.id);
      return;
    }
    if (action == 'unblock_internet') {
      await _applyControlAction(device, 'unblock_internet');
      await ref.read(marcoStateServiceProvider).addNotification(title: 'Internet unblocked', message: '${device.deviceName} internet access restored', type: 'internet_unblocked', deviceId: device.id);
      return;
    }
    if (action == 'limit_speed') {
      final controller = TextEditingController();
      final result = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Limit Speed'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Mbps')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Apply')),
        ],
      ));
      if (result != null && result.isNotEmpty) await _applyControlAction(device, 'limit_speed', params: {'download_limit_mbps': int.tryParse(result)});
      return;
    }
    await ref.read(marcoStateServiceProvider).addNotification(title: 'Action applied', message: 'Action ${action} sent for ${device.deviceName}', type: 'device_action', deviceId: device.id);
  }

  Future<void> _applyControlAction(ConnectedDevice device, String action, {Map<String, dynamic>? params}) async {
    final repo = ref.read(deviceRepositoryProvider);
    final result = await repo.controlDevice(device.id, action, params: params);
    result.fold(
      (failure) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Control action failed: ${failure.message}'))); },
      (_) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${action.replaceAll('_', ' ')} applied'))); },
    );
  }

  Widget _detail(IconData icon, String text, {bool mono = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 5),
      Text(text, style: TextStyle(fontFamily: mono ? 'JetBrainsMono' : null, fontSize: 12)),
    ],
  );

  String _speed(double? value) => value == null ? 'N/A' : '${value.toStringAsFixed(value >= 10 ? 1 : 2)} Mbps';
}

class _ConnectionBanner extends StatelessWidget {
  final dynamic status;
  final int total;
  const _ConnectionBanner({required this.status, required this.total});
  @override
  Widget build(BuildContext context) {
    final color = status.reachable ? Colors.green : Colors.red;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: .08), border: Border.all(color: color.withValues(alpha: .35)), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(status.reachable ? Icons.router : Icons.router_outlined, color: color),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(status.message, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          if (status.routerName != null)
            Text('${status.routerName} • RouterOS ${status.routerVersion ?? 'Unknown'} • ${status.apiEndpoint ?? ''}', style: Theme.of(context).textTheme.bodySmall),
        ])),
        if (status.reachable) Text('$total devices', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DeviceName extends StatelessWidget {
  final ConnectedDevice device;
  const _DeviceName({required this.device});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(device.deviceName, style: const TextStyle(fontWeight: FontWeight.w700)),
    if (device.hostname != null && device.hostname != device.deviceName) Text(device.hostname!, style: Theme.of(context).textTheme.bodySmall),
  ]);
}

class _MonoText extends StatelessWidget {
  final String text;
  const _MonoText(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12));
}

class _StatusChip extends StatelessWidget {
  final bool online;
  const _StatusChip({required this.online});
  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : Colors.red;
    return Chip(avatar: Icon(Icons.circle, size: 10, color: color), label: Text(online ? 'Online' : 'Offline'), visualDensity: VisualDensity.compact);
  }
}

class _ConnectionChip extends StatelessWidget {
  final String type;
  const _ConnectionChip({required this.type});
  @override
  Widget build(BuildContext context) {
    final wifi = type.toLowerCase() == 'wifi';
    return Chip(avatar: Icon(wifi ? Icons.wifi : Icons.lan, size: 16), label: Text(wifi ? 'WiFi' : 'LAN'), visualDensity: VisualDensity.compact);
  }
}

class _RouterUnavailable extends StatelessWidget {
  final String code;
  final String message;
  const _RouterUnavailable({required this.code, required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.router_outlined, size: 64, color: Colors.red),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(code.replaceAll('_', ' '), style: Theme.of(context).textTheme.bodySmall),
    ]),
  ));
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.devices_other, size: 64),
      const SizedBox(height: 16),
      Text('No connected devices in 172.16.0.0/24', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text('RouterOS is connected and returned no matching active entries.'),
    ]),
  ));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.dns_outlined, size: 64, color: Colors.red),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
    ]),
  ));
}
