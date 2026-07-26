import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/asset/floor_map.dart';
import '../../../domain/entities/asset/floor_map_device.dart';
import '../../providers/asset_providers.dart';
import 'floor_map_canvas.dart';

class FloorMapEditorScreen extends ConsumerStatefulWidget {
  final String mapId;

  const FloorMapEditorScreen({super.key, required this.mapId});

  @override
  ConsumerState<FloorMapEditorScreen> createState() =>
      _FloorMapEditorScreenState();
}

class _FloorMapEditorScreenState extends ConsumerState<FloorMapEditorScreen> {
  final _deviceIdCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  String? _selectedDeviceId;
  String _query = '';
  late Future<List<dynamic>> _loadFuture;
  List<FloorMapDevice>? _devices;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final repo = ref.read(assetRepositoryProvider);
    _loadFuture = Future.wait([
      repo.getFloorMap(widget.mapId),
      repo.getFloorMapDevices(widget.mapId),
    ]);
    _devices = null;
  }

  Future<void> _placeDevice(Offset mapPosition) async {
    final deviceId = _selectedDeviceId;
    if (deviceId == null) return;
    final result = await ref.read(assetRepositoryProvider).placeDeviceOnMap({
      'floor_map_id': widget.mapId,
      'device_id': deviceId,
      'x_coord': mapPosition.dx,
      'y_coord': mapPosition.dy,
    });
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place device: ${failure.message}')),
      ),
      (_) => setState(() {
        _selectedDeviceId = null;
        _deviceIdCtrl.clear();
        _reload();
      }),
    );
  }

  Future<void> _persistPosition(FloorMapDevice device) async {
    final result = await ref.read(assetRepositoryProvider).placeDeviceOnMap({
      'floor_map_id': widget.mapId,
      'device_id': device.deviceId,
      'x_coord': device.xCoord,
      'y_coord': device.yCoord,
    });
    if (!mounted) return;
    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not move device: ${failure.message}')),
      ),
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Floor Map'),
        actions: [
          SizedBox(
            width: 260,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                key: const ValueKey('floor-map-editor-search'),
                decoration: const InputDecoration(
                  hintText: 'Highlight a device',
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _deviceIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Device ID to place',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: _selectDevice,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () => _selectDevice(_deviceIdCtrl.text),
                child: Text(_selectedDeviceId == null ? 'Select' : 'Cancel'),
              ),
            ],
          ),
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _loadFuture,
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
              (List<FloorMapDevice> loadedDevices) {
                _devices ??= List.of(loadedDevices);
                return _buildMap(floorMap);
              },
            ),
          );
        },
      ),
    );
  }

  void _selectDevice(String value) {
    final id = value.trim();
    setState(() {
      if (_selectedDeviceId != null) {
        _selectedDeviceId = null;
      } else if (id.isNotEmpty) {
        _selectedDeviceId = id;
      }
    });
  }

  Widget _buildMap(FloorMap floorMap) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = FloorMapViewport(
          mapSize: Size(floorMap.width.toDouble(), floorMap.height.toDouble()),
          displaySize: constraints.biggest,
        );
        return Center(
          child: SizedBox.fromSize(
            size: viewport.renderedSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp:
                  _selectedDeviceId == null
                      ? null
                      : (details) => _placeDevice(
                        viewport.displayToMap(details.localPosition),
                      ),
              child: Stack(
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
                  ..._devices!.asMap().entries.map((entry) {
                    final index = entry.key;
                    final device = entry.value;
                    final position = viewport.mapToDisplay(
                      Offset(device.xCoord, device.yCoord),
                    );
                    final highlighted = floorMapDeviceMatches(device, _query);
                    final radius = highlighted ? 16.0 : 11.0;
                    return Positioned(
                      left: position.dx - radius,
                      top: position.dy - radius,
                      child: GestureDetector(
                        key: ValueKey(
                          'floor-map-editor-device-${device.deviceId}',
                        ),
                        onPanUpdate: (details) {
                          final current = _devices![index];
                          setState(() {
                            _devices![index] = current.copyWith(
                              xCoord: (current.xCoord +
                                      details.delta.dx / viewport.scale)
                                  .clamp(0, floorMap.width.toDouble()),
                              yCoord: (current.yCoord +
                                      details.delta.dy / viewport.scale)
                                  .clamp(0, floorMap.height.toDouble()),
                            );
                          });
                        },
                        onPanEnd: (_) => _persistPosition(_devices![index]),
                        child: Tooltip(
                          message: '${device.deviceName}\n${device.status}',
                          child: Container(
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
                    );
                  }),
                  if (_selectedDeviceId != null)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Card(
                        color: Colors.amber,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Text(
                            'Tap the map to place the selected device',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}
