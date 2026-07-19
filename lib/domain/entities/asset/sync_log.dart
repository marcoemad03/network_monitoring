import 'package:equatable/equatable.dart';

class SyncLog extends Equatable {
  final String id;
  final String organizationId;
  final String? vendorIntegrationId;
  final String status;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const SyncLog({
    required this.id,
    required this.organizationId,
    this.vendorIntegrationId,
    required this.status,
    this.details = const {},
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, organizationId, vendorIntegrationId, status, details, createdAt];
}
