import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/asset/floor_map.dart';
import '../../../domain/entities/asset/floor_map_device.dart';
import '../../../domain/entities/connected_device.dart';
import '../../providers/asset_providers.dart';
import '../../providers/device/device_provider.dart';
import '../../router/route_names.dart';
import 'floor_map_canvas.dart';

bool _isIn172Subnet(String ip) {
  final parts = ip.split('.').map(int.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null)) return false;
  return parts[0]! >= 172 && parts[0]! <= 172;
}

class FloorMapViewerScreen extends ConsumerStatefulWidget {
  final String mapId;

  const FloorMapViewerScreen({super.key, required this.mapId});

  @override
  ConsumerState<FloorMapViewerScreen> createState() =>
      _FloorMapViewerScreenState();
}

class _FloorMapViewerScreenState extends ConsumerState<FloorMapViewerScreen> {
  String _query = '';
  int _currentFloorIndex = 0;
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hospital Map'),
        actions: [
          SizedBox(
            width: 260,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                key: const ValueKey('floor-map-search'),
                decoration: const InputDecoration(
                  hintText: 'Find device, IP, or MAC',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  filled: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Reset zoom',
            onPressed: () => _transformController.value = Matrix4.identity(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
        ],
      ),
      bottomNavigationBar: _buildFloorTabs(),
    );
  }

  Widget _buildBody() {
    final repo = ref.watch(assetRepositoryProvider);
    return FutureBuilder<List<FloorMap>>(
      future: repo.getFloorMaps().then((r) => r.fold((_) => <FloorMap>[], (m) => m)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final floors = snapshot.data ?? <FloorMap>[];
        if (floors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 64),
                SizedBox(height: 16),
                Text('No floor maps available'),
              ],
            ),
          );
        }
        final index = _currentFloorIndex.clamp(0, floors.length - 1);
        final currentMap = floors[index];
        return FutureBuilder<List<FloorMapDevice>>(
          future: repo.getFloorMapDevices(currentMap.id).then(
              (r) => r.fold((_) => <FloorMapDevice>[], (d) => d)),
          builder: (ctx, devSnap) {
            var devices = devSnap.data ?? <FloorMapDevice>[];
            return ref.watch(connectedDevicesProvider).when(
              loading: () => _buildMapView(currentMap, devices),
              error: (_, __) => _buildMapView(currentMap, devices),
              data: (result) {
                if (result.connection.reachable && result.devices.isNotEmpty) {
                  if (devices.isEmpty) {
                    _autoPopulate(currentMap, result.devices);
                  }
                  devices = _mergeDevices(devices, result.devices);
                }
                return _buildMapView(currentMap, devices);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFloorTabs() {
    final repo = ref.read(assetRepositoryProvider);
    return FutureBuilder<List<FloorMap>>(
      future: repo.getFloorMaps().then((r) => r.fold((_) => <FloorMap>[], (m) => m)),
      builder: (context, snapshot) {
        final floors = snapshot.data ?? <FloorMap>[];
        if (floors.length <= 1) return const SizedBox.shrink();
        return Container(
          height: 56,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: floors.length,
            itemBuilder: (context, index) {
              final isSelected = index == _currentFloorIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: FilterChip(
                  label: Text(floors[index].name),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _currentFloorIndex = index);
                    _transformController.value = Matrix4.identity();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMapView(FloorMap floorMap, List<FloorMapDevice> devices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = FloorMapViewport(
          mapSize: Size(floorMap.width.toDouble(), floorMap.height.toDouble()),
          displaySize: constraints.biggest,
        );
        return InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.3,
          maxScale: 4.0,
          boundaryMargin: const EdgeInsets.all(100),
          child: Center(
            child: SizedBox.fromSize(
              size: viewport.renderedSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Image.network(
                      floorMap.imagePath,
                      fit: BoxFit.fill,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: const Color(0xffeeeeee),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.image_not_supported, size: 48),
                              const SizedBox(height: 8),
                              Text(floorMap.name),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  ...devices.map((device) {
                    final position = viewport.mapToDisplay(
                      Offset(device.xCoord.toDouble(), device.yCoord.toDouble()),
                    );
                    final highlighted = floorMapDeviceMatches(device, _query);
                    final radius = highlighted ? 16.0 : 11.0;
                    return Positioned(
                      left: position.dx - radius,
                      top: position.dy - radius,
                      child: Draggable<FloorMapDevice>(
                        data: device,
                        feedback: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(radius),
                          child: CircleAvatar(
                            radius: radius,
                            backgroundColor: floorMapStatusColor(device.status),
                            child: const Icon(Icons.devices, size: 13, color: Colors.white),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: CircleAvatar(
                            radius: radius,
                            backgroundColor: floorMapStatusColor(device.status),
                          ),
                        ),
                        onDragEnd: (details) {
                          final newPos = viewport.displayToMap(details.offset);
                          ref.read(assetRepositoryProvider).placeDeviceOnMap({
                            'floor_map_id': floorMap.id,
                            'device_id': device.deviceId,
                            'device_name': device.deviceName,
                            'ip_address': device.ipAddress,
                            'mac_address': device.macAddress,
                            'status': device.status,
                            'x_coord': newPos.dx,
                            'y_coord': newPos.dy,
                          });
                        },
                        child: Tooltip(
                          message: '${device.deviceName}\n${device.ipAddress ?? device.deviceId}\n${device.status}',
                          child: Semantics(
                            label: '${device.deviceName}, ${device.status}',
                            button: true,
                            child: InkWell(
                              key: ValueKey('floor-map-device-${device.deviceId}'),
                              customBorder: const CircleBorder(),
                              onTap: () => context.push(
                                RouteNames.deviceDetail.replaceAll(':id', device.deviceId),
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: radius * 2,
                                height: radius * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: floorMapStatusColor(device.status),
                                  border: Border.all(
                                    color: highlighted ? Colors.yellowAccent : Colors.white,
                                    width: highlighted ? 4 : 2,
                                  ),
                                  boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                                ),
                                child: const Icon(Icons.devices, size: 13, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _autoPopulate(FloorMap floorMap, List<ConnectedDevice> connected) {
    final repo = ref.read(assetRepositoryProvider);
    for (final device in connected) {
      if (!device.isOnline || !_isIn172Subnet(device.ipAddress)) continue;
      repo.placeDeviceOnMap({
        'floor_map_id': floorMap.id,
        'device_id': device.id,
        'device_name': device.deviceName,
        'ip_address': device.ipAddress,
        'mac_address': device.macAddress,
        'status': 'online',
        'x_coord': (DateTime.now().microsecondsSinceEpoch % 900).toDouble(),
        'y_coord': (DateTime.now().microsecondsSinceEpoch ~/ 1000 % 700).toDouble(),
      });
    }
  }

  List<FloorMapDevice> _mergeDevices(List<FloorMapDevice> mapDevices, List<ConnectedDevice> connected) {
    final macSet = <String>{};
    final ipSet = <String>{};
    for (final d in mapDevices) {
      if (d.macAddress != null) macSet.add(d.macAddress!);
      if (d.ipAddress != null) ipSet.add(d.ipAddress!);
    }
    final merged = List<FloorMapDevice>.from(mapDevices);
    for (final c in connected) {
      if (!c.isOnline || !_isIn172Subnet(c.ipAddress)) continue;
      if (c.macAddress.isNotEmpty && macSet.contains(c.macAddress)) continue;
      if (ipSet.contains(c.ipAddress)) continue;
      merged.add(FloorMapDevice(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        floorMapId: mapDevices.isNotEmpty ? mapDevices[0].floorMapId : '',
        deviceId: c.id,
        deviceName: c.deviceName,
        ipAddress: c.ipAddress,
        macAddress: c.macAddress.isEmpty ? null : c.macAddress,
        status: c.isOnline ? 'online' : 'offline',
        xCoord: (DateTime.now().microsecondsSinceEpoch % 900).toDouble(),
        yCoord: (DateTime.now().microsecondsSinceEpoch ~/ 1000 % 700).toDouble(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    return merged;
  }
}
