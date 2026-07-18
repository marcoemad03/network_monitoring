import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/alert_notification_entity.dart';

part 'alert_notification_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AlertNotificationModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'rule_id')
  final String? ruleId;
  final String title;
  final String message;
  final String severity;
  @JsonKey(name: 'metric_name')
  final String? metricName;
  @JsonKey(name: 'metric_value')
  final double? metricValue;
  final double? threshold;
  @JsonKey(name: 'triggered_at')
  final DateTime triggeredAt;
  @JsonKey(name: 'acknowledged_at')
  final DateTime? acknowledgedAt;
  @JsonKey(name: 'acknowledged_by')
  final String? acknowledgedBy;
  @JsonKey(name: 'is_read')
  final bool isRead;
  final String channel;

  const AlertNotificationModel({
    required this.id,
    required this.organizationId,
    this.ruleId,
    required this.title,
    required this.message,
    this.severity = 'warning',
    this.metricName,
    this.metricValue,
    this.threshold,
    required this.triggeredAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.isRead = false,
    this.channel = 'email',
  });

  factory AlertNotificationModel.fromJson(Map<String, dynamic> json) =>
      _$AlertNotificationModelFromJson(json);

  Map<String, dynamic> toJson() => _$AlertNotificationModelToJson(this);

  AlertNotification toEntity() => AlertNotification(
        id: id,
        organizationId: organizationId,
        ruleId: ruleId,
        title: title,
        message: message,
        severity: severity,
        metricName: metricName,
        metricValue: metricValue,
        threshold: threshold,
        triggeredAt: triggeredAt,
        acknowledgedAt: acknowledgedAt,
        acknowledgedBy: acknowledgedBy,
        isRead: isRead,
        channel: channel,
      );

  factory AlertNotificationModel.fromEntity(AlertNotification entity) =>
      AlertNotificationModel(
        id: entity.id,
        organizationId: entity.organizationId,
        ruleId: entity.ruleId,
        title: entity.title,
        message: entity.message,
        severity: entity.severity,
        metricName: entity.metricName,
        metricValue: entity.metricValue,
        threshold: entity.threshold,
        triggeredAt: entity.triggeredAt,
        acknowledgedAt: entity.acknowledgedAt,
        acknowledgedBy: entity.acknowledgedBy,
        isRead: entity.isRead,
        channel: entity.channel,
      );
}
