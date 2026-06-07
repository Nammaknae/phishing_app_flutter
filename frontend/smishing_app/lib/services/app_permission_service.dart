import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Android 알림 읽기·발송 권한 확인 및 설정 화면 이동
class AppPermissionService {
  static const _channel = MethodChannel('smishing/permissions');

  /// Android 13+ 알림 발송(Post Notifications) 권한 요청
  static Future<bool> requestPostNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// 앱 초기화 시 호출 — 로컬 푸시용 권한 팝업
  static Future<void> requestPostNotificationsOnStartup() async {
    await requestPostNotificationPermission();
  }

  /// 알림 접근(Notification Listener) 허용 여부
  static Future<bool> isNotificationListenerEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      final enabled = await _channel.invokeMethod<bool>(
        'isNotificationListenerEnabled',
      );
      return enabled ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// 시스템 [알림 접근 허용] 설정 화면으로 이동
  static Future<void> openNotificationListenerSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod<void>('openNotificationListenerSettings');
    } on MissingPluginException {
      // ignore
    } on PlatformException {
      // ignore
    }
  }

  /// 스캔 기능 활성화에 필요한 권한이 모두 준비되었는지 확인
  static Future<PermissionCheckResult> checkScanPermissions() async {
    final postGranted = Platform.isAndroid
        ? (await Permission.notification.status).isGranted
        : true;
    final listenerEnabled = await isNotificationListenerEnabled();

    return PermissionCheckResult(
      postNotificationGranted: postGranted,
      notificationListenerEnabled: listenerEnabled,
    );
  }

  /// 권한이 없을 때 안내 다이얼로그 표시 후 설정 화면으로 이동
  static Future<void> promptNotificationListenerIfNeeded(
    BuildContext context, {
    bool force = false,
  }) async {
    final enabled = await isNotificationListenerEnabled();
    if (enabled && !force) return;
    if (!context.mounted) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: Color(0xFF1976D2)),
            SizedBox(width: 8),
            Expanded(child: Text('알림 접근 허용 필요')),
          ],
        ),
        content: const Text(
          '카카오톡·문자 알림을 읽어 스미싱을 탐지하려면\n'
          '시스템 설정에서 [스미싱 탐지기]의\n'
          '[알림 접근 허용]을 켜야 합니다.\n\n'
          '설정 화면으로 이동할까요?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );

    if (shouldOpen == true) {
      await openNotificationListenerSettings();
    }
  }

  /// 로그인 사용자가 홈에 진입했을 때 권한 점검
  static Future<void> ensurePermissionsForLoggedInUser(
    BuildContext context,
  ) async {
    if (!context.mounted) return;

    await requestPostNotificationPermission();

    final listenerEnabled = await isNotificationListenerEnabled();
    if (!listenerEnabled && context.mounted) {
      await promptNotificationListenerIfNeeded(context);
    }
  }
}

class PermissionCheckResult {
  final bool postNotificationGranted;
  final bool notificationListenerEnabled;

  const PermissionCheckResult({
    required this.postNotificationGranted,
    required this.notificationListenerEnabled,
  });

  bool get isReadyForScan =>
      postNotificationGranted && notificationListenerEnabled;
}
