import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/asset_providers.dart';

class FloorMapViewerScreen extends ConsumerWidget {
  final String mapId;
  const FloorMapViewerScreen({super.key, required this.mapId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(assetRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Floor Map')),
      body: FutureBuilder(
        future: Future.wait([repo.getFloorMap(mapId), repo.getFloorMapDevices(mapId)]),
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
                  return Stack(
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
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Device: ${d.deviceId}')),
                              );
                            },
                            child: const CircleAvatar(
                              radius: 8,
                              backgroundColor: Colors.green,
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
