import 'package:equatable/equatable.dart';
import '../../core/enums/alert_severity.dart';

enum AlertStatus { open, acknowledged, resolved, suppressed }

enum AlertCategory {
  connectivity,
  performance,
  security,
  hardware,
  configuration,
  capacity,
  environmental,
  other
}

class Alert extends Equatable {
  final String id;
  final String title;
  final String description;
  final AlertSeverity severity;
  final AlertStatus status;
  final AlertCategory category;
  final String? deviceId;
  final String? deviceName;
  final String? interfaceId;
  final String? interfaceName;
  final String? metricName;
  final double? metricValue;
  final double? thresholdValue;
  final String? ruleId;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? resolutionNotes;
  final int occurrenceCount;
  final bool isSuppressed;
  final DateTime? suppressedUntil;
  final DateTime detectedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Alert({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    this.status = AlertStatus.open,
    this.category = AlertCategory.other,
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

  Alert copyWith({
    String? id,
    String? title,
    String? description,
    AlertSeverity? severity,
    AlertStatus? status,
    AlertCategory? category,
    String? deviceId,
    String? deviceName,
    String? interfaceId,
    String? interfaceName,
    String? metricName,
    double? metricValue,
    double? thresholdValue,
    String? ruleId,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    String? resolvedBy,
    DateTime? resolvedAt,
    String? resolutionNotes,
    int? occurrenceCount,
    bool? isSuppressed,
    DateTime? suppressedUntil,
    DateTime? detectedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Alert(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      status: status ?? this.status,
      category: category ?? this.category,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      interfaceId: interfaceId ?? this.interfaceId,
      interfaceName: interfaceName ?? this.interfaceName,
      metricName: metricName ?? this.metricName,
      metricValue: metricValue ?? this.metricValue,
      thresholdValue: thresholdValue ?? this.thresholdValue,
      ruleId: ruleId ?? this.ruleId,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolutionNotes: resolutionNotes ?? this.resolutionNotes,
      occurrenceCount: occurrenceCount ?? this.occurrenceCount,
      isSuppressed: isSuppressed ?? this.isSuppressed,
      suppressedUntil: suppressedUntil ?? this.suppressedUntil,
      detectedAt: detectedAt ?? this.detectedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        severity,
        status,
        category,
        deviceId,
        deviceName,
        interfaceId,
        interfaceName,
        metricName,
        metricValue,
        thresholdValue,
        ruleId,
        acknowledgedBy,
        acknowledgedAt,
        resolvedBy,
        resolvedAt,
        resolutionNotes,
        occurrenceCount,
        isSuppressed,
        suppressedUntil,
        detectedAt,
        createdAt,
        updatedAt,
      ];
}
