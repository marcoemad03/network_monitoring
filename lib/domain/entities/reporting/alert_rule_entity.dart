import 'package:equatable/equatable.dart';

class AlertRule extends Equatable {
  final String id;
  final String organizationId;
  final String name;
  final String? description;
  final String metric;
  final String condition;
  final double threshold;
  final int durationMinutes;
  final String severity;
  final List<String> channels;
  final bool isActive;
  final List<String>? notifyRoles;
  final int cooldownMinutes;
  final DateTime? lastTriggeredAt;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AlertRule({
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

  AlertRule copyWith({
    String? id,
    String? organizationId,
    String? name,
    String? description,
    String? metric,
    String? condition,
    double? threshold,
    int? durationMinutes,
    String? severity,
    List<String>? channels,
    bool? isActive,
    List<String>? notifyRoles,
    int? cooldownMinutes,
    DateTime? lastTriggeredAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AlertRule(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      name: name ?? this.name,
      description: description ?? this.description,
      metric: metric ?? this.metric,
      condition: condition ?? this.condition,
      threshold: threshold ?? this.threshold,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      severity: severity ?? this.severity,
      channels: channels ?? this.channels,
      isActive: isActive ?? this.isActive,
      notifyRoles: notifyRoles ?? this.notifyRoles,
      cooldownMinutes: cooldownMinutes ?? this.cooldownMinutes,
      lastTriggeredAt: lastTriggeredAt ?? this.lastTriggeredAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        name,
        description,
        metric,
        condition,
        threshold,
        durationMinutes,
        severity,
        channels,
        isActive,
        notifyRoles,
        cooldownMinutes,
        lastTriggeredAt,
        createdBy,
        createdAt,
        updatedAt,
      ];
}
