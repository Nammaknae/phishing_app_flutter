package com.example.smishing_app

import io.flutter.plugin.common.EventChannel

object NotificationEventSink {
    @Volatile
    var sink: EventChannel.EventSink? = null

    fun emit(payload: Map<String, Any?>) {
        val active = sink ?: return
        try {
            active.success(payload)
        } catch (_: Exception) {
            // Flutter 엔진이 아직 준비되지 않은 경우 무시
        }
    }

    fun isForegroundBridgeActive(): Boolean = sink != null
}
