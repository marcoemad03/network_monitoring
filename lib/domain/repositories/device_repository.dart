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
import '../entities/device_control_log.dart';
import '../entities/device_event.dart';
import '../entities/device_event_summary.dart';
import '../entities/device_inventory.dart';
import '../entities/connected_device.dart';
import '../entities/router_connection_status.dart';

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
  Future<
    Either<
      Failure,
      ({RouterConnectionStatus connection, List<ConnectedDevice> devices})
    >
  >
  getConnectedDevices({String? vendorId});
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

  // Device Control
  Future<Either<Failure, void>> controlDevice(
    String deviceId,
    String action, {
    Map<String, dynamic>? params,
  });
  Future<Either<Failure, List<DeviceControlLog>>> getDeviceControlLogs(
    String deviceId, {
    int page = 1,
    int limit = 20,
  });

  // Device Events
  Future<Either<Failure, List<DeviceEvent>>> getDeviceEvents(
    String deviceId, {
    int page = 1,
    int limit = 20,
    String? eventType,
  });
  Future<Either<Failure, DeviceEventSummary>> getDeviceEventSummary(
    String deviceId,
  );

  // Device Inventory
  Future<Either<Failure, List<DeviceInventory>>> getDeviceInventory({
    int page = 1,
    int limit = 50,
    String? search,
    String? building,
    String? floor,
    String? status,
    String? connectionType,
    String? sortBy,
    bool ascending = true,
  });

  // Enhanced Discovery
  Future<Either<Failure, List<DeviceInventory>>> discoverDevices172(
    String vendorId,
  );
  Future<Either<Failure, void>> startPolling(
    String vendorId,
    int intervalSeconds,
  );
  Future<Either<Failure, void>> stopPolling(String vendorId);
}
