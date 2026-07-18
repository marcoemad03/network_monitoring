import '../../models/dashboard_summary_model.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

abstract class DashboardRemoteDataSource {
  Future<DashboardSummaryModel> getSummary();
}

class DashboardRemoteDataSourceImpl implements DashboardRemoteDataSource {
  final DioClient _client;

  DashboardRemoteDataSourceImpl(this._client);

  @override
  Future<DashboardSummaryModel> getSummary() async {
    final response = await _client.get(ApiConstants.dashboardSummary);
    return DashboardSummaryModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
