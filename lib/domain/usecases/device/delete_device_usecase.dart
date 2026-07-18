import 'package:dartz/dartz.dart';
import '../../repositories/device_repository.dart';
import '../../../core/errors/failures.dart';

class DeleteDeviceUseCase {
  final DeviceRepository _repository;

  DeleteDeviceUseCase(this._repository);

  Future<Either<Failure, void>> call(String id) {
    return _repository.deleteDevice(id);
  }
}
