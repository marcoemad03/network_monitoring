import 'package:equatable/equatable.dart';

class FloorMapDevice extends Equatable {
  final String id;
  final String floorMapId;
  final String deviceId;
  final double xCoord;
  final double yCoord;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloorMapDevice({
    required this.id,
    required this.floorMapId,
    required this.deviceId,
    this.xCoord = 0,
    this.yCoord = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  FloorMapDevice copyWith({
    String? id,
    String? floorMapId,
    String? deviceId,
    double? xCoord,
    double? yCoord,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorMapDevice(
      id: id ?? this.id,
      floorMapId: floorMapId ?? this.floorMapId,
      deviceId: deviceId ?? this.deviceId,
      xCoord: xCoord ?? this.xCoord,
      yCoord: yCoord ?? this.yCoord,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, floorMapId, deviceId, xCoord, yCoord, createdAt, updatedAt];
}
