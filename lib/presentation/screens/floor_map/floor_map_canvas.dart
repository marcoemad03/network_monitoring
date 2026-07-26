import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/entities/asset/floor_map_device.dart';

class FloorMapViewport {
  final Size mapSize;
  final Size displaySize;

  const FloorMapViewport({required this.mapSize, required this.displaySize});

  double get scale => math.min(
    displaySize.width / mapSize.width,
    displaySize.height / mapSize.height,
  );

  Size get renderedSize => Size(mapSize.width * scale, mapSize.height * scale);

  Offset displayToMap(Offset position) => Offset(
    (position.dx / scale).clamp(0, mapSize.width),
    (position.dy / scale).clamp(0, mapSize.height),
  );

  Offset mapToDisplay(Offset position) => Offset(
    position.dx.clamp(0, mapSize.width) * scale,
    position.dy.clamp(0, mapSize.height) * scale,
  );
}

Color floorMapStatusColor(String status) => switch (status.toLowerCase()) {
  'online' => Colors.green,
  'offline' => Colors.red,
  'degraded' => Colors.orange,
  'maintenance' => Colors.blue,
  _ => Colors.grey,
};

bool floorMapDeviceMatches(FloorMapDevice device, String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  return [
    device.deviceName,
    device.deviceId,
    device.ipAddress ?? '',
    device.macAddress ?? '',
    device.status,
  ].any((value) => value.toLowerCase().contains(normalized));
}
