import '../../../domain/entities/asset/asset_detail.dart';

class AssetDetailModel {
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

  const AssetDetailModel({
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

  factory AssetDetailModel.fromJson(Map<String, dynamic> json) {
    return AssetDetailModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      department: json['department'] as String?,
      floorName: json['floor_name'] as String?,
      room: json['room'] as String?,
      switchPort: json['switch_port'] as String?,
      accessPointId: json['access_point_id'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'device_id': deviceId,
    if (department != null) 'department': department,
    if (floorName != null) 'floor_name': floorName,
    if (room != null) 'room': room,
    if (switchPort != null) 'switch_port': switchPort,
    if (accessPointId != null) 'access_point_id': accessPointId,
    if (notes != null) 'notes': notes,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  AssetDetail toEntity() => AssetDetail(
    id: id,
    deviceId: deviceId,
    department: department,
    floorName: floorName,
    room: room,
    switchPort: switchPort,
    accessPointId: accessPointId,
    notes: notes,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory AssetDetailModel.fromEntity(AssetDetail entity) => AssetDetailModel(
    id: entity.id,
    deviceId: entity.deviceId,
    department: entity.department,
    floorName: entity.floorName,
    room: entity.room,
    switchPort: entity.switchPort,
    accessPointId: entity.accessPointId,
    notes: entity.notes,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}
