import 'package:flutter/services.dart';

class NotificationAccessService {
  static const MethodChannel _channel = MethodChannel(
    'smishing/notification_access',
  );

  static Future<bool> isNotificationListenerEnabled() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isNotificationListenerEnabled',
          ) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> openNotificationListenerSettings() async {
    try {
      await _channel.invokeMethod<void>('openNotificationListenerSettings');
    } on MissingPluginException {
      return;
    }
  }
}
