import 'package:dartz/dartz.dart';
import '../../repositories/device_repository.dart';
import '../../entities/device.dart';
import '../../../core/errors/failures.dart';

class GetDevicesUseCase {
  final DeviceRepository _repository;

  GetDevicesUseCase(this._repository);

  Future<Either<Failure, List<Device>>> call({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? type,
    String? department,
    String? sortBy,
    bool ascending = true,
  }) {
    return _repository.getDevices(
      page: page,
      limit: limit,
      search: search,
      status: status,
      type: type,
      department: department,
      sortBy: sortBy,
      ascending: ascending,
    );
  }
}
