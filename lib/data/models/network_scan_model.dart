import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/network_scan.dart';

part 'network_scan_model.g.dart';

@JsonSerializable(explicitToJson: true)
class NetworkScanModel {
  final String id;
  final String type;
  final String status;
  final String? name;
  @JsonKey(name: 'target_subnet')
  final String targetSubnet;
  @JsonKey(name: 'target_ips')
  final List<String>? targetIps;
  @JsonKey(name: 'port_range')
  final String? portRange;
  final List<int>? ports;
  @JsonKey(name: 'initiated_by')
  final String? initiatedBy;
  @JsonKey(name: 'total_hosts')
  final int totalHosts;
  @JsonKey(name: 'discovered_hosts')
  final int discoveredHosts;
  @JsonKey(name: 'active_hosts')
  final int activeHosts;
  @JsonKey(name: 'duration_seconds')
  final int? durationSeconds;
  final double? progress;
  @JsonKey(name: 'error_message')
  final String? errorMessage;
  @JsonKey(name: 'result_summary')
  final String? resultSummary;
  @JsonKey(name: 'started_at')
  final DateTime startedAt;
  @JsonKey(name: 'completed_at')
  final DateTime? completedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  const NetworkScanModel({
    required this.id,
    required this.type,
    required this.status,
    this.name,
    required this.targetSubnet,
    this.targetIps,
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

  factory NetworkScanModel.fromJson(Map<String, dynamic> json) =>
      _$NetworkScanModelFromJson(json);

  Map<String, dynamic> toJson() => _$NetworkScanModelToJson(this);

  NetworkScan toEntity() => NetworkScan(
        id: id,
        type: ScanType.values.firstWhere(
          (t) => t.value == type,
          orElse: () => ScanType.ping,
        ),
        status: ScanStatus.values.firstWhere(
          (s) => s.name == status,
          orElse: () => ScanStatus.pending,
        ),
        name: name,
        targetSubnet: targetSubnet,
        targetIps: targetIps ?? [],
        portRange: portRange,
        ports: ports,
        initiatedBy: initiatedBy,
        totalHosts: totalHosts,
        discoveredHosts: discoveredHosts,
        activeHosts: activeHosts,
        durationSeconds: durationSeconds,
        progress: progress,
        errorMessage: errorMessage,
        resultSummary: resultSummary,
        startedAt: startedAt,
        completedAt: completedAt,
        createdAt: createdAt,
      );

  factory NetworkScanModel.fromEntity(NetworkScan entity) =>
      NetworkScanModel(
        id: entity.id,
        type: entity.type.value,
        status: entity.status.name,
        name: entity.name,
        targetSubnet: entity.targetSubnet,
        targetIps: entity.targetIps,
        portRange: entity.portRange,
        ports: entity.ports,
        initiatedBy: entity.initiatedBy,
        totalHosts: entity.totalHosts,
        discoveredHosts: entity.discoveredHosts,
        activeHosts: entity.activeHosts,
        durationSeconds: entity.durationSeconds,
        progress: entity.progress,
        errorMessage: entity.errorMessage,
        resultSummary: entity.resultSummary,
        startedAt: entity.startedAt,
        completedAt: entity.completedAt,
        createdAt: entity.createdAt,
      );
}
