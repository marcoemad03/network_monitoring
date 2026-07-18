import 'package:equatable/equatable.dart';

class WebLog extends Equatable {
  final String id;
  final String organizationId;
  final String? deviceId;
  final String? userId;
  final String url;
  final String? domain;
  final String? category;
  final DateTime timestamp;
  final int durationSeconds;
  final int bytesSent;
  final int bytesReceived;
  final bool isBlocked;
  final String? blockedBy;
  final bool isEncrypted;
  final String protocol;
  final String method;
  final String? contentType;
  final int statusCode;
  final String? userAgent;
  final String? deviceName;
  final String? department;

  const WebLog({
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

  WebLog copyWith({
    String? id,
    String? organizationId,
    String? deviceId,
    String? userId,
    String? url,
    String? domain,
    String? category,
    DateTime? timestamp,
    int? durationSeconds,
    int? bytesSent,
    int? bytesReceived,
    bool? isBlocked,
    String? blockedBy,
    bool? isEncrypted,
    String? protocol,
    String? method,
    String? contentType,
    int? statusCode,
    String? userAgent,
    String? deviceName,
    String? department,
  }) {
    return WebLog(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      deviceId: deviceId ?? this.deviceId,
      userId: userId ?? this.userId,
      url: url ?? this.url,
      domain: domain ?? this.domain,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      bytesSent: bytesSent ?? this.bytesSent,
      bytesReceived: bytesReceived ?? this.bytesReceived,
      isBlocked: isBlocked ?? this.isBlocked,
      blockedBy: blockedBy ?? this.blockedBy,
      isEncrypted: isEncrypted ?? this.isEncrypted,
      protocol: protocol ?? this.protocol,
      method: method ?? this.method,
      contentType: contentType ?? this.contentType,
      statusCode: statusCode ?? this.statusCode,
      userAgent: userAgent ?? this.userAgent,
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
        url,
        domain,
        category,
        timestamp,
        durationSeconds,
        bytesSent,
        bytesReceived,
        isBlocked,
        blockedBy,
        isEncrypted,
        protocol,
        method,
        contentType,
        statusCode,
        userAgent,
        deviceName,
        department,
      ];
}
