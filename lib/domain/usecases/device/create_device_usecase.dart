import 'package:dartz/dartz.dart';
import '../../repositories/device_repository.dart';
import '../../entities/device.dart';
import '../../../core/errors/failures.dart';

class CreateDeviceUseCase {
  final DeviceRepository _repository;

  CreateDeviceUseCase(this._repository);

  Future<Either<Failure, Device>> call(Device device) {
    return _repository.createDevice(device);
  }
}
