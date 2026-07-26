import 'package:equatable/equatable.dart';

class RouterConnectionStatus extends Equatable {
  final String code;
  final String message;
  final bool reachable;
  final String? apiEndpoint;
  final String? routerName;
  final String? routerVersion;
  final DateTime checkedAt;

  const RouterConnectionStatus({
    required this.code,
    required this.message,
    this.reachable = false,
    this.apiEndpoint,
    this.routerName,
    this.routerVersion,
    required this.checkedAt,
  });

  @override
  List<Object?> get props => [
    code,
    message,
    reachable,
    apiEndpoint,
    routerName,
    routerVersion,
    checkedAt,
  ];
}
