import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device/device_provider.dart';
import '../../../core/enums/device_status.dart';
import '../../../core/enums/device_type.dart';
import '../../widgets/common/search_input.dart';
import '../../widgets/common/status_badge.dart';
import '../../router/route_names.dart';

enum _FilterChip { all, online, offline, critical, pinned }

class EnhancedDeviceListScreen extends ConsumerStatefulWidget {
  const EnhancedDeviceListScreen({super.key});

  @override
  ConsumerState<EnhancedDeviceListScreen> createState() =>
      _EnhancedDeviceListScreenState();
}

class _EnhancedDeviceListScreenState
    extends ConsumerState<EnhancedDeviceListScreen> {
  final _searchController = TextEditingController();
  _FilterChip _activeChip = _FilterChip.all;

  // Local filter dialog state
  String? _dialogStatus;
  String? _dialogType;
  String? _dialogBuilding;
  String? _dialogFloor;
  String? _dialogConnectionType;
  String? _dialogSortBy;
  bool _dialogAscending = true;

  static const _sortOptions = [
    ('Name', 'name'),
    ('IP', 'ip_address'),
    ('Status', 'status'),
    ('Last Seen', 'last_seen'),
    ('Signal', 'signal_strength'),
  ];

  static const _connectionTypes = ['Ethernet', 'WiFi', 'Both', 'Unknown'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(deviceFilterProvider);
    final devicesAsync = ref.watch(deviceListProvider(filter));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Device Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(deviceListProvider),
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'discover',
                child: ListTile(
                  leading: Icon(Icons.wifi_tethering),
                  title: Text('Discover 172.16 Devices'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'floor_map',
                child: ListTile(
                  leading: Icon(Icons.map),
                  title: Text('Show Floor Map'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Export CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchInput(
              controller: _searchController,
              onChanged: (value) =>
                  ref.read(deviceFilterProvider.notifier).setSearch(value),
              hintText: 'Search by name, IP, or MAC...',
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildFilterChip(_FilterChip.all, 'All'),
                _buildFilterChip(_FilterChip.online, 'Online'),
                _buildFilterChip(_FilterChip.offline, 'Offline'),
                _buildFilterChip(_FilterChip.critical, 'Critical'),
                _buildFilterChip(_FilterChip.pinned, 'Pinned'),
              ],
            ),
          ),
          Expanded(
            child: devicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text('Failed to load devices'),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(deviceListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (devices) {
                final filtered = _applyLocalFilters(devices);
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_outlined,
                            size: 64, color: theme.colorScheme.outline),
                        const SizedBox(height: 16),
                        Text('No devices found',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () =>
                              context.push(RouteNames.deviceCreate),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Device'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(deviceListProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final device = filtered[index];
                      final statusColor =
                          Color(device.status.colorValue);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(
                            RouteNames.deviceDetail
                                .replaceAll(':id', device.id),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: statusColor
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    _getDeviceIcon(device.type),
                                    color: statusColor,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              device.name,
                                              style: theme
                                                  .textTheme.titleSmall
                                                  ?.copyWith(
                                                fontWeight:
                                                    FontWeight.w600,
                                              ),
                                              overflow:
                                                  TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (device.isPinned)
                                            const SizedBox(width: 4),
                                          if (device.isPinned)
                                            Icon(Icons.push_pin,
                                                size: 14,
                                                color: theme
                                                    .colorScheme
                                                    .primary),
                                          if (device.isCritical)
                                            const SizedBox(width: 4),
                                          if (device.isCritical)
                                            Icon(Icons.warning_amber,
                                                size: 14,
                                                color: Colors.orange),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${device.ipAddress}${device.macAddress != null ? '  |  ${device.macAddress}' : ''}',
                                        style: theme
                                            .textTheme.bodySmall
                                            ?.copyWith(
                                          fontFamily: 'JetBrainsMono',
                                          color: theme.colorScheme
                                              .onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          if (device.building !=
                                                  null ||
                                              device.floor != null)
                                            _buildInfoChip(
                                              context,
                                              Icons.location_on,
                                              [
                                                device.building,
                                                device.floor
                                              ]
                                                  .whereType<String>()
                                                  .join('/'),
                                            ),
                                          if (device.connectionType !=
                                              null)
                                            _buildInfoChip(
                                              context,
                                              device.connectionType ==
                                                      'WiFi'
                                                  ? Icons.wifi
                                                  : Icons
                                                       .lan,
                                              device.connectionType!,
                                            ),
                                          if (device.type ==
                                                  DeviceType
                                                      .accessPoint &&
                                              device
                                                  .signalStrength !=
                                                  null)
                                            _buildInfoChip(
                                              context,
                                              Icons.wifi,
                                              '${device.signalStrength}%',
                                            ),
                                          StatusBadge(
                                            label:
                                                device.status.label,
                                            color: statusColor,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: theme
                                      .colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(RouteNames.deviceCreate),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(_FilterChip chip, String label) {
    final isSelected = _activeChip == chip;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _activeChip = chip);
          final notifier = ref.read(deviceFilterProvider.notifier);
          switch (chip) {
            case _FilterChip.all:
              notifier.setStatus(null);
              break;
            case _FilterChip.online:
              notifier.setStatus('online');
              break;
            case _FilterChip.offline:
              notifier.setStatus('offline');
              break;
            case _FilterChip.critical:
            case _FilterChip.pinned:
              break;
          }
        },
      ),
    );
  }

  Widget _buildInfoChip(
      BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _applyLocalFilters(List<dynamic> devices) {
    if (_activeChip == _FilterChip.critical) {
      return devices.where((d) => d.isCritical).toList();
    }
    if (_activeChip == _FilterChip.pinned) {
      return devices.where((d) => d.isPinned).toList();
    }
    return devices;
  }

  IconData _getDeviceIcon(DeviceType type) {
    switch (type) {
      case DeviceType.router:
        return Icons.router;
      case DeviceType.switch_:
        return Icons.lan;
      case DeviceType.server:
        return Icons.dns;
      case DeviceType.firewall:
        return Icons.security;
      case DeviceType.workstation:
        return Icons.desktop_windows;
      case DeviceType.printer:
        return Icons.print;
      case DeviceType.accessPoint:
        return Icons.wifi;
      case DeviceType.camera:
        return Icons.videocam;
      case DeviceType.phone:
        return Icons.phone;
      case DeviceType.iot:
        return Icons.sensors;
      case DeviceType.medicalDevice:
        return Icons.medical_services;
      default:
        return Icons.devices_other;
    }
  }

  String _formatBytes(int? bytes) {
    if (bytes == null) return 'N/A';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _handleMenuAction(BuildContext context, String value) {
    switch (value) {
      case 'discover':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scanning 172.16.0.0/16 for new devices...'),
          ),
        );
        break;
      case 'floor_map':
        context.push(RouteNames.floorMaps);
        break;
      case 'export':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exporting device inventory as CSV...'),
          ),
        );
        break;
    }
  }

  void _showFilterDialog(BuildContext context) {
    final currentFilter = ref.read(deviceFilterProvider);
    _dialogStatus = currentFilter.status;
    _dialogType = currentFilter.type;
    _dialogBuilding = null;
    _dialogFloor = null;
    _dialogConnectionType = null;
    _dialogSortBy = currentFilter.sortBy;
    _dialogAscending = currentFilter.ascending;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Filter Devices'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Status'),
                  value: _dialogStatus,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All')),
                    ...DeviceStatus.values
                        .map((s) => DropdownMenuItem(
                              value: s.value,
                              child: Text(s.label),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => _dialogStatus = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Device Type'),
                  value: _dialogType,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All')),
                    ...DeviceType.values
                        .map((t) => DropdownMenuItem(
                              value: t.value,
                              child: Text(t.label),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => _dialogType = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Building',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setDialogState(() => _dialogBuilding = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Floor',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) =>
                      setDialogState(() => _dialogFloor = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      labelText: 'Connection Type'),
                  value: _dialogConnectionType,
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('All')),
                    ..._connectionTypes
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                  ],
                  onChanged: (v) => setDialogState(
                      () => _dialogConnectionType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Sort By'),
                  value: _dialogSortBy,
                  items: _sortOptions
                      .map((o) => DropdownMenuItem(
                            value: o.$2,
                            child: Text(o.$1),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => _dialogSortBy = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Ascending'),
                    const Spacer(),
                    Switch(
                      value: _dialogAscending,
                      onChanged: (v) => setDialogState(
                          () => _dialogAscending = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(deviceFilterProvider.notifier).reset();
                setDialogState(() {
                  _dialogStatus = null;
                  _dialogType = null;
                  _dialogBuilding = null;
                  _dialogFloor = null;
                  _dialogConnectionType = null;
                  _dialogSortBy = null;
                  _dialogAscending = true;
                });
              },
              child: const Text('Reset'),
            ),
            FilledButton(
              onPressed: () {
                final notifier =
                    ref.read(deviceFilterProvider.notifier);
                notifier.setStatus(_dialogStatus);
                notifier.setType(_dialogType);
                if (_dialogSortBy != null) {
                  notifier.setSort(
                      _dialogSortBy!, _dialogAscending);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
