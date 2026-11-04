import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/inventory_models.dart';
import '../../models/usage_report_models.dart';

const _base = '${ApiConstants.basePath}/inventory';

class InventoryRemoteDataSource {
  InventoryRemoteDataSource(this._client);
  final DioClient _client;

  Future<AssetInventory> fetch() async {
    final r = await _client.get(_base);
    return AssetInventory.fromJson(Map<String, dynamic>.from((r.data as Map)['data'] as Map? ?? const {}));
  }

  Future<void> startScan() => _client.post('$_base/scan', options: Options(extra: {'retryCount': 99}));

  Future<ReportFile> export() async {
    final r = await _client.get<List<int>>(
      '$_base/export',
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)),
    );
    final match = RegExp('filename="([^"]+)"').firstMatch(r.headers.value('content-disposition') ?? '');
    return ReportFile(match?.group(1) ?? 'inventory.csv', r.data ?? const []);
  }
}
