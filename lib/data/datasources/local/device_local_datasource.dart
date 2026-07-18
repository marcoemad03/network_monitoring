import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/device_model.dart';

abstract class DeviceLocalDataSource {
  Future<List<DeviceModel>> getCachedDevices();
  Future<void> cacheDevices(List<DeviceModel> devices);
  Future<DeviceModel?> getCachedDevice(String id);
  Future<void> cacheDevice(DeviceModel device);
  Future<void> clearCache();
}

class DeviceLocalDataSourceImpl implements DeviceLocalDataSource {
  final SharedPreferences _prefs;
  static const String _cacheKey = 'cached_devices';

  DeviceLocalDataSourceImpl(this._prefs);

  @override
  Future<List<DeviceModel>> getCachedDevices() async {
    final json = _prefs.getString(_cacheKey);
    if (json == null) return [];
    final list = jsonDecode(json) as List;
    return list
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> cacheDevices(List<DeviceModel> devices) async {
    final json = jsonEncode(devices.map((e) => e.toJson()).toList());
    await _prefs.setString(_cacheKey, json);
  }

  @override
  Future<DeviceModel?> getCachedDevice(String id) async {
    final devices = await getCachedDevices();
    try {
      return devices.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheDevice(DeviceModel device) async {
    final devices = await getCachedDevices();
    final index = devices.indexWhere((d) => d.id == device.id);
    if (index >= 0) {
      devices[index] = device;
    } else {
      devices.add(device);
    }
    await cacheDevices(devices);
  }

  @override
  Future<void> clearCache() async {
    await _prefs.remove(_cacheKey);
  }
}
