import 'package:equatable/equatable.dart';

class Report extends Equatable {
  final String id;
  final String organizationId;
  final String reportType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Map<String, dynamic> data;
  final int totalWebsites;
  final int totalBandwidthMb;
  final int totalDurationMinutes;
  final int uniqueDevices;
  final int uniqueUsers;
  final int blockedAttempts;
  final DateTime generatedAt;

  const Report({
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

  Report copyWith({
    String? id,
    String? organizationId,
    String? reportType,
    DateTime? periodStart,
    DateTime? periodEnd,
    Map<String, dynamic>? data,
    int? totalWebsites,
    int? totalBandwidthMb,
    int? totalDurationMinutes,
    int? uniqueDevices,
    int? uniqueUsers,
    int? blockedAttempts,
    DateTime? generatedAt,
  }) {
    return Report(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      reportType: reportType ?? this.reportType,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      data: data ?? this.data,
      totalWebsites: totalWebsites ?? this.totalWebsites,
      totalBandwidthMb: totalBandwidthMb ?? this.totalBandwidthMb,
      totalDurationMinutes: totalDurationMinutes ?? this.totalDurationMinutes,
      uniqueDevices: uniqueDevices ?? this.uniqueDevices,
      uniqueUsers: uniqueUsers ?? this.uniqueUsers,
      blockedAttempts: blockedAttempts ?? this.blockedAttempts,
      generatedAt: generatedAt ?? this.generatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        reportType,
        periodStart,
        periodEnd,
        data,
        totalWebsites,
        totalBandwidthMb,
        totalDurationMinutes,
        uniqueDevices,
        uniqueUsers,
        blockedAttempts,
        generatedAt,
      ];
}
