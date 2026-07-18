import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../entities/device.dart';
import '../entities/interface.dart';
import '../entities/device_metrics.dart';
import '../entities/device_client.dart';
import '../entities/device_traffic.dart';
import '../entities/device_ping.dart';
import '../entities/device_connection.dart';
import '../entities/dashboard_live.dart';

abstract class DeviceRepository {
  Future<Either<Failure, List<Device>>> getDevices({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool ascending = true,
  });
  Future<Either<Failure, Device>> getDeviceById(String id);
  Future<Either<Failure, Device>> createDevice(Device device);
  Future<Either<Failure, Device>> updateDevice(Device device);
  Future<Either<Failure, void>> deleteDevice(String id);
  Future<Either<Failure, List<NetworkInterface>>> getDeviceInterfaces(
    String deviceId,
  );
  Future<Either<Failure, DeviceMetrics>> getDeviceMetrics(String deviceId);
  Future<Either<Failure, List<DeviceMetrics>>> getDeviceMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<Either<Failure, Map<String, int>>> getDeviceStatusSummary();
  Future<Either<Failure, List<Device>>> searchDevices(String query);

  // Monitoring
  Future<Either<Failure, DashboardLive>> getDashboardSummary();
  Future<Either<Failure, List<DeviceClient>>> getDeviceClients(String deviceId);
  Future<Either<Failure, List<DeviceClient>>> getAllClients();
  Future<Either<Failure, List<DeviceConnection>>> getConnections();
  Future<Either<Failure, DeviceMetrics>> getLatestMetrics(String deviceId);
  Future<Either<Failure, DevicePing>> getLatestPing(String deviceId);
  Future<Either<Failure, DeviceTraffic>> getLatestTraffic(String deviceId);
  Future<Either<Failure, List<DevicePing>>> getPingHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
  Future<Either<Failure, List<DeviceTraffic>>> getTrafficHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  });
}
