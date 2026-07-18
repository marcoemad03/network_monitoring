import 'package:equatable/equatable.dart';

class ConnectionLog extends Equatable {
  final String id;
  final String organizationId;
  final String? deviceId;
  final String? userId;
  final String? protocol;
  final String sourceIp;
  final String destIp;
  final int? sourcePort;
  final int? destPort;
  final int bytesSent;
  final int bytesReceived;
  final int packetsSent;
  final int packetsReceived;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final bool isActive;
  final String? application;
  final String? department;
  final String? deviceName;

  const ConnectionLog({
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

  ConnectionLog copyWith({
    String? id,
    String? organizationId,
    String? deviceId,
    String? userId,
    String? protocol,
    String? sourceIp,
    String? destIp,
    int? sourcePort,
    int? destPort,
    int? bytesSent,
    int? bytesReceived,
    int? packetsSent,
    int? packetsReceived,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    bool? isActive,
    String? application,
    String? department,
    String? deviceName,
  }) {
    return ConnectionLog(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      protocol: protocol ?? this.protocol,
      sourceIp: sourceIp ?? this.sourceIp,
      destIp: destIp ?? this.destIp,
      sourcePort: sourcePort ?? this.sourcePort,
      destPort: destPort ?? this.destPort,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      packetsSent: packetsSent ?? this.packetsSent,
      packetsReceived: packetsReceived ?? this.packetsReceived,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isActive: isActive ?? this.isActive,
      application: application ?? this.application,
      department: department ?? this.department,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        deviceId,
        userId,
        protocol,
        sourceIp,
        destIp,
        sourcePort,
        destPort,
        bytesSent,
        bytesReceived,
        packetsSent,
        packetsReceived,
        startTime,
        endTime,
        durationSeconds,
        isActive,
        application,
        department,
        deviceName,
      ];
}
