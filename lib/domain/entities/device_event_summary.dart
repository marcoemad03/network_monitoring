import 'package:equatable/equatable.dart';

class DeviceEventSummary extends Equatable {
  final int totalEvents;
  final int connectionEvents;
  final int disconnectionEvents;
  final int ipChanges;
  final int groupChanges;
  final int policyChanges;
  final int bandwidthAlerts;
  final int blockEvents;
  final int adminActions;

  const DeviceEventSummary({
    this.totalEvents = 0,
    this.connectionEvents = 0,
    this.disconnectionEvents = 0,
    this.ipChanges = 0,
    this.groupChanges = 0,
    this.policyChanges = 0,
    this.bandwidthAlerts = 0,
    this.blockEvents = 0,
    this.adminActions = 0,
  });

  DeviceEventSummary copyWith({
    int? totalEvents,
    int? connectionEvents,
    int? disconnectionEvents,
    int? ipChanges,
    int? groupChanges,
    int? policyChanges,
    int? bandwidthAlerts,
    int? blockEvents,
    int? adminActions,
  }) {
    return DeviceEventSummary(
      totalEvents: totalEvents ?? this.totalEvents,
      connectionEvents: connectionEvents ?? this.connectionEvents,
      disconnectionEvents: disconnectionEvents ?? this.disconnectionEvents,
      ipChanges: ipChanges ?? this.ipChanges,
      groupChanges: groupChanges ?? this.groupChanges,
      policyChanges: policyChanges ?? this.policyChanges,
      bandwidthAlerts: bandwidthAlerts ?? this.bandwidthAlerts,
      blockEvents: blockEvents ?? this.blockEvents,
      adminActions: adminActions ?? this.adminActions,
    );
  }

  @override
  List<Object?> get props => [
        totalEvents,
        connectionEvents,
        disconnectionEvents,
        ipChanges,
        groupChanges,
        policyChanges,
        bandwidthAlerts,
        blockEvents,
        adminActions,
      ];
}
