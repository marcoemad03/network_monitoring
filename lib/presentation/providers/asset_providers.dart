import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/di/injection_container.dart';
import '../../data/datasources/remote/asset/asset_remote_datasource.dart';
import '../../data/repositories/asset/asset_repository_impl.dart';
import '../../domain/repositories/asset_repository.dart';

final assetRemoteDataSourceProvider = Provider<AssetRemoteDataSource>((ref) {
  return AssetRemoteDataSource(ref.watch(dioProvider));
});

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepositoryImpl(ref.watch(assetRemoteDataSourceProvider));
});
