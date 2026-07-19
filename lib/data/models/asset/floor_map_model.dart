import '../../../domain/entities/asset/floor_map.dart';

class FloorMapModel {
  final String id;
  final String organizationId;
  final String name;
  final String imagePath;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloorMapModel({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.imagePath,
    this.width = 1000,
    this.height = 800,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FloorMapModel.fromJson(Map<String, dynamic> json) {
    return FloorMapModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      name: json['name'] as String,
      imagePath: json['image_path'] as String,
      width: (json['width'] as num?)?.toInt() ?? 1000,
      height: (json['height'] as num?)?.toInt() ?? 800,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'organization_id': organizationId,
    'name': name,
    'image_path': imagePath,
    'width': width,
    'height': height,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  FloorMap toEntity() => FloorMap(
    id: id,
    organizationId: organizationId,
    name: name,
    imagePath: imagePath,
    width: width,
    height: height,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  factory FloorMapModel.fromEntity(FloorMap entity) => FloorMapModel(
    id: entity.id,
    organizationId: entity.organizationId,
    name: entity.name,
    imagePath: entity.imagePath,
    width: entity.width,
    height: entity.height,
    createdAt: entity.createdAt,
    updatedAt: entity.updatedAt,
  );
}
