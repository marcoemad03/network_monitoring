import 'package:equatable/equatable.dart';

class Policy extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String policyType;
  final Map<String, dynamic> config;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Policy({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    required this.policyType,
    this.config = const {},
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Policy copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    String? policyType,
    Map<String, dynamic>? config,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Policy(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      policyType: policyType ?? this.policyType,
      config: config ?? this.config,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, organizationId, name, description, policyType, config, isActive, createdAt, updatedAt];
}
