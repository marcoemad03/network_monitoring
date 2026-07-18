import 'package:equatable/equatable.dart';

class ReportExport extends Equatable {
  final String id;
  final String organizationId;
  final String reportType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String format;
  final String? filePath;
  final int fileSizeBytes;
  final String status;
  final String? generatedBy;
  final DateTime? generatedAt;
  final DateTime? expiresAt;

  const ReportExport({
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

  ReportExport copyWith({
    String? id,
    String? organizationId,
    String? reportType,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? format,
    String? filePath,
    int? fileSizeBytes,
    String? status,
    String? generatedBy,
    DateTime? generatedAt,
    DateTime? expiresAt,
  }) {
    return ReportExport(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      reportType: reportType ?? this.reportType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      format: format ?? this.format,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      generatedBy: generatedBy ?? this.generatedBy,
      generatedAt: generatedAt ?? this.generatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        reportType,
        periodStart,
        periodEnd,
        format,
        filePath,
        fileSizeBytes,
        status,
        generatedBy,
        generatedAt,
        expiresAt,
      ];
}
