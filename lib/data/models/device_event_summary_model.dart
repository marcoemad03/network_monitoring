import '../../domain/entities/device_event_summary.dart';

class DeviceEventSummaryModel {
  final int totalEvents;
  final int connectionEvents;
  final int disconnectionEvents;
  final int ipChanges;
  final int groupChanges;
  final int policyChanges;
  final int bandwidthAlerts;
  final int blockEvents;
  final int adminActions;

  const DeviceEventSummaryModel({
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

  factory DeviceEventSummaryModel.fromJson(Map<String, dynamic> json) {
    return DeviceEventSummaryModel(
      totalEvents: (json['total_events'] as num?)?.toInt() ?? 0,
      connectionEvents: (json['connection_events'] as num?)?.toInt() ?? 0,
      disconnectionEvents:
          (json['disconnection_events'] as num?)?.toInt() ?? 0,
      ipChanges: (json['ip_changes'] as num?)?.toInt() ?? 0,
      groupChanges: (json['group_changes'] as num?)?.toInt() ?? 0,
      policyChanges: (json['policy_changes'] as num?)?.toInt() ?? 0,
      bandwidthAlerts: (json['bandwidth_alerts'] as num?)?.toInt() ?? 0,
      blockEvents: (json['block_events'] as num?)?.toInt() ?? 0,
      adminActions: (json['admin_actions'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_events': totalEvents,
      'connection_events': connectionEvents,
      'disconnection_events': disconnectionEvents,
      'ip_changes': ipChanges,
      'group_changes': groupChanges,
      'policy_changes': policyChanges,
      'bandwidth_alerts': bandwidthAlerts,
      'block_events': blockEvents,
      'admin_actions': adminActions,
    };
  }

  DeviceEventSummary toEntity() => DeviceEventSummary(
        totalEvents: totalEvents,
        connectionEvents: connectionEvents,
        disconnectionEvents: disconnectionEvents,
        ipChanges: ipChanges,
        groupChanges: groupChanges,
        policyChanges: policyChanges,
        bandwidthAlerts: bandwidthAlerts,
        blockEvents: blockEvents,
        adminActions: adminActions,
      );

  factory DeviceEventSummaryModel.fromEntity(DeviceEventSummary entity) =>
      DeviceEventSummaryModel(
        totalEvents: entity.totalEvents,
        connectionEvents: entity.connectionEvents,
        disconnectionEvents: entity.disconnectionEvents,
        ipChanges: entity.ipChanges,
        groupChanges: entity.groupChanges,
        policyChanges: entity.policyChanges,
        bandwidthAlerts: entity.bandwidthAlerts,
        blockEvents: entity.blockEvents,
        adminActions: entity.adminActions,
      );
}
