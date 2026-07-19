import 'package:equatable/equatable.dart';

class FloorMap extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String imagePath;
  final int width;
  final int height;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FloorMap({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.imagePath,
    this.width = 1000,
    this.height = 800,
    required this.createdAt,
    required this.updatedAt,
  });

  FloorMap copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? imagePath,
    int? width,
    int? height,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FloorMap(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, organizationId, name, imagePath, width, height, createdAt, updatedAt];
}
