import 'package:device_info_plus/device_info_plus.dart';

class DeviceService {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _deviceId;

  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    final androidInfo = await _deviceInfo.androidInfo;
    _deviceId = androidInfo.id;
    return _deviceId!;
  }
} 