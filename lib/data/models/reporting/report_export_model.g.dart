// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_export_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReportExportModel _$ReportExportModelFromJson(Map<String, dynamic> json) =>
    ReportExportModel(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      reportType: json['report_type'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      format: json['format'] as String,
      filePath: json['file_path'] as String?,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'pending',
      generatedBy: json['generated_by'] as String?,
      generatedAt:
          json['generated_at'] == null
              ? null
              : DateTime.parse(json['generated_at'] as String),
      expiresAt:
          json['expires_at'] == null
              ? null
              : DateTime.parse(json['expires_at'] as String),
    );

Map<String, dynamic> _$ReportExportModelToJson(ReportExportModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'organization_id': instance.organizationId,
      'report_type': instance.reportType,
      'period_start': instance.periodStart.toIso8601String(),
      'period_end': instance.periodEnd.toIso8601String(),
      'format': instance.format,
      'file_path': instance.filePath,
      'file_size_bytes': instance.fileSizeBytes,
      'status': instance.status,
      'generated_by': instance.generatedBy,
      'generated_at': instance.generatedAt?.toIso8601String(),
      'expires_at': instance.expiresAt?.toIso8601String(),
    };
