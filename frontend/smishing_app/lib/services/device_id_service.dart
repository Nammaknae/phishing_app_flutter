import 'package:shared_preferences/shared_preferences.dart';

/// 기기별 고유 식별자 — 알림·스캔 요청 시 서버에 전달합니다.
class DeviceIdService {
  static const _key = 'device_id';

  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final generated =
        'android-${DateTime.now().millisecondsSinceEpoch}-${prefs.hashCode}';
    await prefs.setString(_key, generated);
    return generated;
  }
}
