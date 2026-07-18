import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/alert_rule_entity.dart';

part 'alert_rule_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AlertRuleModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  final String name;
  final String? description;
  final String metric;
  final String condition;
  final double threshold;
  @JsonKey(name: 'duration_minutes')
  final int durationMinutes;
  final String severity;
  final List<String> channels;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'notify_roles')
  final List<String>? notifyRoles;
  @JsonKey(name: 'cooldown_minutes')
  final int cooldownMinutes;
  @JsonKey(name: 'last_triggered_at')
  final DateTime? lastTriggeredAt;
  @JsonKey(name: 'created_by')
  final String? createdBy;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const AlertRuleModel({
    required this.id,
    required this.organizationId,
    required this.name,
    this.description,
    required this.metric,
    required this.condition,
    required this.threshold,
    this.durationMinutes = 5,
    this.severity = 'warning',
    this.channels = const ['email'],
    this.isActive = true,
    this.notifyRoles,
    this.cooldownMinutes = 30,
    this.lastTriggeredAt,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlertRuleModel.fromJson(Map<String, dynamic> json) =>
      _$AlertRuleModelFromJson(json);

  Map<String, dynamic> toJson() => _$AlertRuleModelToJson(this);

  AlertRule toEntity() => AlertRule(
        id: id,
        organizationId: organizationId,
        name: name,
        description: description,
        metric: metric,
        condition: condition,
        threshold: threshold,
        durationMinutes: durationMinutes,
        severity: severity,
        channels: channels,
        isActive: isActive,
        notifyRoles: notifyRoles,
        cooldownMinutes: cooldownMinutes,
        lastTriggeredAt: lastTriggeredAt,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory AlertRuleModel.fromEntity(AlertRule entity) => AlertRuleModel(
        id: entity.id,
        organizationId: entity.organizationId,
        name: entity.name,
        description: entity.description,
        metric: entity.metric,
        condition: entity.condition,
        threshold: entity.threshold,
        durationMinutes: entity.durationMinutes,
        severity: entity.severity,
        channels: entity.channels,
        isActive: entity.isActive,
        notifyRoles: entity.notifyRoles,
        cooldownMinutes: entity.cooldownMinutes,
        lastTriggeredAt: entity.lastTriggeredAt,
        createdBy: entity.createdBy,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
