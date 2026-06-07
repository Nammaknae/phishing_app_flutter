import 'package:flutter/services.dart';

import '../config/api_config.dart';
import 'token_storage.dart';

/// Android 알림 리스너가 백그라운드에서 JWT·API 주소를 읽을 수 있도록 동기화합니다.
class NativeAuthBridge {
  static const _channel = MethodChannel('smishing/native_session');

  static Future<void> syncSession() async {
    final token = await TokenStorage.readAccessToken();
    if (token == null || token.isEmpty) {
      await clearSession();
      return;
    }

    try {
      await _channel.invokeMethod<void>('syncSession', <String, dynamic>{
        'accessToken': token,
        'baseUrl': ApiConfig.baseUrl,
      });
    } on MissingPluginException {
      // iOS/데스크톱 등 네이티브 브릿지 미지원 환경
    } on PlatformException {
      // 네이티브 저장 실패 — 포그라운드 Flutter 파이프라인은 계속 동작
    }
  }

  static Future<void> clearSession() async {
    try {
      await _channel.invokeMethod<void>('clearSession');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }
}
