import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/filtering_rule.dart';

part 'filtering_rule_model.g.dart';

@JsonSerializable(explicitToJson: true)
class FilteringRuleModel {
  final String id;
  @JsonKey(name: 'policy_id')
  final String policyId;
  @JsonKey(name: 'rule_type')
  final String ruleType;
  @JsonKey(name: 'filter_type')
  final String filterType;
  final String value;
  final String? description;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const FilteringRuleModel({
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

  factory FilteringRuleModel.fromJson(Map<String, dynamic> json) =>
      _$FilteringRuleModelFromJson(json);

  Map<String, dynamic> toJson() => _$FilteringRuleModelToJson(this);

  FilteringRule toEntity() => FilteringRule(
        id: id,
        policyId: policyId,
        ruleType: ruleType,
        filterType: filterType,
        value: value,
        description: description,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory FilteringRuleModel.fromEntity(FilteringRule entity) =>
      FilteringRuleModel(
        id: entity.id,
        policyId: entity.policyId,
        ruleType: entity.ruleType,
        filterType: entity.filterType,
        value: entity.value,
        description: entity.description,
        isActive: entity.isActive,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
