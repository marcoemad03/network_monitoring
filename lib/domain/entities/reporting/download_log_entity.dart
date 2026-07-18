import 'package:equatable/equatable.dart';

class DownloadLog extends Equatable {
  final String id;
  final String organizationId;
  final String? deviceId;
  final String? userId;
  final String filename;
  final String? url;
  final int sizeBytes;
  final String protocol;
  final String? mimeType;
  final DateTime startTime;
  final DateTime? endTime;
  final int durationSeconds;
  final String status;
  final bool isAllowed;
  final String? blockedBy;
  final String? deviceName;
  final String? department;

  const DownloadLog({
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

  DownloadLog copyWith({
    String? id,
    String? organizationId,
    String? deviceId,
    String? userId,
    String? filename,
    String? url,
    int? sizeBytes,
    String? protocol,
    String? mimeType,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    String? status,
    bool? isAllowed,
    String? blockedBy,
    String? deviceName,
    String? department,
  }) {
    return DownloadLog(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      filename: filename ?? this.filename,
      url: url ?? this.url,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      protocol: protocol ?? this.protocol,
      mimeType: mimeType ?? this.mimeType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      isAllowed: isAllowed ?? this.isAllowed,
      blockedBy: blockedBy ?? this.blockedBy,
      deviceName: deviceName ?? this.deviceName,
      department: department ?? this.department,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        deviceId,
        userId,
        filename,
        url,
        sizeBytes,
        protocol,
        mimeType,
        startTime,
        endTime,
        durationSeconds,
        status,
        isAllowed,
        blockedBy,
        deviceName,
        department,
      ];
}
