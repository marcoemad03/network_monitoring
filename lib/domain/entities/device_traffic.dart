import 'package:equatable/equatable.dart';

class DeviceTraffic extends Equatable {
  final String id;
  final String deviceId;
  final String? interfaceId;
  final int uploadBps;
  final int downloadBps;
  final int totalUploadBytes;
  final int totalDownloadBytes;
  final int uploadPackets;
  final int downloadPackets;
  final int uploadErrors;
  final int downloadErrors;
  final double? utilizationPercent;
  final DateTime timestamp;

  const DeviceTraffic({
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

  double get uploadSpeedMbps => uploadBps / 1000000;
  double get downloadSpeedMbps => downloadBps / 1000000;
  double get totalUploadGB => totalUploadBytes / 1073741824;
  double get totalDownloadGB => totalDownloadBytes / 1073741824;

  @override
  List<Object?> get props => [
        id, deviceId, interfaceId, uploadBps, downloadBps,
        totalUploadBytes, totalDownloadBytes, uploadPackets, downloadPackets,
        uploadErrors, downloadErrors, utilizationPercent, timestamp,
      ];
}
