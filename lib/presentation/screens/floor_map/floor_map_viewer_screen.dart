import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/entities/asset/floor_map.dart';
import '../../../domain/entities/asset/floor_map_device.dart';
import '../../providers/asset_providers.dart';
import '../../router/route_names.dart';
import 'floor_map_canvas.dart';

class FloorMapViewerScreen extends ConsumerStatefulWidget {
  final String mapId;

  const FloorMapViewerScreen({super.key, required this.mapId});

  @override
  ConsumerState<FloorMapViewerScreen> createState() =>
      _FloorMapViewerScreenState();
}

class _FloorMapViewerScreenState extends ConsumerState<FloorMapViewerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Floor Map'),
        actions: [
          SizedBox(
            width: 280,
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
          const SizedBox(width: 12),
        ],
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([
          repo.getFloorMap(widget.mapId),
          repo.getFloorMapDevices(widget.mapId),
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('Error loading floor map'));
          }
          final mapResult = snapshot.data![0] as dynamic;
          final devicesResult = snapshot.data![1] as dynamic;
          return mapResult.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (FloorMap floorMap) => devicesResult.fold(
              (failure) => Center(child: Text('Error: ${failure.message}')),
              (List<FloorMapDevice> devices) => _buildMap(floorMap, devices),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap(FloorMap floorMap, List<FloorMapDevice> devices) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = FloorMapViewport(
          mapSize: Size(floorMap.width.toDouble(), floorMap.height.toDouble()),
          displaySize: constraints.biggest,
        );
        return Center(
          child: SizedBox.fromSize(
            size: viewport.renderedSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.network(
                    floorMap.imagePath,
                    fit: BoxFit.fill,
                    errorBuilder:
                        (_, __, ___) => const ColoredBox(
                          color: Color(0xffeeeeee),
                          child: Center(
                            child: Text('Floor map image not available'),
                          ),
                        ),
                  ),
                ),
                ...devices.map((device) {
                  final position = viewport.mapToDisplay(
                    Offset(device.xCoord, device.yCoord),
                  );
                  final highlighted = floorMapDeviceMatches(device, _query);
                  final radius = highlighted ? 16.0 : 11.0;
                  return Positioned(
                    left: position.dx - radius,
                    top: position.dy - radius,
                    child: Tooltip(
                      message:
                          '${device.deviceName}\n${device.ipAddress ?? device.deviceId}\n${device.status}',
                      child: Semantics(
                        label: '${device.deviceName}, ${device.status}',
                        button: true,
                        child: InkWell(
                          key: ValueKey('floor-map-device-${device.deviceId}'),
                          customBorder: const CircleBorder(),
                          onTap:
                              () => context.push(
                                RouteNames.deviceDetail.replaceAll(
                                  ':id',
                                  device.deviceId,
                                ),
                              ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: radius * 2,
                            height: radius * 2,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: floorMapStatusColor(device.status),
                              border: Border.all(
                                color:
                                    highlighted
                                        ? Colors.yellowAccent
                                        : Colors.white,
                                width: highlighted ? 4 : 2,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            child: const Icon(
                              Icons.devices,
                              size: 13,
                              color: Colors.white,
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
        );
      },
    );
  }
}
