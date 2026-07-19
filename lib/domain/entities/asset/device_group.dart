import 'package:equatable/equatable.dart';

class DeviceGroup extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? parentGroupId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeviceGroup({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.parentGroupId,
    required this.createdAt,
    required this.updatedAt,
  });

  DeviceGroup copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    String? parentGroupId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DeviceGroup(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      parentGroupId: parentGroupId ?? this.parentGroupId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, organizationId, name, description, parentGroupId, createdAt, updatedAt];
}
