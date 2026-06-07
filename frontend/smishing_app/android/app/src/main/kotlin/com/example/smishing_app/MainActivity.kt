package com.example.smishing_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationListenerEnabled" -> {
                    result.success(
                        NotificationListenerPermission.isEnabled(applicationContext),
                    )
                }

                "openNotificationListenerSettings" -> {
                    NotificationListenerPermission.openSettings(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NATIVE_SESSION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncSession" -> {
                    val token = call.argument<String>("accessToken")
                    val baseUrl = call.argument<String>("baseUrl")
                    if (token.isNullOrBlank() || baseUrl.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "accessToken/baseUrl required", null)
                        return@setMethodCallHandler
                    }
                    NativeSessionStore.syncSession(applicationContext, token, baseUrl)
                    result.success(null)
                }

                "clearSession" -> {
                    NativeSessionStore.clearSession(applicationContext)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_EVENT_CHANNEL,
        ).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    NotificationEventSink.sink = events
                }

                override fun onCancel(arguments: Any?) {
                    NotificationEventSink.sink = null
                }
            },
        )
    }

    companion object {
        private const val PERMISSION_CHANNEL = "smishing/permissions"
        private const val NATIVE_SESSION_CHANNEL = "smishing/native_session"
        private const val NOTIFICATION_EVENT_CHANNEL = "smishing/notifications"
    }
}
