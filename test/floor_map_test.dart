import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_monitorong/data/models/asset/floor_map_device_model.dart';
import 'package:network_monitorong/presentation/screens/floor_map/floor_map_canvas.dart';

void main() {
  const json = <String, dynamic>{
    'id': 'placement-1',
    'floor_map_id': 'map-1',
    'device_id': 'device-1',
    'x_coord': 500,
    'y_coord': 200.5,
    'device_name': 'ICU Monitor',
    'mac_address': 'AA:BB:CC:DD:EE:FF',
    'ip_address': '10.0.0.15',
    'status': 'degraded',
    'created_at': '2026-07-26T10:00:00Z',
    'updated_at': '2026-07-26T11:00:00Z',
  };

  test('parses joined floor map device metadata', () {
    final device = FloorMapDeviceModel.fromJson(json).toEntity();

    expect(device.deviceName, 'ICU Monitor');
    expect(device.macAddress, 'AA:BB:CC:DD:EE:FF');
    expect(device.ipAddress, '10.0.0.15');
    expect(device.status, 'degraded');
    expect(device.xCoord, 500);
    expect(floorMapStatusColor(device.status), Colors.orange);
  });

  test('search matches metadata case-insensitively', () {
    final device = FloorMapDeviceModel.fromJson(json).toEntity();

    expect(floorMapDeviceMatches(device, 'icu'), isTrue);
    expect(floorMapDeviceMatches(device, 'aa:bb'), isTrue);
    expect(floorMapDeviceMatches(device, '10.0.0'), isTrue);
    expect(floorMapDeviceMatches(device, 'offline'), isFalse);
  });

  test('map coordinates round-trip in a responsive contained viewport', () {
    const viewport = FloorMapViewport(
      mapSize: Size(1000, 800),
      displaySize: Size(500, 700),
    );

    expect(viewport.renderedSize, const Size(500, 400));
    expect(viewport.mapToDisplay(const Offset(500, 200)), const Offset(250, 100));
    expect(viewport.displayToMap(const Offset(250, 100)), const Offset(500, 200));
    expect(viewport.displayToMap(const Offset(600, -10)), const Offset(1000, 0));
  });
}
