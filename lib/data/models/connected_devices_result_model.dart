import '../../domain/entities/connected_device.dart';
import '../../domain/entities/router_connection_status.dart';
import 'connected_device_model.dart';
import 'router_connection_status_model.dart';

class ConnectedDevicesResultModel {
  final RouterConnectionStatusModel connection;
  final List<ConnectedDeviceModel> devices;

  const ConnectedDevicesResultModel({
    required this.connection,
    required this.devices,
  });

  factory ConnectedDevicesResultModel.fromJson(Map<String, dynamic> json) {
    final connection = RouterConnectionStatusModel.fromJson(
      (json['connection'] as Map?)?.cast<String, dynamic>() ?? {},
    );
    final devices =
        ((json['devices'] as List?) ?? const [])
            .whereType<Map>()
            .map(
              (e) => ConnectedDeviceModel.fromJson(e.cast<String, dynamic>()),
            )
            .toList();
    return ConnectedDevicesResultModel(
      connection: connection,
      devices: devices,
    );
  }

  RouterConnectionStatus get connectionEntity => connection.toEntity();
  List<ConnectedDevice> get deviceEntities =>
      devices.map((device) => device.toEntity()).toList();
}
