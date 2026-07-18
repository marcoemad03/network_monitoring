import 'package:dartz/dartz.dart';
import '../../domain/repositories/device_repository.dart';
import '../../domain/entities/device.dart';
import '../../domain/entities/interface.dart';
import '../../domain/entities/device_metrics.dart';
import '../../domain/entities/device_client.dart';
import '../../domain/entities/device_traffic.dart';
import '../../domain/entities/device_ping.dart';
import '../../domain/entities/device_connection.dart';
import '../../domain/entities/dashboard_live.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/error_handler.dart';
import '../datasources/remote/device_remote_datasource.dart';
import '../datasources/local/device_local_datasource.dart';
import '../../core/network/network_info.dart';

class DeviceRepositoryImpl implements DeviceRepository {
  final DeviceRemoteDataSource _remoteDataSource;
  final DeviceLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;

  DeviceRepositoryImpl({
    required DeviceRemoteDataSource remoteDataSource,
    required DeviceLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  @override
  Future<Either<Failure, List<Device>>> getDevices({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool ascending = true,
  }) async {
    try {
      if (await _networkInfo.isConnected) {
        final models = await _remoteDataSource.getDevices(
          page: page,
          limit: limit,
          search: search,
          status: status,
          type: type,
          department: department,
          sortBy: sortBy,
          ascending: ascending,
        );
        final devices = models.map((m) => m.toEntity()).toList();
        if (page == 1) {
          await _localDataSource.cacheDevices(models);
        }
        return Right(devices);
      } else {
        final models = await _localDataSource.getCachedDevices();
        final devices = models.map((m) => m.toEntity()).toList();
        return Right(devices);
      }
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Device>> getDeviceById(String id) async {
    try {
      if (await _networkInfo.isConnected) {
        final model = await _remoteDataSource.getDeviceById(id);
        await _localDataSource.cacheDevice(model);
        return Right(model.toEntity());
      } else {
        final model = await _localDataSource.getCachedDevice(id);
        if (model != null) return Right(model.toEntity());
        return const Left(CacheFailure(message: 'Device not in cache'));
      }
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Device>> createDevice(Device device) async {
    try {
      final model = await _remoteDataSource.createDevice(
        _deviceToJson(device),
      );
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Device>> updateDevice(Device device) async {
    try {
      final model = await _remoteDataSource.updateDevice(
        device.id,
        _deviceToJson(device),
      );
      await _localDataSource.cacheDevice(model);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteDevice(String id) async {
    try {
      await _remoteDataSource.deleteDevice(id);
      return const Right(null);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<NetworkInterface>>> getDeviceInterfaces(
    String deviceId,
  ) async {
    try {
      final models = await _remoteDataSource.getDeviceInterfaces(deviceId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceMetrics>> getDeviceMetrics(
    String deviceId,
  ) async {
    try {
      final model = await _remoteDataSource.getDeviceMetrics(deviceId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceMetrics>>> getDeviceMetricsHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final models = await _remoteDataSource.getDeviceMetricsHistory(
        deviceId: deviceId,
        from: from,
        to: to,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getDeviceStatusSummary() async {
    try {
      final devices = await _remoteDataSource.getDevices(limit: 10000);
      final summary = <String, int>{};
      for (final device in devices) {
        summary[device.status] = (summary[device.status] ?? 0) + 1;
      }
      return Right(summary);
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<Device>>> searchDevices(String query) async {
    return getDevices(search: query, limit: 50);
  }

  @override
  Future<Either<Failure, DashboardLive>> getDashboardSummary() async {
    try {
      final model = await _remoteDataSource.getDashboardSummary();
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceClient>>> getDeviceClients(
    String deviceId,
  ) async {
    try {
      final models = await _remoteDataSource.getDeviceClients(deviceId);
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceClient>>> getAllClients() async {
    try {
      final models = await _remoteDataSource.getAllClients();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceConnection>>> getConnections() async {
    try {
      final models = await _remoteDataSource.getConnections();
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceMetrics>> getLatestMetrics(
    String deviceId,
  ) async {
    try {
      final model = await _remoteDataSource.getLatestMetrics(deviceId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DevicePing>> getLatestPing(String deviceId) async {
    try {
      final model = await _remoteDataSource.getLatestPing(deviceId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, DeviceTraffic>> getLatestTraffic(
    String deviceId,
  ) async {
    try {
      final model = await _remoteDataSource.getLatestTraffic(deviceId);
      return Right(model.toEntity());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DevicePing>>> getPingHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final models = await _remoteDataSource.getPingHistory(
        deviceId: deviceId,
        from: from,
        to: to,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  @override
  Future<Either<Failure, List<DeviceTraffic>>> getTrafficHistory({
    required String deviceId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final models = await _remoteDataSource.getTrafficHistory(
        deviceId: deviceId,
        from: from,
        to: to,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } catch (e) {
      return Left(ErrorHandler.handleException(e));
    }
  }

  Map<String, dynamic> _deviceToJson(Device device) => {
        'name': device.name,
        'hostname': device.hostname,
        'ip_address': device.ipAddress,
        'mac_address': device.macAddress,
        'device_type': device.type.value,
        'status': device.status.value,
        'vendor': device.vendor,
        'model': device.model,
        'serial_number': device.serialNumber,
        'os_version': device.osVersion,
        'firmware_version': device.firmwareVersion,
        'location': device.location,
        'department': device.department,
        'notes': device.notes,
        'custom_fields': device.customFields,
        'is_critical': device.isCritical,
        'is_monitored': device.isMonitored,
      };
}
