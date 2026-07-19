import 'package:equatable/equatable.dart';

class PolicyAssignment extends Equatable {
  final String id;
  final String policyId;
  final String groupId;
  final DateTime createdAt;

  const PolicyAssignment({
    required this.id,
    required this.policyId,
    required this.groupId,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, policyId, groupId, createdAt];
}
