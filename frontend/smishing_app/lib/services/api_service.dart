import 'api_client.dart';

class ApiService {
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
    return scanUrl(
      deviceId: 'android-test-device',
      url: url,
      sourceApp: sourceApp,
    );
  }
}
