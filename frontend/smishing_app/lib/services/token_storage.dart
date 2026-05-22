import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// JWT access token을 기기 보안 저장소에 보관합니다.
class TokenStorage {
  static const _accessTokenKey = 'access_token';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> readAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: _accessTokenKey);
  }
}
