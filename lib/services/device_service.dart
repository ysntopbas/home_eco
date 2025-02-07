import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static const String _keyUserId = 'user_id';
  static String? _cachedUserId;
  static final _uuid = Uuid();

  static Future<String> getUserId() async {
    // Önce cache'e bakıyoruz
    if (_cachedUserId != null) {
      return _cachedUserId!;
    }

    // SharedPreferences'dan ID'yi almaya çalışıyoruz
    final prefs = await SharedPreferences.getInstance();
    _cachedUserId = prefs.getString(_keyUserId);

    // Eğer ID yoksa yeni oluşturup kaydediyoruz
    if (_cachedUserId == null) {
      _cachedUserId = _uuid.v4();
      await prefs.setString(_keyUserId, _cachedUserId!);
    }

    return _cachedUserId!;
  }
} 