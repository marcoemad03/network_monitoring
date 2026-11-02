import 'dart:convert';

import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../models/usage_report_models.dart';

/// A request the server refused or could not answer, with a message ready to show.
class ReportRequestFailed implements Exception {
  final String message;
  const ReportRequestFailed(this.message);

  @override
  String toString() => message;
}

class UsageReportRemoteDataSource {
  final DioClient _client;
  UsageReportRemoteDataSource(this._client);

  static const _base = '${ApiConstants.basePath}/reports/usage';

  static String dateParam(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      var data = e.response?.data;
      if (data is List<int>) {
        try {
          data = jsonDecode(utf8.decode(data));
        } on FormatException {
          data = null;
        }
      }
      if (data is Map && data['message'] is String) throw ReportRequestFailed(data['message'] as String);
      if (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout) {
        throw const ReportRequestFailed('The NMS server took too long to answer.');
      }
      throw const ReportRequestFailed('The NMS server is not reachable.');
    }
  }

  Future<UsageReport> fetch(DateTime from, DateTime to) => _guard(() async {
    final r = await _client.get(
      _base,
      queryParameters: {'from': dateParam(from), 'to': dateParam(to)},
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    final body = Map<String, dynamic>.from(r.data as Map);
    return UsageReport.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  });

  /// One view of the report as a CSV file: devices, daily, hourly, kinds or places.
  Future<ReportFile> export(DateTime from, DateTime to, String view) => _guard(() async {
    final r = await _client.get<List<int>>(
      '$_base/export',
      queryParameters: {'from': dateParam(from), 'to': dateParam(to), 'view': view},
      options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(seconds: 60)),
    );
    final header = r.headers.value('content-disposition') ?? '';
    final match = RegExp('filename="([^"]+)"').firstMatch(header);
    return ReportFile(match?.group(1) ?? 'usage-$view.csv', r.data ?? const []);
  });
}
