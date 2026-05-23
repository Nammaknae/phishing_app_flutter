import 'api_client.dart';

class ApiService {
  static Future<Map<String, dynamic>> scanText({
    required String deviceId,
    required String content,
    required String sourceApp,
    String? sender,
  }) async {
    return ApiClient.post(
      '/api/scans/text',
      body: {
        'device_id': deviceId,
        'content': content,
        'source_app': sourceApp,
        'sender': sender,
      },
    );
  }

  static Future<Map<String, dynamic>> scanUrl({
    required String deviceId,
    required String url,
    required String sourceApp,
  }) async {
    return ApiClient.post(
      '/api/scans/url',
      body: {
        'device_id': deviceId,
        'url': url,
        'source_app': sourceApp,
      },
    );
  }

  static Future<Map<String, dynamic>> checkUrl({
    required String url,
    required String sourceApp,
    required String messageText,
  }) {
    // 기존 코드 호환용.
    // 이제는 URL만 검사하지 말고 전체 문자 내용을 검사하는 scanText를 사용한다.
    return scanText(
      deviceId: 'android-test-device',
      content: messageText,
      sourceApp: sourceApp,
      sender: 'manual',
    );
  }
}