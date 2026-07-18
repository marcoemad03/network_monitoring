import 'package:json_annotation/json_annotation.dart';
import '../../../domain/entities/reporting/connection_log_entity.dart';

part 'connection_log_model.g.dart';

@JsonSerializable(explicitToJson: true)
class ConnectionLogModel {
  final String id;
  @JsonKey(name: 'organization_id')
  final String organizationId;
  @JsonKey(name: 'device_id')
  final String? deviceId;
  @JsonKey(name: 'user_id')
  final String? userId;
  final String? protocol;
  @JsonKey(name: 'source_ip')
  final String sourceIp;
  @JsonKey(name: 'dest_ip')
  final String destIp;
  @JsonKey(name: 'source_port')
  final int? sourcePort;
  @JsonKey(name: 'dest_port')
  final int? destPort;
  @JsonKey(name: 'bytes_sent')
  final int bytesSent;
  @JsonKey(name: 'bytes_received')
  final int bytesReceived;
  @JsonKey(name: 'packets_sent')
  final int packetsSent;
  @JsonKey(name: 'packets_received')
  final int packetsReceived;
  @JsonKey(name: 'start_time')
  final DateTime startTime;
  @JsonKey(name: 'end_time')
  final DateTime? endTime;
  @JsonKey(name: 'duration_seconds')
  final int durationSeconds;
  @JsonKey(name: 'is_active')
  final bool isActive;
  final String? application;
  final String? department;
  @JsonKey(name: 'device_name')
  final String? deviceName;

  const ConnectionLogModel({
    required this.id,
    required this.organizationId,
    this.deviceId,
    this.userId,
    this.protocol,
    required this.sourceIp,
    required this.destIp,
    this.sourcePort,
    this.destPort,
    this.bytesSent = 0,
    this.bytesReceived = 0,
    this.packetsSent = 0,
    this.packetsReceived = 0,
    required this.startTime,
    this.endTime,
    this.durationSeconds = 0,
    this.isActive = false,
    this.application,
    this.department,
    this.deviceName,
  });

  factory ConnectionLogModel.fromJson(Map<String, dynamic> json) =>
      _$ConnectionLogModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConnectionLogModelToJson(this);

  ConnectionLog toEntity() => ConnectionLog(
        id: id,
        organizationId: organizationId,
        deviceId: deviceId,
        userId: userId,
        protocol: protocol,
        sourceIp: sourceIp,
        destIp: destIp,
        sourcePort: sourcePort,
        destPort: destPort,
        bytesSent: bytesSent,
        bytesReceived: bytesReceived,
        packetsSent: packetsSent,
        packetsReceived: packetsReceived,
        startTime: startTime,
        endTime: endTime,
        durationSeconds: durationSeconds,
        isActive: isActive,
        application: application,
        department: department,
        deviceName: deviceName,
      );

  factory ConnectionLogModel.fromEntity(ConnectionLog entity) =>
      ConnectionLogModel(
        id: entity.id,
        organizationId: entity.organizationId,
        deviceId: entity.deviceId,
        userId: entity.userId,
        protocol: entity.protocol,
        sourceIp: entity.sourceIp,
        destIp: entity.destIp,
        sourcePort: entity.sourcePort,
        destPort: entity.destPort,
        bytesSent: entity.bytesSent,
        bytesReceived: entity.bytesReceived,
        packetsSent: entity.packetsSent,
        packetsReceived: entity.packetsReceived,
        startTime: entity.startTime,
        endTime: entity.endTime,
        durationSeconds: entity.durationSeconds,
        isActive: entity.isActive,
        application: entity.application,
        department: entity.department,
        deviceName: entity.deviceName,
      );
}
