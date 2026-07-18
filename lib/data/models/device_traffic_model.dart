import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device_traffic.dart';

part 'device_traffic_model.g.dart';

@JsonSerializable(explicitToJson: true)
class DeviceTrafficModel {
  final String id;
  @JsonKey(name: 'device_id')
  final String deviceId;
  @JsonKey(name: 'interface_id')
  final String? interfaceId;
  @JsonKey(name: 'upload_bps')
  final int uploadBps;
  @JsonKey(name: 'download_bps')
  final int downloadBps;
  @JsonKey(name: 'total_upload_bytes')
  final int totalUploadBytes;
  @JsonKey(name: 'total_download_bytes')
  final int totalDownloadBytes;
  @JsonKey(name: 'upload_packets')
  final int uploadPackets;
  @JsonKey(name: 'download_packets')
  final int downloadPackets;
  @JsonKey(name: 'upload_errors')
  final int uploadErrors;
  @JsonKey(name: 'download_errors')
  final int downloadErrors;
  @JsonKey(name: 'utilization_percent')
  final double? utilizationPercent;
  final DateTime timestamp;

  const DeviceTrafficModel({
    required this.id,
    required this.deviceId,
    this.interfaceId,
    this.uploadBps = 0,
    this.downloadBps = 0,
    this.totalUploadBytes = 0,
    this.totalDownloadBytes = 0,
    this.uploadPackets = 0,
    this.downloadPackets = 0,
    this.uploadErrors = 0,
    this.downloadErrors = 0,
    this.utilizationPercent,
    required this.timestamp,
  });

  factory DeviceTrafficModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceTrafficModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceTrafficModelToJson(this);

  DeviceTraffic toEntity() => DeviceTraffic(
        id: id,
        deviceId: deviceId,
        interfaceId: interfaceId,
        uploadBps: uploadBps,
        downloadBps: downloadBps,
        totalUploadBytes: totalUploadBytes,
        totalDownloadBytes: totalDownloadBytes,
        uploadPackets: uploadPackets,
        downloadPackets: downloadPackets,
        uploadErrors: uploadErrors,
        downloadErrors: downloadErrors,
        utilizationPercent: utilizationPercent,
        timestamp: timestamp,
      );
}
