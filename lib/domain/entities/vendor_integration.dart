import 'package:equatable/equatable.dart';

class VendorIntegration extends Equatable {
  final String id;
  final String organizationId;
  final String vendorType;
  final String name;
  final String baseUrl;
  final String? username;
  final String? apiVersion;
  final bool isActive;
  final DateTime? lastSyncAt;
  final String? lastSyncStatus;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorIntegration({
    required this.id,
    required this.organizationId,
    required this.vendorType,
    required this.name,
    required this.baseUrl,
    this.username,
    this.apiVersion,
    this.isActive = true,
    this.lastSyncAt,
    this.lastSyncStatus,
    this.errorMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  VendorIntegration copyWith({
    String? id,
    String? organizationId,
    String? vendorType,
    String? name,
    String? baseUrl,
    String? username,
    String? apiVersion,
    bool? isActive,
    DateTime? lastSyncAt,
    String? lastSyncStatus,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorIntegration(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      vendorType: vendorType ?? this.vendorType,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      username: username ?? this.username,
      apiVersion: apiVersion ?? this.apiVersion,
      isActive: isActive ?? this.isActive,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      lastSyncStatus: lastSyncStatus ?? this.lastSyncStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        vendorType,
        name,
        baseUrl,
        username,
        apiVersion,
        isActive,
        lastSyncAt,
        lastSyncStatus,
        errorMessage,
        createdAt,
        updatedAt,
      ];
}
