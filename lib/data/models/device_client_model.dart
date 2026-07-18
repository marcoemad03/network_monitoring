import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_client.dart';

part 'device_client_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceClientModel {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'mac_address')
  final String macAddress;
  @JsonKey(name: 'ip_address')
  final String? ipAddress;
  final String? hostname;
  final String? vendor;
  @JsonKey(name: 'os_type')
  final String? osType;
  @JsonKey(name: 'connection_type')
  final String connectionType;
  final String? ssid;
  final String? bssid;
  @JsonKey(name: 'signal_strength_dbm')
  final int? signalStrengthDbm;
  @JsonKey(name: 'signal_quality_percent')
  final double? signalQualityPercent;
  final int? channel;
  @JsonKey(name: 'frequency_mhz')
  final int? frequencyMhz;
  @JsonKey(name: 'noise_dbm')
  final int? noiseDbm;
  @JsonKey(name: 'snr_dbm')
  final int? snrDbm;
  @JsonKey(name: 'tx_rate_mbps')
  final double? txRateMbps;
  @JsonKey(name: 'rx_rate_mbps')
  final double? rxRateMbps;
  @JsonKey(name: 'tx_bytes')
  final int txBytes;
  @JsonKey(name: 'rx_bytes')
  final int rxBytes;
  @JsonKey(name: 'tx_packets')
  final int txPackets;
  @JsonKey(name: 'rx_packets')
  final int rxPackets;
  @JsonKey(name: 'connected_ap_id')
  final String? connectedApId;
  @JsonKey(name: 'connected_switch_id')
  final String? connectedSwitchId;
  @JsonKey(name: 'switch_port')
  final String? switchPort;
  @JsonKey(name: 'vlan_id')
  final int? vlanId;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'first_seen')
  final DateTime firstSeen;
  @JsonKey(name: 'last_seen')
  final DateTime lastSeen;

  const DeviceClientModel({
    required this.id,
    required this.deviceId,
    required this.macAddress,
    this.ipAddress,
    this.hostname,
    this.vendor,
    this.osType,
    this.connectionType = 'ethernet',
    this.ssid,
    this.bssid,
    this.signalStrengthDbm,
    this.signalQualityPercent,
    this.channel,
    this.frequencyMhz,
    this.noiseDbm,
    this.snrDbm,
    this.txRateMbps,
    this.rxRateMbps,
    this.txBytes = 0,
    this.rxBytes = 0,
    this.txPackets = 0,
    this.rxPackets = 0,
    this.connectedApId,
    this.connectedSwitchId,
    this.switchPort,
    this.vlanId,
    this.isActive = true,
    required this.firstSeen,
    required this.lastSeen,
  });

  factory DeviceClientModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceClientModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceClientModelToJson(this);

  DeviceClient toEntity() => DeviceClient(
        id: id,
        deviceId: deviceId,
        macAddress: macAddress,
        ipAddress: ipAddress,
        hostname: hostname,
        vendor: vendor,
        osType: osType,
        connectionType: connectionType,
        ssid: ssid,
        bssid: bssid,
        signalStrengthDbm: signalStrengthDbm,
        signalQualityPercent: signalQualityPercent,
        channel: channel,
        frequencyMhz: frequencyMhz,
        noiseDbm: noiseDbm,
        snrDbm: snrDbm,
        txRateMbps: txRateMbps,
        rxRateMbps: rxRateMbps,
        txBytes: txBytes,
        rxBytes: rxBytes,
        txPackets: txPackets,
        rxPackets: rxPackets,
        connectedApId: connectedApId,
        connectedSwitchId: connectedSwitchId,
        switchPort: switchPort,
        vlanId: vlanId,
        isActive: isActive,
        firstSeen: firstSeen,
        lastSeen: lastSeen,
      );
}
