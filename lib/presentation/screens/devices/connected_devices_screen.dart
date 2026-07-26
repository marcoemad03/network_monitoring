import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/connected_device.dart';
import '../../../shared/extensions/datetime_extensions.dart';
import '../../providers/device/device_provider.dart';
import '../../widgets/common/search_input.dart';

enum _ConnectedDeviceSort { name, ip, connection, upload, download, lastSeen }

class ConnectedDevicesScreen extends ConsumerStatefulWidget {
  const ConnectedDevicesScreen({super.key});

  @override
  ConsumerState<ConnectedDevicesScreen> createState() =>
      _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState
    extends ConsumerState<ConnectedDevicesScreen> {
  final _searchController = TextEditingController();
  Timer? _timer;
  String _search = '';
  String _connectionFilter = 'all';
  String _statusFilter = 'all';
  _ConnectedDeviceSort _sort = _ConnectedDeviceSort.ip;
  bool _ascending = true;
  bool _autoRefresh = true;
  int _refreshSeconds = 15;

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

  List<ConnectedDevice> _visibleDevices(List<ConnectedDevice> source) {
    final query = _search.trim().toLowerCase();
    final devices =
        source.where((device) {
          final matchesSearch =
              query.isEmpty ||
              [
                device.deviceName,
                device.hostname,
                device.ipAddress,
                device.macAddress,
                device.interfaceName,
                device.connectedAccessPoint,
              ].whereType<String>().any(
                (value) => value.toLowerCase().contains(query),
              );
          final matchesConnection =
              _connectionFilter == 'all' ||
              device.connectionType.toLowerCase() == _connectionFilter;
          final matchesStatus =
              _statusFilter == 'all' ||
              (_statusFilter == 'online' ? device.isOnline : !device.isOnline);
          return matchesSearch && matchesConnection && matchesStatus;
        }).toList();
    int compare(ConnectedDevice a, ConnectedDevice b) => switch (_sort) {
      _ConnectedDeviceSort.name => a.deviceName.toLowerCase().compareTo(
        b.deviceName.toLowerCase(),
      ),
      _ConnectedDeviceSort.ip => _ipNumber(
        a.ipAddress,
      ).compareTo(_ipNumber(b.ipAddress)),
      _ConnectedDeviceSort.connection => a.connectionType.compareTo(
        b.connectionType,
      ),
      _ConnectedDeviceSort.upload => (a.currentUploadMbps ?? 0).compareTo(
        b.currentUploadMbps ?? 0,
      ),
      _ConnectedDeviceSort.download => (a.currentDownloadMbps ?? 0).compareTo(
        b.currentDownloadMbps ?? 0,
      ),
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
    final state = ref.watch(connectedDevicesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh RouterOS data',
            onPressed: _refresh,
          ),
          PopupMenuButton<int>(
            tooltip: 'Auto refresh interval',
            icon: Icon(_autoRefresh ? Icons.sync : Icons.sync_disabled),
            onSelected:
                (seconds) => setState(() {
                  _refreshSeconds = seconds;
                  _autoRefresh = true;
                  _scheduleRefresh();
                }),
            itemBuilder:
                (_) =>
                    [5, 15, 30, 60]
                        .map(
                          (seconds) => PopupMenuItem(
                            value: seconds,
                            child: Text('Every $seconds seconds'),
                          ),
                        )
                        .toList(),
          ),
          Switch(
            value: _autoRefresh,
            onChanged:
                (value) => setState(() {
                  _autoRefresh = value;
                  _scheduleRefresh();
                }),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => _ErrorState(
              message: error.toString().replaceFirst('Exception: ', ''),
              onRetry: _refresh,
            ),
        data: (result) {
          final devices = _visibleDevices(result.devices);
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ConnectionBanner(
                    status: result.connection,
                    total: result.devices.length,
                  ),
                ),
                SliverToBoxAdapter(child: _buildToolbar()),
                if (!result.connection.reachable)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _RouterUnavailable(
                      code: result.connection.code,
                      message: result.connection.message,
                    ),
                  )
                else if (devices.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  )
                else
                  SliverToBoxAdapter(
                    child: LayoutBuilder(
                      builder:
                          (context, constraints) =>
                              constraints.maxWidth >= 1050
                                  ? _buildTable(devices)
                                  : _buildCards(devices),
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
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: SearchInput(
            controller: _searchController,
            hintText: 'Search name, hostname, IP, MAC, interface...',
            onChanged: (value) => setState(() => _search = value),
            onClear: () => setState(() => _search = ''),
          ),
        ),
        DropdownButton<String>(
          value: _connectionFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Connections')),
            DropdownMenuItem(value: 'lan', child: Text('LAN')),
            DropdownMenuItem(value: 'wifi', child: Text('WiFi')),
          ],
          onChanged:
              (value) => setState(() => _connectionFilter = value ?? 'all'),
        ),
        DropdownButton<String>(
          value: _statusFilter,
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Statuses')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
            DropdownMenuItem(value: 'offline', child: Text('Offline')),
          ],
          onChanged: (value) => setState(() => _statusFilter = value ?? 'all'),
        ),
        DropdownButton<_ConnectedDeviceSort>(
          value: _sort,
          items:
              _ConnectedDeviceSort.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text('Sort: ${_sortLabel(value)}'),
                    ),
                  )
                  .toList(),
          onChanged: (value) => setState(() => _sort = value ?? _sort),
        ),
        IconButton(
          icon: Icon(_ascending ? Icons.arrow_upward : Icons.arrow_downward),
          tooltip: _ascending ? 'Ascending' : 'Descending',
          onPressed: () => setState(() => _ascending = !_ascending),
        ),
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

  Widget _buildTable(List<ConnectedDevice> devices) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.all(16),
    child: DataTable(
      columns: const [
        DataColumn(label: Text('Device')),
        DataColumn(label: Text('IP Address')),
        DataColumn(label: Text('MAC Address')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('LAN / WiFi')),
        DataColumn(label: Text('Access Point')),
        DataColumn(label: Text('Interface')),
        DataColumn(label: Text('Upload')),
        DataColumn(label: Text('Download')),
        DataColumn(label: Text('Last Seen')),
      ],
      rows:
          devices
              .map(
                (device) => DataRow(
                  cells: [
                    DataCell(_DeviceName(device: device)),
                    DataCell(_MonoText(device.ipAddress)),
                    DataCell(
                      _MonoText(
                        device.macAddress.isEmpty ? 'N/A' : device.macAddress,
                      ),
                    ),
                    DataCell(_StatusChip(online: device.isOnline)),
                    DataCell(_ConnectionChip(type: device.connectionType)),
                    DataCell(Text(device.connectedAccessPoint ?? 'N/A')),
                    DataCell(Text(device.interfaceName ?? 'N/A')),
                    DataCell(Text(_speed(device.currentUploadMbps))),
                    DataCell(Text(_speed(device.currentDownloadMbps))),
                    DataCell(Text(device.lastSeen.timeAgo())),
                  ],
                ),
              )
              .toList(),
    ),
  );

  Widget _buildCards(List<ConnectedDevice> devices) => ListView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: const EdgeInsets.all(16),
    itemCount: devices.length,
    itemBuilder: (context, index) {
      final device = devices[index];
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _DeviceName(device: device)),
                  _StatusChip(online: device.isOnline),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _detail(Icons.language, device.ipAddress, mono: true),
                  _detail(
                    Icons.badge_outlined,
                    device.macAddress.isEmpty ? 'N/A' : device.macAddress,
                    mono: true,
                  ),
                  _ConnectionChip(type: device.connectionType),
                  _detail(
                    Icons.settings_ethernet,
                    device.interfaceName ?? 'N/A',
                  ),
                  if (device.connectedAccessPoint != null)
                    _detail(Icons.wifi_tethering, device.connectedAccessPoint!),
                  _detail(Icons.upload, _speed(device.currentUploadMbps)),
                  _detail(Icons.download, _speed(device.currentDownloadMbps)),
                  _detail(Icons.schedule, device.lastSeen.timeAgo()),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _detail(IconData icon, String text, {bool mono = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 5),
      Text(
        text,
        style: TextStyle(
          fontFamily: mono ? 'JetBrainsMono' : null,
          fontSize: 12,
        ),
      ),
    ],
  );
  String _speed(double? value) =>
      value == null
          ? 'N/A'
          : '${value.toStringAsFixed(value >= 10 ? 1 : 2)} Mbps';
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        border: Border.all(color: color.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            status.reachable ? Icons.router : Icons.router_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.message,
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                if (status.routerName != null)
                  Text(
                    '${status.routerName} • RouterOS ${status.routerVersion ?? 'Unknown'} • ${status.apiEndpoint ?? ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          if (status.reachable)
            Text(
              '$total devices',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

class _DeviceName extends StatelessWidget {
  final ConnectedDevice device;
  const _DeviceName({required this.device});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        device.deviceName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (device.hostname != null && device.hostname != device.deviceName)
        Text(device.hostname!, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}

class _MonoText extends StatelessWidget {
  final String text;
  const _MonoText(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
  );
}

class _StatusChip extends StatelessWidget {
  final bool online;
  const _StatusChip({required this.online});
  @override
  Widget build(BuildContext context) {
    final color = online ? Colors.green : Colors.red;
    return Chip(
      avatar: Icon(Icons.circle, size: 10, color: color),
      label: Text(online ? 'Online' : 'Offline'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  final String type;
  const _ConnectionChip({required this.type});
  @override
  Widget build(BuildContext context) {
    final wifi = type.toLowerCase() == 'wifi';
    return Chip(
      avatar: Icon(wifi ? Icons.wifi : Icons.lan, size: 16),
      label: Text(wifi ? 'WiFi' : 'LAN'),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _RouterUnavailable extends StatelessWidget {
  final String code;
  final String message;
  const _RouterUnavailable({required this.code, required this.message});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.router_outlined, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            code.replaceAll('_', ' '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.devices_other, size: 64),
        const SizedBox(height: 16),
        Text(
          'No connected devices in 172.16.0.0/24',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'RouterOS is connected and returned no matching active entries.',
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.dns_outlined, size: 64, color: Colors.red),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );
}
