// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportModel _$ReportModelFromJson(Map<String, dynamic> json) => ReportModel(
  id: json['id'] as String,
  organizationId: json['organization_id'] as String,
  reportType: json['report_type'] as String,
  periodStart: DateTime.parse(json['period_start'] as String),
  periodEnd: DateTime.parse(json['period_end'] as String),
  data:
      json['data'] == null ? const {} : ReportModel._stringToMap(json['data']),
  totalWebsites: (json['total_websites'] as num?)?.toInt() ?? 0,
  totalBandwidthMb: (json['total_bandwidth_mb'] as num?)?.toInt() ?? 0,
  totalDurationMinutes: (json['total_duration_minutes'] as num?)?.toInt() ?? 0,
  uniqueDevices: (json['unique_devices'] as num?)?.toInt() ?? 0,
  uniqueUsers: (json['unique_users'] as num?)?.toInt() ?? 0,
  blockedAttempts: (json['blocked_attempts'] as num?)?.toInt() ?? 0,
  generatedAt: DateTime.parse(json['generated_at'] as String),
);

Map<String, dynamic> _$ReportModelToJson(ReportModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'report_type': instance.reportType,
      'period_start': instance.periodStart.toIso8601String(),
      'period_end': instance.periodEnd.toIso8601String(),
      'data': ReportModel._mapToString(instance.data),
      'total_websites': instance.totalWebsites,
      'total_bandwidth_mb': instance.totalBandwidthMb,
      'total_duration_minutes': instance.totalDurationMinutes,
      'unique_devices': instance.uniqueDevices,
      'unique_users': instance.uniqueUsers,
      'blocked_attempts': instance.blockedAttempts,
      'generated_at': instance.generatedAt.toIso8601String(),
    };
