import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/device.dart';
import '../../../domain/entities/device_client.dart';
import '../../../domain/entities/device_connection.dart';
import '../../../domain/entities/dashboard_live.dart';
import '../../../domain/usecases/device/get_devices_usecase.dart';
import '../../../domain/usecases/device/get_device_detail_usecase.dart';
import '../../../domain/usecases/device/create_device_usecase.dart';
import '../../../domain/usecases/device/update_device_usecase.dart';
import '../../../domain/usecases/device/delete_device_usecase.dart';
import '../../../data/repositories/device_repository_impl.dart';
import '../../../data/datasources/remote/device_remote_datasource.dart';
import '../../../data/datasources/local/device_local_datasource.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/network/websocket_manager.dart';
import '../../../core/network/websocket_client.dart';
import '../../../data/models/dashboard_live_model.dart';
import '../../../core/utils/logger.dart';

final getDevicesUseCaseProvider = Provider<GetDevicesUseCase>((ref) {
  return GetDevicesUseCase(ref.watch(deviceRepositoryProvider));
});

final getDeviceDetailUseCaseProvider = Provider<GetDeviceDetailUseCase>((ref) {
  return GetDeviceDetailUseCase(ref.watch(deviceRepositoryProvider));
});

final createDeviceUseCaseProvider = Provider<CreateDeviceUseCase>((ref) {
  return CreateDeviceUseCase(ref.watch(deviceRepositoryProvider));
});

final updateDeviceUseCaseProvider = Provider<UpdateDeviceUseCase>((ref) {
  return UpdateDeviceUseCase(ref.watch(deviceRepositoryProvider));
});

final deleteDeviceUseCaseProvider = Provider<DeleteDeviceUseCase>((ref) {
  return DeleteDeviceUseCase(ref.watch(deviceRepositoryProvider));
});

final deviceRepositoryProvider = Provider<DeviceRepositoryImpl>((ref) {
  return DeviceRepositoryImpl(
    remoteDataSource: ref.watch(deviceRemoteDataSourceProvider),
    localDataSource: ref.watch(deviceLocalDataSourceProvider),
    networkInfo: ref.watch(networkInfoProvider),
  );
});

final deviceRemoteDataSourceProvider = Provider<DeviceRemoteDataSource>((ref) {
  return DeviceRemoteDataSourceImpl(ref.watch(dioProvider));
});

final deviceLocalDataSourceProvider = Provider<DeviceLocalDataSource>((ref) {
  return DeviceLocalDataSourceImpl(ref.watch(sharedPreferencesProvider));
});

final deviceListProvider =
    FutureProvider.autoDispose.family<List<Device>, DeviceFilter>(
  (ref, filter) async {
    final useCase = ref.watch(getDevicesUseCaseProvider);
    final result = await useCase(
      page: filter.page,
      limit: filter.limit,
      search: filter.search,
      status: filter.status,
      type: filter.type,
      department: filter.department,
      sortBy: filter.sortBy,
      ascending: filter.ascending,
    );
    return result.fold((failure) => [], (devices) => devices);
  },
);

class DeviceFilter {
  final int page;
  final int limit;
  final String? search;
  final String? status;
  final String? type;
  final String? department;
  final String? sortBy;
  final bool ascending;

  const DeviceFilter({
    this.page = 1,
    this.limit = 20,
    this.search,
    this.status,
    this.type,
    this.department,
    this.sortBy,
    this.ascending = true,
  });

  DeviceFilter copyWith({
    int? page,
    int? limit,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool? ascending,
  }) {
    return DeviceFilter(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status ?? this.status,
      type: type ?? this.type,
      department: department ?? this.department,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

final deviceFilterProvider =
    StateNotifierProvider<DeviceFilterNotifier, DeviceFilter>(
  (ref) => DeviceFilterNotifier(),
);

class DeviceFilterNotifier extends StateNotifier<DeviceFilter> {
  DeviceFilterNotifier() : super(const DeviceFilter());

  void setSearch(String? search) => state = state.copyWith(search: search);
  void setStatus(String? status) => state = state.copyWith(status: status);
  void setType(String? type) => state = state.copyWith(type: type);
  void setPage(int page) => state = state.copyWith(page: page);
  void setSort(String sortBy, bool ascending) =>
      state = state.copyWith(sortBy: sortBy, ascending: ascending);
  void reset() => state = const DeviceFilter();
}

final deviceDetailProvider = FutureProvider.autoDispose.family<Device?, String>(
  (ref, id) async {
    final useCase = ref.watch(getDeviceDetailUseCaseProvider);
    final result = await useCase(id);
    return result.fold((failure) => null, (device) => device);
  },
);

final wsConnectionStateProvider = Provider<WebSocketState>((ref) {
  final manager = ref.watch(webSocketManagerProvider);
  return manager.connectionStateValue;
});

final webSocketManagerProvider = Provider<WebSocketManager>((ref) {
  final client = ref.watch(webSocketClientProvider);
  final manager = WebSocketManager(client);
  ref.onDispose(() => manager.dispose());
  return manager;
});

final allDevicesProvider = FutureProvider.autoDispose<List<Device>>((ref) async {
  final useCase = ref.watch(getDevicesUseCaseProvider);
  final result = await useCase(page: 1, limit: 500);
  return result.fold((_) => [], (devices) => devices);
});

final dashboardSummaryProvider = StreamProvider.autoDispose<DashboardLive?>((ref) async* {
  final repo = ref.watch(deviceRepositoryProvider);

  try {
    final result = await repo.getDashboardSummary();
    yield result.fold((_) => null, (s) => s);
  } catch (e) {
    AppLogger.error('Failed to fetch dashboard summary', error: e);
    yield null;
  }

  try {
    final manager = ref.watch(webSocketManagerProvider);
    await manager.start();
    await for (final message in manager.messages) {
      if (message['type'] == 'dashboard_summary') {
        try {
          final data = message['data'] as Map<String, dynamic>;
          yield DashboardLiveModel.fromJson(data).toEntity();
        } catch (e) {
          AppLogger.error('Failed to parse WebSocket dashboard update', error: e);
        }
      }
    }
  } catch (e) {
    AppLogger.debug('WebSocket dashboard stream ended', error: e);
  }
});

final deviceClientsProvider = FutureProvider.autoDispose.family<List<DeviceClient>, String>(
  (ref, deviceId) async {
    final repo = ref.watch(deviceRepositoryProvider);
    final result = await repo.getDeviceClients(deviceId);
    return result.fold((_) => [], (clients) => clients);
  },
);

final allClientsProvider = FutureProvider.autoDispose<List<DeviceClient>>((ref) async {
  final repo = ref.watch(deviceRepositoryProvider);
  final result = await repo.getAllClients();
  return result.fold((_) => [], (clients) => clients);
});

final connectionsProvider = FutureProvider.autoDispose<List<DeviceConnection>>((ref) async {
  final repo = ref.watch(deviceRepositoryProvider);
  final result = await repo.getConnections();
  return result.fold((_) => [], (conns) => conns);
});

final deviceUpdateStreamProvider = StreamProvider.autoDispose<Map<String, dynamic>>((ref) {
  final manager = ref.watch(webSocketManagerProvider);

  return () async* {
    try {
      await manager.start();
      await for (final message in manager.messages) {
        if (message['type'] == 'device_update' && message['data'] is Map<String, dynamic>) {
          yield message['data'] as Map<String, dynamic>;
        }
      }
    } finally {
      AppLogger.debug('deviceUpdateStreamProvider stream ended');
    }
  }();
});
