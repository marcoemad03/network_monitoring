import 'package:equatable/equatable.dart';

enum ScanStatus { pending, running, completed, failed, cancelled }

enum ScanType {
  arp('arp', 'ARP Scan'),
  ping('ping', 'Ping Sweep'),
  port('port', 'Port Scan'),
  snmp('snmp', 'SNMP Scan'),
  topology('topology', 'Topology Discovery'),
  nmap('nmap', 'Nmap Scan');

  final String value;
  final String label;

  const ScanType(this.value, this.label);
}

class NetworkScan extends Equatable {
  final String id;
  final ScanType type;
  final ScanStatus status;
  final String? name;
  final String targetSubnet;
  final List<String> targetIps;
  final String? portRange;
  final List<int>? ports;
  final String? initiatedBy;
  final int totalHosts;
  final int discoveredHosts;
  final int activeHosts;
  final int? durationSeconds;
  final double? progress;
  final String? errorMessage;
  final String? resultSummary;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  const NetworkScan({
    required this.id,
    required this.type,
    required this.status,
    this.name,
    required this.targetSubnet,
    this.targetIps = const [],
    this.portRange,
    this.ports,
    this.initiatedBy,
    this.totalHosts = 0,
    this.discoveredHosts = 0,
    this.activeHosts = 0,
    this.durationSeconds,
    this.progress,
    this.errorMessage,
    this.resultSummary,
    required this.startedAt,
    this.completedAt,
    required this.createdAt,
  });

  NetworkScan copyWith({
    String? id,
    ScanType? type,
    ScanStatus? status,
    String? name,
    String? targetSubnet,
    List<String>? targetIps,
    String? portRange,
    List<int>? ports,
    String? initiatedBy,
    int? totalHosts,
    int? discoveredHosts,
    int? activeHosts,
    int? durationSeconds,
    double? progress,
    String? errorMessage,
    String? resultSummary,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
  }) {
    return NetworkScan(
      id: id ?? this.id,
      type: type ?? this.type,
      status: status ?? this.status,
      name: name ?? this.name,
      targetSubnet: targetSubnet ?? this.targetSubnet,
      targetIps: targetIps ?? this.targetIps,
      portRange: portRange ?? this.portRange,
      ports: ports ?? this.ports,
      initiatedBy: initiatedBy ?? this.initiatedBy,
      totalHosts: totalHosts ?? this.totalHosts,
      discoveredHosts: discoveredHosts ?? this.discoveredHosts,
      activeHosts: activeHosts ?? this.activeHosts,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      resultSummary: resultSummary ?? this.resultSummary,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        status,
        name,
        targetSubnet,
        targetIps,
        portRange,
        ports,
        initiatedBy,
        totalHosts,
        discoveredHosts,
        activeHosts,
        durationSeconds,
        progress,
        errorMessage,
        resultSummary,
        startedAt,
        completedAt,
        createdAt,
      ];
}
