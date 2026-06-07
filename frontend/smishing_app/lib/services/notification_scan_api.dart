import '../models/alert_scan_result.dart';
import 'api_client.dart';
import 'device_id_service.dart';

/// 로그인 사용자 알림 본문을 분석 서버로 전송합니다.
class NotificationScanApi {
  static Future<AlertScanResult> submitNotification({
    required String appName,
    required String sender,
    required String message,
  }) async {
    final deviceId = await DeviceIdService.getDeviceId();

    final data = await ApiClient.post(
      '/api/scans',
      body: <String, dynamic>{
        'appName': appName,
        'sender': sender,
        'message': message,
        'device_id': deviceId,
      },
    );

    return AlertScanResult.fromJson(data);
  }
}
