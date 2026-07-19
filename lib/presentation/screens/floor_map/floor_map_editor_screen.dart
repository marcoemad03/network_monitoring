import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/asset_providers.dart';

class FloorMapEditorScreen extends ConsumerStatefulWidget {
  final String mapId;
  const FloorMapEditorScreen({super.key, required this.mapId});

  @override
  ConsumerState<FloorMapEditorScreen> createState() => _FloorMapEditorScreenState();
}

class _FloorMapEditorScreenState extends ConsumerState<FloorMapEditorScreen> {
  String? _selectedDeviceId;
  final _deviceIdCtrl = TextEditingController();

  void _placeDevice(double x, double y) {
    if (_selectedDeviceId == null) return;
    ref.read(assetRepositoryProvider).placeDeviceOnMap({
      'floor_map_id': widget.mapId,
      'device_id': _selectedDeviceId,
      'x_coord': x,
      'y_coord': y,
    });
    setState(() => _selectedDeviceId = null);
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Floor Map')),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _deviceIdCtrl,
                decoration: InputDecoration(
                  labelText: 'Device ID',
                  border: const OutlineInputBorder(),
                  suffixIcon: _selectedDeviceId != null
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _selectedDeviceId = null),
                        )
                      : null,
                ),
                onSubmitted: (v) => setState(() => _selectedDeviceId = v),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final id = _deviceIdCtrl.text.trim();
                if (id.isNotEmpty) setState(() => _selectedDeviceId = id);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
      body: FutureBuilder(
        future: Future.wait([repo.getFloorMap(widget.mapId), repo.getFloorMapDevices(widget.mapId)]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final results = snapshot.data;
          if (results == null || results.length < 2) {
            return const Center(child: Text('Error loading'));
          }
          final mapResult = results[0] as dynamic;
          final devicesResult = results[1] as dynamic;
          return mapResult.fold(
            (failure) => Center(child: Text('Error: ${failure.message}')),
            (floorMap) {
              return devicesResult.fold(
                (failure) => Center(child: Text('Error: ${failure.message}')),
                (devices) {
                  return GestureDetector(
                    onTapUp: (details) {
                      if (_selectedDeviceId != null) {
                        _placeDevice(details.localPosition.dx, details.localPosition.dy);
                      }
                    },
                    child: Stack(
                      children: [
                        Image.network(
                          floorMap.imagePath,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map, size: 64, color: Colors.grey),
                                Text('Floor map image not available'),
                              ],
                            ),
                          ),
                        ),
                        ...devices.map((d) {
                          return Positioned(
                            left: d.xCoord,
                            top: d.yCoord,
                            child: GestureDetector(
                              onPanUpdate: (details) {
                                ref.read(assetRepositoryProvider).placeDeviceOnMap({
                                  'floor_map_id': widget.mapId,
                                  'device_id': d.deviceId,
                                  'x_coord': d.xCoord + details.delta.dx,
                                  'y_coord': d.yCoord + details.delta.dy,
                                });
                              },
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.devices, size: 12, color: Colors.white),
                              ),
                            ),
                          );
                        }),
                        if (_selectedDeviceId != null)
                          const Center(
                            child: Card(
                              color: Colors.amber,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('Tap on map to place device', style: TextStyle(color: Colors.black87)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _deviceIdCtrl.dispose();
    super.dispose();
  }
}
