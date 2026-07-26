import 'package:equatable/equatable.dart';

class FloorMapDevice extends Equatable {
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

  const FloorMapDevice({
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

  FloorMapDevice copyWith({
    String? id,
    String? floorMapId,
    String? deviceId,
    double? xCoord,
    double? yCoord,
    String? deviceName,
    String? macAddress,
    String? ipAddress,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorMapDevice(
      id: id ?? this.id,
      floorMapId: floorMapId ?? this.floorMapId,
      deviceId: deviceId ?? this.deviceId,
      xCoord: xCoord ?? this.xCoord,
      yCoord: yCoord ?? this.yCoord,
      deviceName: deviceName ?? this.deviceName,
      macAddress: macAddress ?? this.macAddress,
      ipAddress: ipAddress ?? this.ipAddress,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    floorMapId,
    deviceId,
    xCoord,
    yCoord,
    deviceName,
    macAddress,
    ipAddress,
    status,
    createdAt,
    updatedAt,
  ];
}
