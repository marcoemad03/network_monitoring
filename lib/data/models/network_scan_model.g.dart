// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_scan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

NetworkScanModel _$NetworkScanModelFromJson(Map<String, dynamic> json) =>
    NetworkScanModel(
      id: json['id'] as String,
      type: json['type'] as String,
      status: json['status'] as String,
      name: json['name'] as String?,
      targetSubnet: json['target_subnet'] as String,
      targetIps:
          (json['target_ips'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      portRange: json['port_range'] as String?,
      ports:
          (json['ports'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList(),
      initiatedBy: json['initiated_by'] as String?,
      totalHosts: (json['total_hosts'] as num?)?.toInt() ?? 0,
      discoveredHosts: (json['discovered_hosts'] as num?)?.toInt() ?? 0,
      activeHosts: (json['active_hosts'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      progress: (json['progress'] as num?)?.toDouble(),
      errorMessage: json['error_message'] as String?,
      resultSummary: json['result_summary'] as String?,
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt:
          json['completed_at'] == null
              ? null
              : DateTime.parse(json['completed_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$NetworkScanModelToJson(NetworkScanModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'status': instance.status,
      'name': instance.name,
      'target_subnet': instance.targetSubnet,
      'target_ips': instance.targetIps,
      'port_range': instance.portRange,
      'ports': instance.ports,
      'initiated_by': instance.initiatedBy,
      'total_hosts': instance.totalHosts,
      'discovered_hosts': instance.discoveredHosts,
      'active_hosts': instance.activeHosts,
      'duration_seconds': instance.durationSeconds,
      'progress': instance.progress,
      'error_message': instance.errorMessage,
      'result_summary': instance.resultSummary,
      'started_at': instance.startedAt.toIso8601String(),
      'completed_at': instance.completedAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
    };
