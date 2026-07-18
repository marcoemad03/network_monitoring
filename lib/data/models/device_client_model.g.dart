// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_client_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceClientModel _$DeviceClientModelFromJson(Map<String, dynamic> json) =>
    DeviceClientModel(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      macAddress: json['mac_address'] as String,
      ipAddress: json['ip_address'] as String?,
      hostname: json['hostname'] as String?,
      vendor: json['vendor'] as String?,
      osType: json['os_type'] as String?,
      connectionType: json['connection_type'] as String? ?? 'ethernet',
      ssid: json['ssid'] as String?,
      bssid: json['bssid'] as String?,
      signalStrengthDbm: (json['signal_strength_dbm'] as num?)?.toInt(),
      signalQualityPercent:
          (json['signal_quality_percent'] as num?)?.toDouble(),
      channel: (json['channel'] as num?)?.toInt(),
      frequencyMhz: (json['frequency_mhz'] as num?)?.toInt(),
      noiseDbm: (json['noise_dbm'] as num?)?.toInt(),
      snrDbm: (json['snr_dbm'] as num?)?.toInt(),
      txRateMbps: (json['tx_rate_mbps'] as num?)?.toDouble(),
      rxRateMbps: (json['rx_rate_mbps'] as num?)?.toDouble(),
      txBytes: (json['tx_bytes'] as num?)?.toInt() ?? 0,
      rxBytes: (json['rx_bytes'] as num?)?.toInt() ?? 0,
      txPackets: (json['tx_packets'] as num?)?.toInt() ?? 0,
      rxPackets: (json['rx_packets'] as num?)?.toInt() ?? 0,
      connectedApId: json['connected_ap_id'] as String?,
      connectedSwitchId: json['connected_switch_id'] as String?,
      switchPort: json['switch_port'] as String?,
      vlanId: (json['vlan_id'] as num?)?.toInt(),
      isActive: json['is_active'] as bool? ?? true,
      firstSeen: DateTime.parse(json['first_seen'] as String),
      lastSeen: DateTime.parse(json['last_seen'] as String),
    );

Map<String, dynamic> _$DeviceClientModelToJson(DeviceClientModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'device_id': instance.deviceId,
      'mac_address': instance.macAddress,
      'ip_address': instance.ipAddress,
      'hostname': instance.hostname,
      'vendor': instance.vendor,
      'os_type': instance.osType,
      'connection_type': instance.connectionType,
      'ssid': instance.ssid,
      'bssid': instance.bssid,
      'signal_strength_dbm': instance.signalStrengthDbm,
      'signal_quality_percent': instance.signalQualityPercent,
      'channel': instance.channel,
      'frequency_mhz': instance.frequencyMhz,
      'noise_dbm': instance.noiseDbm,
      'snr_dbm': instance.snrDbm,
      'tx_rate_mbps': instance.txRateMbps,
      'rx_rate_mbps': instance.rxRateMbps,
      'tx_bytes': instance.txBytes,
      'rx_bytes': instance.rxBytes,
      'tx_packets': instance.txPackets,
      'rx_packets': instance.rxPackets,
      'connected_ap_id': instance.connectedApId,
      'connected_switch_id': instance.connectedSwitchId,
      'switch_port': instance.switchPort,
      'vlan_id': instance.vlanId,
      'is_active': instance.isActive,
      'first_seen': instance.firstSeen.toIso8601String(),
      'last_seen': instance.lastSeen.toIso8601String(),
    };
