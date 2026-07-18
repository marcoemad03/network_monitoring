import 'package:equatable/equatable.dart';

class AlertNotification extends Equatable {
  final String id;
  final String organizationId;
  final String? ruleId;
  final String title;
  final String message;
  final String severity;
  final String? metricName;
  final double? metricValue;
  final double? threshold;
  final DateTime triggeredAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final bool isRead;
  final String channel;

  const AlertNotification({
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

  AlertNotification copyWith({
    String? id,
    String? organizationId,
    String? ruleId,
    String? title,
    String? message,
    String? severity,
    String? metricName,
    double? metricValue,
    double? threshold,
    DateTime? triggeredAt,
    DateTime? acknowledgedAt,
    String? acknowledgedBy,
    bool? isRead,
    String? channel,
  }) {
    return AlertNotification(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      ruleId: ruleId ?? this.ruleId,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      metricName: metricName ?? this.metricName,
      metricValue: metricValue ?? this.metricValue,
      threshold: threshold ?? this.threshold,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      isRead: isRead ?? this.isRead,
      channel: channel ?? this.channel,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        ruleId,
        title,
        message,
        severity,
        metricName,
        metricValue,
        threshold,
        triggeredAt,
        acknowledgedAt,
        acknowledgedBy,
        isRead,
        channel,
      ];
}
