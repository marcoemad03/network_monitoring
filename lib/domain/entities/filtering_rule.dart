import 'package:equatable/equatable.dart';

class FilteringRule extends Equatable {
  final String id;
  final String policyId;
  final String ruleType;
  final String filterType;
  final String value;
  final String? description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FilteringRule({
    required this.id,
    required this.policyId,
    required this.ruleType,
    required this.filterType,
    required this.value,
    this.description,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  FilteringRule copyWith({
    String? id,
    String? policyId,
    String? ruleType,
    String? filterType,
    String? value,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FilteringRule(
      id: id ?? this.id,
      policyId: policyId ?? this.policyId,
      ruleType: ruleType ?? this.ruleType,
      filterType: filterType ?? this.filterType,
      value: value ?? this.value,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        policyId,
        ruleType,
        filterType,
        value,
        description,
        isActive,
        createdAt,
        updatedAt,
      ];
}
