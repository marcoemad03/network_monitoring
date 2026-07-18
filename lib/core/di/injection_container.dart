import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../network/dio_client.dart';
import '../network/network_info.dart';
import '../network/websocket_client.dart';
import '../security/jwt_manager.dart';
import '../security/secure_storage.dart';

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final flutterSecureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final jwtManagerProvider = Provider<JwtManager>(
  (ref) => JwtManager(ref.watch(flutterSecureStorageProvider)),
);

final dioProvider = Provider<DioClient>(
  (ref) => DioClient(jwtManager: ref.watch(jwtManagerProvider)),
);

final dioRawProvider = Provider<Dio>((ref) => ref.watch(dioProvider).dio);

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final networkInfoProvider = Provider<NetworkInfo>(
  (ref) => NetworkInfoImpl(ref.watch(connectivityProvider)),
);

final webSocketClientProvider = Provider<WebSocketClient>(
  (ref) => WebSocketClient(ref.watch(jwtManagerProvider)),
);

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in main.dart');
});
