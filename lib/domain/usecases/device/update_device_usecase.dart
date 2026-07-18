import 'package:dartz/dartz.dart';
import '../../repositories/device_repository.dart';
import '../../entities/device.dart';
import '../../../core/errors/failures.dart';

class UpdateDeviceUseCase {
  final DeviceRepository _repository;

  UpdateDeviceUseCase(this._repository);

  Future<Either<Failure, Device>> call(Device device) {
    return _repository.updateDevice(device);
  }
}
