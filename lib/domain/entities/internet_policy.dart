import 'package:equatable/equatable.dart';

class InternetPolicy extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String? department;
  final bool isActive;
  final int? uploadLimitBps;
  final int? downloadLimitBps;
  final String policyType;
  final int priority;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const InternetPolicy({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    this.department,
    this.isActive = true,
    this.uploadLimitBps,
    this.downloadLimitBps,
    required this.policyType,
    this.priority = 500,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  InternetPolicy copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    String? department,
    bool? isActive,
    int? uploadLimitBps,
    int? downloadLimitBps,
    String? policyType,
    int? priority,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InternetPolicy(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      department: department ?? this.department,
      isActive: isActive ?? this.isActive,
      uploadLimitBps: uploadLimitBps ?? this.uploadLimitBps,
      downloadLimitBps: downloadLimitBps ?? this.downloadLimitBps,
      policyType: policyType ?? this.policyType,
      priority: priority ?? this.priority,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        name,
        description,
        department,
        isActive,
        uploadLimitBps,
        downloadLimitBps,
        policyType,
        priority,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
