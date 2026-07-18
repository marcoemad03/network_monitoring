import 'package:equatable/equatable.dart';

class BandwidthRule extends Equatable {
  final String id;
  final String policyId;
  final String? deviceId;
  final String? userId;
  final int priority;
  final int? uploadLimitBps;
  final int? downloadLimitBps;
  final String ruleType;
  final bool isTemporary;
  final DateTime? tempExpiresAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BandwidthRule({
    required this.id,
    required this.policyId,
    this.deviceId,
    this.userId,
    this.priority = 500,
    this.uploadLimitBps,
    this.downloadLimitBps,
    required this.ruleType,
    this.isTemporary = false,
    this.tempExpiresAt,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  BandwidthRule copyWith({
    String? id,
    String? policyId,
    String? deviceId,
    String? userId,
    int? priority,
    int? uploadLimitBps,
    int? downloadLimitBps,
    String? ruleType,
    bool? isTemporary,
    DateTime? tempExpiresAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BandwidthRule(
      id: id ?? this.id,
      policyId: policyId ?? this.policyId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      priority: priority ?? this.priority,
      uploadLimitBps: uploadLimitBps ?? this.uploadLimitBps,
      downloadLimitBps: downloadLimitBps ?? this.downloadLimitBps,
      ruleType: ruleType ?? this.ruleType,
      isTemporary: isTemporary ?? this.isTemporary,
      tempExpiresAt: tempExpiresAt ?? this.tempExpiresAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        policyId,
        deviceId,
        userId,
        priority,
        uploadLimitBps,
        downloadLimitBps,
        ruleType,
        isTemporary,
        tempExpiresAt,
        isActive,
        createdAt,
        updatedAt,
      ];
}
