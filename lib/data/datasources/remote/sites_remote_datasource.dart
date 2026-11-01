import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/sites_models.dart';

/// A request the server refused, with its message ready to show.
class SitesRequestFailed implements Exception {
  final String code;
  final String message;
  const SitesRequestFailed(this.code, this.message);

  @override
  String toString() => message;
}

/// The saved entry, and why its logo could not be downloaded (empty if it was).
class CatalogResult {
  final CatalogEntry entry;
  final String logoError;
  const CatalogResult(this.entry, this.logoError);
}

// A write is never repeated by the client: a retried create would be refused as a duplicate.
final _noRetry = Options(extra: {'retryCount': 99});
final _slowWrite = Options(
  receiveTimeout: const Duration(seconds: 60),
  extra: {'retryCount': 99},
);

class SitesRemoteDataSource {
  final DioClient _client;
  SitesRemoteDataSource(this._client);

  static const _base = '${ApiConstants.basePath}/security';

  Map<String, dynamic> _data(Response<dynamic> r) =>
      Map<String, dynamic>.from((r.data as Map)['data'] as Map);

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map)
        throw SitesRequestFailed(
          data['error_code'] as String? ?? 'ERROR',
          data['message'] as String? ?? 'The request failed.',
        );
      throw const SitesRequestFailed(
        'NETWORK',
        'Could not reach the NMS server.',
      );
    }
  }

  Future<SitesOverview> overview({
    required int hours,
    required bool background,
  }) async {
    final r = await _client.get(
      '$_base/sites',
      queryParameters: {'hours': hours, if (background) 'background': 1},
    );
    return SitesOverview.fromJson(_data(r));
  }

  Future<DeviceSites> device(
    String key, {
    required int hours,
    bool background = false,
  }) async {
    final r = await _client.get(
      '$_base/sites/device/${Uri.encodeComponent(key)}',
      queryParameters: {'hours': hours, if (background) 'background': 1},
    );
    return DeviceSites.fromJson(_data(r));
  }

  Future<SiteDetail> site(String domain, {required int hours}) async {
    final r = await _client.get(
      '$_base/sites/detail/${Uri.encodeComponent(domain)}',
      queryParameters: {'hours': hours},
    );
    return SiteDetail.fromJson(_data(r));
  }

  /// The logo bytes, or null when the site has none.
  Future<Uint8List?> logo(String domain) async {
    try {
      final r = await _client.get<List<int>>(
        '$_base/sites/logo/${Uri.encodeComponent(domain)}',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = r.data;
      return bytes == null || bytes.isEmpty ? null : Uint8List.fromList(bytes);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  CatalogResult _result(Response<dynamic> r) => CatalogResult(
    CatalogEntry.fromJson(_data(r)),
    ((r.data as Map)['logo_error'] as String?) ?? '',
  );

  Future<CatalogResult> create({
    required String name,
    required String category,
    required List<String> domains,
    bool fetchLogo = true,
  }) => _guard(() async {
    final r = await _client.post(
      '$_base/catalog',
      data: {
        'name': name,
        'category': category,
        'domains': domains,
        'fetch_logo': fetchLogo,
      },
      options: _slowWrite,
    );
    return _result(r);
  });

  /// Names a site seen in the recording. A common site keeps its built-in name.
  Future<CatalogResult> adopt(
    String domain, {
    String name = '',
    String category = '',
  }) => _guard(() async {
    final r = await _client.post(
      '$_base/sites/adopt',
      data: {'domain': domain, 'name': name, 'category': category},
      options: _slowWrite,
    );
    return _result(r);
  });

  Future<CatalogResult> update(
    String id, {
    required String name,
    required String category,
    required List<String> domains,
    bool fetchLogo = false,
  }) => _guard(() async {
    final r = await _client.put(
      '$_base/catalog/$id',
      data: {
        'name': name,
        'category': category,
        'domains': domains,
        'fetch_logo': fetchLogo,
      },
      options: _slowWrite,
    );
    return _result(r);
  });

  Future<void> delete(String id) => _guard(() async {
    await _client.delete('$_base/catalog/$id', options: _noRetry);
  });

  /// Gets the logo from the site itself, or from [imageUrl] when one is given.
  Future<CatalogEntry> fetchLogo(String id, {String imageUrl = ''}) =>
      _guard(() async {
        final r = await _client.post(
          '$_base/catalog/$id/logo/fetch',
          data: {if (imageUrl.isNotEmpty) 'logo_url': imageUrl},
          options: _slowWrite,
        );
        return CatalogEntry.fromJson(_data(r));
      });

  Future<void> removeLogo(String id) => _guard(() async {
    await _client.delete('$_base/catalog/$id/logo', options: _noRetry);
  });
}
