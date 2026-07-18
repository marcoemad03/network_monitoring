import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/report_entity.dart';

part 'report_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ReportModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'report_type')
  final String reportType;
  @JsonKey(name: 'period_start')
  final DateTime periodStart;
  @JsonKey(name: 'period_end')
  final DateTime periodEnd;
  @JsonKey(fromJson: _stringToMap, toJson: _mapToString)
  final Map<String, dynamic> data;
  @JsonKey(name: 'total_websites')
  final int totalWebsites;
  @JsonKey(name: 'total_bandwidth_mb')
  final int totalBandwidthMb;
  @JsonKey(name: 'total_duration_minutes')
  final int totalDurationMinutes;
  @JsonKey(name: 'unique_devices')
  final int uniqueDevices;
  @JsonKey(name: 'unique_users')
  final int uniqueUsers;
  @JsonKey(name: 'blocked_attempts')
  final int blockedAttempts;
  @JsonKey(name: 'generated_at')
  final DateTime generatedAt;

  const ReportModel({
    required this.id,
    required this.organizationId,
    required this.reportType,
    required this.periodStart,
    required this.periodEnd,
    this.data = const {},
    this.totalWebsites = 0,
    this.totalBandwidthMb = 0,
    this.totalDurationMinutes = 0,
    this.uniqueDevices = 0,
    this.uniqueUsers = 0,
    this.blockedAttempts = 0,
    required this.generatedAt,
  });

  static Map<String, dynamic> _stringToMap(dynamic json) =>
      json is String
          ? Map<String, dynamic>.from(jsonDecode(json) as Map)
          : (json as Map<String, dynamic>);

  static String _mapToString(Map<String, dynamic> map) => jsonEncode(map);

  factory ReportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReportModelToJson(this);

  Report toEntity() => Report(
        id: id,
        organizationId: organizationId,
        reportType: reportType,
        periodStart: periodStart,
        periodEnd: periodEnd,
        data: data,
        totalWebsites: totalWebsites,
        totalBandwidthMb: totalBandwidthMb,
        totalDurationMinutes: totalDurationMinutes,
        uniqueDevices: uniqueDevices,
        uniqueUsers: uniqueUsers,
        blockedAttempts: blockedAttempts,
        generatedAt: generatedAt,
      );

  factory ReportModel.fromEntity(Report entity) => ReportModel(
        id: entity.id,
        organizationId: entity.organizationId,
        reportType: entity.reportType,
        periodStart: entity.periodStart,
        periodEnd: entity.periodEnd,
        data: entity.data,
        totalWebsites: entity.totalWebsites,
        totalBandwidthMb: entity.totalBandwidthMb,
        totalDurationMinutes: entity.totalDurationMinutes,
        uniqueDevices: entity.uniqueDevices,
        uniqueUsers: entity.uniqueUsers,
        blockedAttempts: entity.blockedAttempts,
        generatedAt: entity.generatedAt,
      );
}
