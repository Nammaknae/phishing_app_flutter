import '../app_state.dart';
import '../models/alert_scan_result.dart';
import 'local_notification_service.dart';
import 'notification_scan_api.dart';

/// 실시간 알림 수집 → 로그인 확인 → 서버 분석 → 조건부 로컬 알림
class NotificationPipelineService {
  /// 로그인 상태가 아니면 즉시 null 반환(Early Return).
  static Future<AlertScanResult?> processNotification({
    required String appName,
    required String sender,
    required String message,
  }) async {
    if (!appState.isLoggedIn) {
      return null;
    }

    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final result = await NotificationScanApi.submitNotification(
      appName: appName,
      sender: sender,
      message: trimmed,
    );

    if (result.shouldNotify) {
      await LocalNotificationService.showRiskAlert(
        result: result,
        appName: appName,
        sender: sender,
        preview: trimmed,
      );
    }

    return result;
  }
}
