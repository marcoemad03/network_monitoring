import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/web_log_entity.dart';

part 'web_log_model.g.dart';

@JsonSerializable(explicitToJson: true)
class WebLogModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'user_id')
  final String? userId;
  final String url;
  final String? domain;
  final String? category;
  final DateTime timestamp;
  @JsonKey(name: 'duration_seconds')
  final int durationSeconds;
  @JsonKey(name: 'bytes_sent')
  final int bytesSent;
  @JsonKey(name: 'bytes_received')
  final int bytesReceived;
  @JsonKey(name: 'is_blocked')
  final bool isBlocked;
  @JsonKey(name: 'blocked_by')
  final String? blockedBy;
  @JsonKey(name: 'is_encrypted')
  final bool isEncrypted;
  final String protocol;
  final String method;
  @JsonKey(name: 'content_type')
  final String? contentType;
  @JsonKey(name: 'status_code')
  final int statusCode;
  @JsonKey(name: 'user_agent')
  final String? userAgent;
  @JsonKey(name: 'device_name')
  final String? deviceName;
  final String? department;

  const WebLogModel({
    required this.id,
    required this.organizationId,
    this.deviceId,
    this.userId,
    required this.url,
    this.domain,
    this.category,
    required this.timestamp,
    this.durationSeconds = 0,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.isBlocked = false,
    this.blockedBy,
    this.isEncrypted = false,
    this.protocol = 'HTTPS',
    this.method = 'GET',
    this.contentType,
    this.statusCode = 200,
    this.userAgent,
    this.deviceName,
    this.department,
  });

  factory WebLogModel.fromJson(Map<String, dynamic> json) =>
      _$WebLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$WebLogModelToJson(this);

  WebLog toEntity() => WebLog(
        id: id,
        organizationId: organizationId,
        deviceId: deviceId,
        userId: userId,
        url: url,
        domain: domain,
        category: category,
        timestamp: timestamp,
        durationSeconds: durationSeconds,
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        isBlocked: isBlocked,
        blockedBy: blockedBy,
        isEncrypted: isEncrypted,
        protocol: protocol,
        method: method,
        contentType: contentType,
        statusCode: statusCode,
        userAgent: userAgent,
        deviceName: deviceName,
        department: department,
      );

  factory WebLogModel.fromEntity(WebLog entity) => WebLogModel(
        id: entity.id,
        organizationId: entity.organizationId,
        deviceId: entity.deviceId,
        userId: entity.userId,
        url: entity.url,
        domain: entity.domain,
        category: entity.category,
        timestamp: entity.timestamp,
        durationSeconds: entity.durationSeconds,
        bytesSent: entity.bytesSent,
        bytesReceived: entity.bytesReceived,
        isBlocked: entity.isBlocked,
        blockedBy: entity.blockedBy,
        isEncrypted: entity.isEncrypted,
        protocol: entity.protocol,
        method: entity.method,
        contentType: entity.contentType,
        statusCode: entity.statusCode,
        userAgent: entity.userAgent,
        deviceName: entity.deviceName,
        department: entity.department,
      );
}
