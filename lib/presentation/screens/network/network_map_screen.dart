import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';
import '../../../core/enums/device_type.dart';
import '../../../core/enums/device_status.dart';
import '../../../core/network/websocket_client.dart';
import '../../../domain/entities/device.dart';
import '../../../domain/entities/device_connection.dart';

class NetworkMapScreen extends ConsumerStatefulWidget {
  const NetworkMapScreen({super.key});

  @override
  ConsumerState<NetworkMapScreen> createState() => _NetworkMapScreenState();
}

class _NetworkMapScreenState extends ConsumerState<NetworkMapScreen> {
  final TransformationController _transformController = TransformationController();
  String? _selectedDeviceId;
  Offset _hoveredPosition = Offset.zero;
  Map<String, Offset> _nodePositions = {};
  Map<String, Device> _deviceMap = {};
  List<_TopologyEdge> _edges = [];
  double _canvasWidth = 2000;
  double _canvasHeight = 2000;

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devicesAsync = ref.watch(allDevicesProvider);
    final connectionsAsync = ref.watch(connectionsProvider);

    ref.listen<AsyncValue<Map<String, dynamic>>>(
      deviceUpdateStreamProvider,
      (_, next) {
        if (next.hasValue) {
          final data = next.requireValue;
          final deviceId = data['device_id'] as String?;
          final status = data['status'] as String?;
          if (deviceId != null && status != null && _deviceMap.containsKey(deviceId)) {
            setState(() {
              _deviceMap[deviceId] = _deviceMap[deviceId]!.copyWith(
                status: DeviceStatus.fromValue(status),
              );
            });
          }
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _zoom(1.2),
            tooltip: 'Zoom In',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _zoom(0.8),
            tooltip: 'Zoom Out',
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerMap,
            tooltip: 'Center Map',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(allDevicesProvider);
              ref.invalidate(connectionsProvider);
            },
            tooltip: 'Refresh Topology',
          ),
        ],
      ),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (devices) => connectionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (connections) {
            _deviceMap = {for (final d in devices) d.id: d};
            _computeLayout(devices, connections);
            return _buildMap(theme, devices, connections);
          },
        ),
      ),
    );
  }

  void _zoom(double factor) {
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final newScale = (currentScale * factor).clamp(0.3, 3.0);
    _transformController.value = Matrix4.diagonal3Values(newScale, newScale, 1);
  }

  void _centerMap() {
    _transformController.value = Matrix4.identity();
  }

  Widget _buildMap(ThemeData theme, List<Device> devices, List<DeviceConnection> connections) {
    final edgeCount = connections.length;
    final onlineCount = devices.where((d) => d.status == DeviceStatus.online).length;
    final offlineCount = devices.where((d) => d.status == DeviceStatus.offline).length;
    final degradedCount = devices.where((d) => d.status == DeviceStatus.degraded).length;

    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _transformController,
          boundaryMargin: const EdgeInsets.all(200),
          minScale: 0.3,
          maxScale: 3.0,
          child: SizedBox(
            width: _canvasWidth,
            height: _canvasHeight,
            child: GestureDetector(
              onTapDown: (details) => _handleTap(details.localPosition),
              child: CustomPaint(
                painter: _TopologyPainter(
                  nodes: _nodePositions,
                  deviceMap: _deviceMap,
                  edges: _edges,
                  selectedDeviceId: _selectedDeviceId,
                  hoveredPosition: _hoveredPosition,
                ),
                child: SizedBox(
                  width: _canvasWidth,
                  height: _canvasHeight,
                  child: Stack(
                    children: _nodePositions.entries.map((entry) {
                      final device = _deviceMap[entry.key];
                      if (device == null) return const SizedBox.shrink();
                      return Positioned(
                        left: entry.value.dx - 60,
                        top: entry.value.dy - 30,
                        child: _DeviceNode(
                          device: device,
                          isSelected: _selectedDeviceId == device.id,
                          onTap: () => _navigateToDevice(device.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Legend', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _LegendItem(color: DeviceType.router.color, label: 'Router'),
                  _LegendItem(color: DeviceType.switch_.color, label: 'Switch'),
                  _LegendItem(color: DeviceType.server.color, label: 'Server'),
                  _LegendItem(color: DeviceType.firewall.color, label: 'Firewall'),
                  _LegendItem(color: DeviceType.accessPoint.color, label: 'Access Point'),
                  _LegendItem(color: DeviceType.workstation.color, label: 'Workstation'),
                  const SizedBox(height: 4),
                  const Divider(height: 1),
                  const SizedBox(height: 4),
                  _LegendItem(color: Colors.green, label: 'Online'),
                  _LegendItem(color: Colors.red, label: 'Offline'),
                  _LegendItem(color: Colors.orange, label: 'Degraded'),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Statistics', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Total Nodes: ${devices.length}'),
                  Text('Links: $edgeCount'),
                  Text('Online: $onlineCount'),
                  Text('Offline: $offlineCount'),
                  Text('Degraded: $degradedCount'),
                ],
              ),
            ),
          ),
        ),
        if (_selectedDeviceId != null && _deviceMap.containsKey(_selectedDeviceId))
          Positioned(
            top: 16,
            right: 16,
            child: _DeviceInfoCard(
              device: _deviceMap[_selectedDeviceId]!,
              onClose: () => setState(() => _selectedDeviceId = null),
              onNavigate: () => _navigateToDevice(_selectedDeviceId!),
            ),
          ),
      ],
    );
  }

  void _handleTap(Offset position) {
    for (final entry in _nodePositions.entries) {
      final nodeRect = Rect.fromCenter(center: entry.value, width: 120, height: 60);
      if (nodeRect.contains(position)) {
        setState(() => _selectedDeviceId = entry.key);
        return;
      }
    }
    setState(() => _selectedDeviceId = null);
  }

  void _navigateToDevice(String id) {
    context.push(RouteNames.deviceDetail.replaceAll(':id', id));
  }

  void _computeLayout(List<Device> devices, List<DeviceConnection> connections) {
    final deviceMap = {for (final d in devices) d.id: d};
    final childrenOf = <String, Set<String>>{};
    final parentOf = <String, String?>{};

    for (final conn in connections) {
      childrenOf.putIfAbsent(conn.parentDeviceId, () => {}).add(conn.childDeviceId);
      parentOf[conn.childDeviceId] = conn.parentDeviceId;
    }

    final roots = devices
        .where((d) => !parentOf.containsKey(d.id) || parentOf[d.id] == null)
        .map((d) => d.id)
        .toList();

    final layers = <int, List<String>>{};
    final visited = <String>{};
    final queue = <_BfsEntry>[];

    for (final root in roots) {
      queue.add(_BfsEntry(root, 0));
    }

    while (queue.isNotEmpty) {
      final entry = queue.removeAt(0);
      if (visited.contains(entry.id)) continue;
      visited.add(entry.id);
      layers.putIfAbsent(entry.depth, () => []).add(entry.id);
      for (final child in childrenOf[entry.id] ?? <String>{}) {
        if (!visited.contains(child)) {
          queue.add(_BfsEntry(child, entry.depth + 1));
        }
      }
    }

    for (final d in devices) {
      if (!visited.contains(d.id)) {
        final depth = layers.length;
        layers.putIfAbsent(depth, () => []).add(d.id);
      }
    }

    final maxDepth = layers.keys.isEmpty ? 0 : layers.keys.reduce(math.max);
    final layerHeight = 160.0;
    final margin = 80.0;
    final nodeWidth = 140.0;

    final positions = <String, Offset>{};
    _edges = [];

    for (final depth in layers.keys.toList()..sort()) {
      final nodes = layers[depth]!;
      final totalWidth = nodes.length * nodeWidth + (nodes.length - 1) * 20;
      final startX = (_canvasWidth - totalWidth) / 2;

      for (var i = 0; i < nodes.length; i++) {
        final x = startX + i * (nodeWidth + 20) + nodeWidth / 2;
        final y = margin + depth * layerHeight;
        positions[nodes[i]] = Offset(x, y);
      }
    }

    for (final conn in connections) {
      final parentPos = positions[conn.parentDeviceId];
      final childPos = positions[conn.childDeviceId];
      if (parentPos != null && childPos != null) {
        _edges.add(_TopologyEdge(
          parentDeviceId: conn.parentDeviceId,
          childDeviceId: conn.childDeviceId,
          speedMbps: conn.speedMbps,
          connectionType: conn.connectionType,
          isActive: conn.isActive,
        ));
      }
    }

    _nodePositions = positions;
  }
}

class _BfsEntry {
  final String id;
  final int depth;
  const _BfsEntry(this.id, this.depth);
}

class _TopologyEdge {
  final String parentDeviceId;
  final String childDeviceId;
  final double? speedMbps;
  final String connectionType;
  final bool isActive;

  const _TopologyEdge({
    required this.parentDeviceId,
    required this.childDeviceId,
    this.speedMbps,
    this.connectionType = 'ethernet',
    this.isActive = true,
  });
}

class _TopologyPainter extends CustomPainter {
  final Map<String, Offset> nodes;
  final Map<String, Device> deviceMap;
  final List<_TopologyEdge> edges;
  final String? selectedDeviceId;
  final Offset hoveredPosition;

  _TopologyPainter({
    required this.nodes,
    required this.deviceMap,
    required this.edges,
    this.selectedDeviceId,
    required this.hoveredPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawEdges(canvas);
    _drawGrid(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const gridSize = 50.0;
    for (var x = 0.0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawEdges(Canvas canvas) {
    for (final edge in edges) {
      final from = nodes[edge.parentDeviceId];
      final to = nodes[edge.childDeviceId];
      if (from == null || to == null) continue;

      final color = edge.isActive ? _connectionColor(edge.connectionType) : Colors.grey;
      final paint = Paint()
        ..color = color.withValues(alpha: edge.isActive ? 0.7 : 0.3)
        ..strokeWidth = _edgeWidth(edge.speedMbps)
        ..style = PaintingStyle.stroke;

      final midY = (from.dy + to.dy) / 2;
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);
      canvas.drawPath(path, paint);

      if (edge.speedMbps != null) {
        final midX = (from.dx + to.dx) / 2;
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${edge.speedMbps} Mbps',
            style: TextStyle(
              color: color.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(canvas, Offset(midX - textPainter.width / 2, midY - 12));
      }
    }
  }

  Color _connectionColor(String type) {
    return switch (type) {
      'fiber' => const Color(0xFF9C27B0),
      'coaxial' => const Color(0xFFFF5722),
      'wifi' => const Color(0xFF2196F3),
      'trunk' => const Color(0xFF795548),
      _ => const Color(0xFF4CAF50),
    };
  }

  double _edgeWidth(double? speedMbps) {
    if (speedMbps == null) return 1.5;
    if (speedMbps >= 10000) return 4.0;
    if (speedMbps >= 1000) return 3.0;
    if (speedMbps >= 100) return 2.0;
    return 1.5;
  }

  @override
  bool shouldRepaint(_TopologyPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.selectedDeviceId != selectedDeviceId;
}

class _DeviceNode extends StatelessWidget {
  final Device device;
  final bool isSelected;
  final VoidCallback onTap;

  const _DeviceNode({
    required this.device,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = Color(device.status.colorValue);
    final typeColor = device.type.color;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 120,
        height: 56,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? statusColor : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected ? statusColor.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.1),
              blurRadius: isSelected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: Icon(device.type.icon, size: 18, color: typeColor),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 30,
              child: Text(
                device.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 42,
              child: Text(
                device.ipAddress,
                style: TextStyle(
                  fontSize: 8,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final Device device;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  const _DeviceInfoCard({
    required this.device,
    required this.onClose,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = Color(device.status.colorValue);
    final typeColor = device.type.color;

    return Card(
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(device.type.icon, size: 20, color: typeColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(device.name, style: theme.textTheme.titleSmall, overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new, size: 16),
                  onPressed: onNavigate,
                  tooltip: 'Open Details',
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: onClose,
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 8),
            _InfoRow(label: 'IP', value: device.ipAddress),
            if (device.hostname != null) _InfoRow(label: 'Hostname', value: device.hostname!),
            _InfoRow(label: 'Type', value: device.type.label),
            _InfoRow(label: 'Status', value: device.status.label, valueColor: statusColor),
            if (device.vendor != null) _InfoRow(label: 'Vendor', value: device.vendor!),
            if (device.model != null) _InfoRow(label: 'Model', value: device.model!),
            if (device.location != null) _InfoRow(label: 'Location', value: device.location!),
            if (device.department != null) _InfoRow(label: 'Dept', value: device.department!),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: valueColor),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

extension on DeviceType {
  IconData get icon => switch (this) {
    DeviceType.router => Icons.router,
    DeviceType.switch_ => Icons.lan,
    DeviceType.server => Icons.dns,
    DeviceType.firewall => Icons.enhanced_encryption,
    DeviceType.workstation => Icons.desktop_windows,
    DeviceType.printer => Icons.print,
    DeviceType.accessPoint => Icons.wifi,
    DeviceType.camera => Icons.videocam,
    DeviceType.phone => Icons.phone,
    DeviceType.iot => Icons.sensors,
    DeviceType.medicalDevice => Icons.medical_services,
    DeviceType.unknown => Icons.devices,
  };

  Color get color => switch (this) {
    DeviceType.router => const Color(0xFF1565C0),
    DeviceType.switch_ => const Color(0xFF00897B),
    DeviceType.server => const Color(0xFFE65100),
    DeviceType.firewall => const Color(0xFFC62828),
    DeviceType.workstation => const Color(0xFF6A1B9A),
    DeviceType.printer => const Color(0xFF283593),
    DeviceType.accessPoint => const Color(0xFF4A148C),
    DeviceType.camera => const Color(0xFF37474F),
    DeviceType.phone => const Color(0xFF2E7D32),
    DeviceType.iot => const Color(0xFFF57F17),
    DeviceType.medicalDevice => const Color(0xFFC51162),
    DeviceType.unknown => const Color(0xFF78909C),
  };
}
