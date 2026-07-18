import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/alert.dart';
import '../../core/enums/alert_severity.dart';

part 'alert_model.g.dart';

@JsonSerializable(explicitToJson: true)
class AlertModel {
  final String id;
  final String title;
  final String description;
  final String severity;
  final String status;
  final String category;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'device_name')
  final String? deviceName;
  @JsonKey(name: 'interface_id')
  final String? interfaceId;
  @JsonKey(name: 'interface_name')
  final String? interfaceName;
  @JsonKey(name: 'metric_name')
  final String? metricName;
  @JsonKey(name: 'metric_value')
  final double? metricValue;
  @JsonKey(name: 'threshold_value')
  final double? thresholdValue;
  @JsonKey(name: 'rule_id')
  final String? ruleId;
  @JsonKey(name: 'acknowledged_by')
  final String? acknowledgedBy;
  @JsonKey(name: 'acknowledged_at')
  final DateTime? acknowledgedAt;
  @JsonKey(name: 'resolved_by')
  final String? resolvedBy;
  @JsonKey(name: 'resolved_at')
  final DateTime? resolvedAt;
  @JsonKey(name: 'resolution_notes')
  final String? resolutionNotes;
  @JsonKey(name: 'occurrence_count')
  final int occurrenceCount;
  @JsonKey(name: 'is_suppressed')
  final bool isSuppressed;
  @JsonKey(name: 'suppressed_until')
  final DateTime? suppressedUntil;
  @JsonKey(name: 'detected_at')
  final DateTime detectedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  const AlertModel({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.category,
    this.deviceId,
    this.deviceName,
    this.interfaceId,
    this.interfaceName,
    this.metricName,
    this.metricValue,
    this.thresholdValue,
    this.ruleId,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.resolvedBy,
    this.resolvedAt,
    this.resolutionNotes,
    this.occurrenceCount = 1,
    this.isSuppressed = false,
    this.suppressedUntil,
    required this.detectedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AlertModel.fromJson(Map<String, dynamic> json) =>
      _$AlertModelFromJson(json);

  Map<String, dynamic> toJson() => _$AlertModelToJson(this);

  Alert toEntity() => Alert(
        id: id,
        title: title,
        description: description,
        severity: AlertSeverity.fromValue(severity),
        status: AlertStatus.values.firstWhere(
          (s) => s.name == status,
          orElse: () => AlertStatus.open,
        ),
        category: AlertCategory.values.firstWhere(
          (c) => c.name == category,
          orElse: () => AlertCategory.other,
        ),
        deviceId: deviceId,
        deviceName: deviceName,
        interfaceId: interfaceId,
        interfaceName: interfaceName,
        metricName: metricName,
        metricValue: metricValue,
        thresholdValue: thresholdValue,
        ruleId: ruleId,
        acknowledgedBy: acknowledgedBy,
        acknowledgedAt: acknowledgedAt,
        resolvedBy: resolvedBy,
        resolvedAt: resolvedAt,
        resolutionNotes: resolutionNotes,
        occurrenceCount: occurrenceCount,
        isSuppressed: isSuppressed,
        suppressedUntil: suppressedUntil,
        detectedAt: detectedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory AlertModel.fromEntity(Alert entity) => AlertModel(
        id: entity.id,
        title: entity.title,
        description: entity.description,
        severity: entity.severity.value,
        status: entity.status.name,
        category: entity.category.name,
        deviceId: entity.deviceId,
        deviceName: entity.deviceName,
        interfaceId: entity.interfaceId,
        interfaceName: entity.interfaceName,
        metricName: entity.metricName,
        metricValue: entity.metricValue,
        thresholdValue: entity.thresholdValue,
        ruleId: entity.ruleId,
        acknowledgedBy: entity.acknowledgedBy,
        acknowledgedAt: entity.acknowledgedAt,
        resolvedBy: entity.resolvedBy,
        resolvedAt: entity.resolvedAt,
        resolutionNotes: entity.resolutionNotes,
        occurrenceCount: entity.occurrenceCount,
        isSuppressed: entity.isSuppressed,
        suppressedUntil: entity.suppressedUntil,
        detectedAt: entity.detectedAt,
        createdAt: entity.createdAt,
        updatedAt: entity.updatedAt,
      );
}
