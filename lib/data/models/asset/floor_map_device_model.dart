import '../../../domain/entities/asset/floor_map_device.dart';

class FloorMapDeviceModel {
  final String id;
  final String floorMapId;
  final String deviceId;
  final double xCoord;
  final double yCoord;
  final String deviceName;
  final String? macAddress;
  final String? ipAddress;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloorMapDeviceModel({
    required this.id,
    required this.floorMapId,
    required this.deviceId,
    this.xCoord = 0,
    this.yCoord = 0,
    required this.deviceName,
    this.macAddress,
    this.ipAddress,
    this.status = 'unknown',
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloorMapDeviceModel.fromJson(Map<String, dynamic> json) {
    return FloorMapDeviceModel(
      id: json['id'] as String,
      floorMapId: json['floor_map_id'] as String,
      deviceId: json['device_id'] as String,
      xCoord: (json['x_coord'] as num?)?.toDouble() ?? 0,
      yCoord: (json['y_coord'] as num?)?.toDouble() ?? 0,
      deviceName:
          (json['device_name'] as String?) ?? (json['device_id'] as String),
      macAddress: json['mac_address'] as String?,
      ipAddress: json['ip_address'] as String?,
      status: (json['status'] as String?) ?? 'unknown',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'floor_map_id': floorMapId,
    'device_id': deviceId,
    'x_coord': xCoord,
    'y_coord': yCoord,
    'device_name': deviceName,
    'mac_address': macAddress,
    'ip_address': ipAddress,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  FloorMapDevice toEntity() => FloorMapDevice(
    id: id,
    floorMapId: floorMapId,
    deviceId: deviceId,
    xCoord: xCoord,
    yCoord: yCoord,
    deviceName: deviceName,
    macAddress: macAddress,
    ipAddress: ipAddress,
    status: status,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory FloorMapDeviceModel.fromEntity(FloorMapDevice entity) =>
      FloorMapDeviceModel(
        id: entity.id,
        floorMapId: entity.floorMapId,
        deviceId: entity.deviceId,
        xCoord: entity.xCoord,
        yCoord: entity.yCoord,
        deviceName: entity.deviceName,
        macAddress: entity.macAddress,
        ipAddress: entity.ipAddress,
        status: entity.status,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
