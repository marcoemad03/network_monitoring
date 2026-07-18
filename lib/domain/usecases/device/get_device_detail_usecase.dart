import 'package:dartz/dartz.dart';
import '../../repositories/device_repository.dart';
import '../../entities/device.dart';
import '../../../core/errors/failures.dart';

class GetDeviceDetailUseCase {
  final DeviceRepository _repository;

  GetDeviceDetailUseCase(this._repository);

  Future<Either<Failure, Device>> call(String id) {
    return _repository.getDeviceById(id);
  }
}
