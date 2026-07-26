import '../../domain/entities/router_connection_status.dart';

class RouterConnectionStatusModel {
  final String code;
  final String message;
  final bool reachable;
  final String? apiEndpoint;
  final String? routerName;
  final String? routerVersion;
  final DateTime checkedAt;

  const RouterConnectionStatusModel({
    required this.code,
    required this.message,
    required this.reachable,
    this.apiEndpoint,
    this.routerName,
    this.routerVersion,
    required this.checkedAt,
  });

  factory RouterConnectionStatusModel.fromJson(Map<String, dynamic> json) =>
      RouterConnectionStatusModel(
        code: json['code']?.toString() ?? 'UNKNOWN',
        message: json['message']?.toString() ?? 'Unknown RouterOS status',
        reachable: json['reachable'] == true,
        apiEndpoint: json['api_endpoint']?.toString(),
        routerName: json['router_name']?.toString(),
        routerVersion: json['router_version']?.toString(),
        checkedAt:
            DateTime.tryParse(json['checked_at']?.toString() ?? '') ??
            DateTime.now(),
      );

  RouterConnectionStatus toEntity() => RouterConnectionStatus(
    code: code,
    message: message,
    reachable: reachable,
    apiEndpoint: apiEndpoint,
    routerName: routerName,
    routerVersion: routerVersion,
    checkedAt: checkedAt,
  );
}
