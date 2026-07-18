// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_traffic_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceTrafficModel _$DeviceTrafficModelFromJson(Map<String, dynamic> json) =>
    DeviceTrafficModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      interfaceId: json['interface_id'] as String?,
      uploadBps: (json['upload_bps'] as num?)?.toInt() ?? 0,
      downloadBps: (json['download_bps'] as num?)?.toInt() ?? 0,
      totalUploadBytes: (json['total_upload_bytes'] as num?)?.toInt() ?? 0,
      totalDownloadBytes: (json['total_download_bytes'] as num?)?.toInt() ?? 0,
      uploadPackets: (json['upload_packets'] as num?)?.toInt() ?? 0,
      downloadPackets: (json['download_packets'] as num?)?.toInt() ?? 0,
      uploadErrors: (json['upload_errors'] as num?)?.toInt() ?? 0,
      downloadErrors: (json['download_errors'] as num?)?.toInt() ?? 0,
      utilizationPercent: (json['utilization_percent'] as num?)?.toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );

Map<String, dynamic> _$DeviceTrafficModelToJson(DeviceTrafficModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'interface_id': instance.interfaceId,
      'upload_bps': instance.uploadBps,
      'download_bps': instance.downloadBps,
      'total_upload_bytes': instance.totalUploadBytes,
      'total_download_bytes': instance.totalDownloadBytes,
      'upload_packets': instance.uploadPackets,
      'download_packets': instance.downloadPackets,
      'upload_errors': instance.uploadErrors,
      'download_errors': instance.downloadErrors,
      'utilization_percent': instance.utilizationPercent,
      'timestamp': instance.timestamp.toIso8601String(),
    };
