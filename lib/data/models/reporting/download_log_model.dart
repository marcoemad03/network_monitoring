import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/reporting/download_log_entity.dart';

part 'download_log_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DownloadLogModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'user_id')
  final String? userId;
  final String filename;
  final String? url;
  @JsonKey(name: 'size_bytes')
  final int sizeBytes;
  final String protocol;
  @JsonKey(name: 'mime_type')
  final String? mimeType;
  @JsonKey(name: 'start_time')
  final DateTime startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  @JsonKey(name: 'duration_seconds')
  final int durationSeconds;
  final String status;
  @JsonKey(name: 'is_allowed')
  final bool isAllowed;
  @JsonKey(name: 'blocked_by')
  final String? blockedBy;
  @JsonKey(name: 'device_name')
  final String? deviceName;
  final String? department;

  const DownloadLogModel({
    required this.id,
    required this.organizationId,
    this.deviceId,
    this.userId,
    required this.filename,
    this.url,
    this.sizeBytes = 0,
    this.protocol = 'HTTPS',
    this.mimeType,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.status = 'completed',
    this.isAllowed = true,
    this.blockedBy,
    this.deviceName,
    this.department,
  });

  factory DownloadLogModel.fromJson(Map<String, dynamic> json) =>
      _$DownloadLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$DownloadLogModelToJson(this);

  DownloadLog toEntity() => DownloadLog(
        id: id,
        organizationId: organizationId,
        deviceId: deviceId,
        userId: userId,
        filename: filename,
        url: url,
        sizeBytes: sizeBytes,
        protocol: protocol,
        mimeType: mimeType,
        startTime: startTime,
        endTime: endTime,
        durationSeconds: durationSeconds,
        status: status,
        isAllowed: isAllowed,
        blockedBy: blockedBy,
        deviceName: deviceName,
        department: department,
      );

  factory DownloadLogModel.fromEntity(DownloadLog entity) =>
      DownloadLogModel(
        id: entity.id,
        organizationId: entity.organizationId,
        deviceId: entity.deviceId,
        userId: entity.userId,
        filename: entity.filename,
        url: entity.url,
        sizeBytes: entity.sizeBytes,
        protocol: entity.protocol,
        mimeType: entity.mimeType,
        startTime: entity.startTime,
        endTime: entity.endTime,
        durationSeconds: entity.durationSeconds,
        status: entity.status,
        isAllowed: entity.isAllowed,
        blockedBy: entity.blockedBy,
        deviceName: entity.deviceName,
        department: entity.department,
      );
}
