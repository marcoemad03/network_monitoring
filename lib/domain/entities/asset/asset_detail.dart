import 'package:equatable/equatable.dart';

class AssetDetail extends Equatable {
  final String id;
  final String deviceId;
  final String? department;
  final String? floorName;
  final String? room;
  final String? switchPort;
  final String? accessPointId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AssetDetail({
    required this.id,
    required this.deviceId,
    this.department,
    this.floorName,
    this.room,
    this.switchPort,
    this.accessPointId,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  AssetDetail copyWith({
    String? id,
    String? deviceId,
    String? department,
    String? floorName,
    String? room,
    String? switchPort,
    String? accessPointId,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AssetDetail(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      department: department ?? this.department,
      floorName: floorName ?? this.floorName,
      room: room ?? this.room,
      switchPort: switchPort ?? this.switchPort,
      accessPointId: accessPointId ?? this.accessPointId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, deviceId, department, floorName, room, switchPort, accessPointId, notes, createdAt, updatedAt];
}
