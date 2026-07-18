import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/reporting/report_export_entity.dart';

part 'report_export_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ReportExportModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'report_type')
  final String reportType;
  @JsonKey(name: 'period_start')
  final DateTime periodStart;
  @JsonKey(name: 'period_end')
  final DateTime periodEnd;
  final String format;
  @JsonKey(name: 'file_path')
  final String? filePath;
  @JsonKey(name: 'file_size_bytes')
  final int fileSizeBytes;
  final String status;
  @JsonKey(name: 'generated_by')
  final String? generatedBy;
  @JsonKey(name: 'generated_at')
  final DateTime? generatedAt;
  @JsonKey(name: 'expires_at')
  final DateTime? expiresAt;

  const ReportExportModel({
    required this.id,
    required this.organizationId,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    required this.format,
    this.filePath,
    this.fileSizeBytes = 0,
    this.status = 'pending',
    this.generatedBy,
    this.generatedAt,
    this.expiresAt,
  });

  factory ReportExportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportExportModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReportExportModelToJson(this);

  ReportExport toEntity() => ReportExport(
        id: id,
        organizationId: organizationId,
        reportType: reportType,
        periodStart: periodStart,
        periodEnd: periodEnd,
        format: format,
        filePath: filePath,
        fileSizeBytes: fileSizeBytes,
        status: status,
        generatedBy: generatedBy,
        generatedAt: generatedAt,
        expiresAt: expiresAt,
      );

  factory ReportExportModel.fromEntity(ReportExport entity) =>
      ReportExportModel(
        id: entity.id,
        organizationId: entity.organizationId,
        reportType: entity.reportType,
        periodStart: entity.periodStart,
        periodEnd: entity.periodEnd,
        format: entity.format,
        filePath: entity.filePath,
        fileSizeBytes: entity.fileSizeBytes,
        status: entity.status,
        generatedBy: entity.generatedBy,
        generatedAt: entity.generatedAt,
        expiresAt: entity.expiresAt,
      );
}
