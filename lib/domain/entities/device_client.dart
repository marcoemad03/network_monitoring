import 'package:equatable/equatable.dart';

class DeviceClient extends Equatable {
  final String id;
  final String deviceId;
  final String macAddress;
  final String? ipAddress;
  final String? hostname;
  final String? vendor;
  final String? osType;
  final String connectionType;
  final String? ssid;
  final String? bssid;
  final int? signalStrengthDbm;
  final double? signalQualityPercent;
  final int? channel;
  final int? frequencyMhz;
  final int? noiseDbm;
  final int? snrDbm;
  final double? txRateMbps;
  final double? rxRateMbps;
  final int txBytes;
  final int rxBytes;
  final int txPackets;
  final int rxPackets;
  final String? connectedApId;
  final String? connectedSwitchId;
  final String? switchPort;
  final int? vlanId;
  final bool isActive;
  final DateTime firstSeen;
  final DateTime lastSeen;

  const DeviceClient({
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

  String get signalStrengthLabel {
    if (signalStrengthDbm == null) return 'N/A';
    final s = signalStrengthDbm!;
    if (s >= -50) return 'Excellent';
    if (s >= -60) return 'Good';
    if (s >= -70) return 'Fair';
    if (s >= -80) return 'Weak';
    return 'Very Weak';
  }

  @override
  List<Object?> get props => [
        id, deviceId, macAddress, ipAddress, hostname, vendor, osType,
        connectionType, ssid, bssid, signalStrengthDbm, signalQualityPercent,
        channel, frequencyMhz, noiseDbm, snrDbm, txRateMbps, rxRateMbps,
        txBytes, rxBytes, txPackets, rxPackets, connectedApId, connectedSwitchId,
        switchPort, vlanId, isActive, firstSeen, lastSeen,
      ];
}
