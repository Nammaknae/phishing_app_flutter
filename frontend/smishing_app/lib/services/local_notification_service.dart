import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/alert_scan_result.dart';

/// WARNING / CAUTION 등급일 때만 기기 로컬 푸시 알림을 표시합니다.
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _warningChannelId = 'smishing_warning';
  static const String _cautionChannelId = 'smishing_caution';

  static Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Post Notifications 권한은 main()의 AppPermissionService에서 요청합니다.
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _warningChannelId,
          '스미싱 경고',
          description: '위험 등급(WARNING) 스미싱 탐지 알림',
          importance: Importance.high,
        ),
      );

      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _cautionChannelId,
          '스미싱 주의',
          description: '주의 등급(CAUTION) 스미싱 탐지 알림',
          importance: Importance.defaultImportance,
        ),
      );
    }

    _initialized = true;
  }

  static Future<void> showRiskAlert({
    required AlertScanResult result,
    required String appName,
    required String sender,
    required String preview,
  }) async {
    if (!result.shouldNotify) return;

    await initialize();

    final isWarning = result.isWarning;
    final channelId = isWarning ? _warningChannelId : _cautionChannelId;
    final title = isWarning ? '스미싱 위험 경고' : '스미싱 주의 알림';

    final bodyPreview = preview.length > 80
        ? '${preview.substring(0, 80)}...'
        : preview;

    final body =
        '[$appName] $sender\n$bodyPreview\n등급: ${result.riskLevel}';

    final notificationId = result.id.hashCode & 0x7fffffff;

    await _plugin.show(
      notificationId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          isWarning ? '스미싱 경고' : '스미싱 주의',
          channelDescription: isWarning
              ? '위험 등급 스미싱 탐지 알림'
              : '주의 등급 스미싱 탐지 알림',
          importance:
              isWarning ? Importance.high : Importance.defaultImportance,
          priority: isWarning ? Priority.high : Priority.defaultPriority,
          color: isWarning
              ? const Color(0xFFE53935)
              : const Color(0xFFFFA000),
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }
}
