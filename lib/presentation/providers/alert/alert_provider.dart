import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/alert.dart';
import '../../../domain/usecases/alert/get_alerts_usecase.dart';
import '../../../domain/usecases/alert/acknowledge_alert_usecase.dart';
import '../../../domain/usecases/alert/resolve_alert_usecase.dart';
import '../../../data/repositories/alert_repository_impl.dart';
import '../../../data/datasources/remote/alert_remote_datasource.dart';
import '../../../core/di/injection_container.dart';

final getAlertsUseCaseProvider = Provider<GetAlertsUseCase>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return GetAlertsUseCase(repo);
});

final acknowledgeAlertUseCaseProvider =
    Provider<AcknowledgeAlertUseCase>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return AcknowledgeAlertUseCase(repo);
});

final resolveAlertUseCaseProvider = Provider<ResolveAlertUseCase>((ref) {
  final repo = ref.watch(alertRepositoryProvider);
  return ResolveAlertUseCase(repo);
});

final alertRepositoryProvider = Provider<AlertRepositoryImpl>((ref) {
  final remote = ref.watch(alertRemoteDataSourceProvider2);
  final net = ref.watch(networkInfoProvider);
  return AlertRepositoryImpl(remoteDataSource: remote, networkInfo: net);
});

final alertRemoteDataSourceProvider2 = Provider<AlertRemoteDataSource>((ref) {
  final client = ref.watch(dioProvider);
  return AlertRemoteDataSourceImpl(client);
});

final alertListProvider =
    FutureProvider.autoDispose.family<List<Alert>, AlertQueryParameters>(
  (ref, params) async {
    final useCase = ref.watch(getAlertsUseCaseProvider);
    final result = await useCase(
      page: params.page,
      limit: params.limit,
      status: params.status,
      severity: params.severity,
      category: params.category,
      deviceId: params.deviceId,
      sortBy: params.sortBy,
      ascending: params.ascending,
    );
    return result.fold((failure) => [], (alerts) => alerts);
  },
);

class AlertQueryParameters {
  final int page;
  final int limit;
  final String? status;
  final String? severity;
  final String? category;
  final String? deviceId;
  final String? sortBy;
  final bool ascending;

  const AlertQueryParameters({
    this.page = 1,
    this.limit = 20,
    this.status,
    this.severity,
    this.category,
    this.deviceId,
    this.sortBy,
    this.ascending = false,
  });

  AlertQueryParameters copyWith({
    int? page,
    int? limit,
    String? status,
    String? severity,
    String? category,
    String? deviceId,
    String? sortBy,
    bool? ascending,
  }) {
    return AlertQueryParameters(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      status: status ?? this.status,
      severity: severity ?? this.severity,
      category: category ?? this.category,
      deviceId: deviceId ?? this.deviceId,
      sortBy: sortBy ?? this.sortBy,
      ascending: ascending ?? this.ascending,
    );
  }
}

final alertFilterProvider =
    StateNotifierProvider<AlertFilterNotifier, AlertQueryParameters>(
  (ref) => AlertFilterNotifier(),
);

class AlertFilterNotifier extends StateNotifier<AlertQueryParameters> {
  AlertFilterNotifier() : super(const AlertQueryParameters());

  void setStatus(String? status) =>
      state = state.copyWith(status: status, page: 1);
  void setSeverity(String? severity) =>
      state = state.copyWith(severity: severity, page: 1);
  void setPage(int page) => state = state.copyWith(page: page);
  void reset() => state = const AlertQueryParameters();
}
