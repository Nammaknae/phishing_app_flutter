package com.example.smishing_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.UUID
import java.util.concurrent.Executors

class AppNotificationListenerService : NotificationListenerService() {
    private val worker = Executors.newSingleThreadExecutor()

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return

        val packageName = sbn.packageName ?: return
        if (!isAllowedPackage(packageName)) {
            return
        }

        // 로그인(JWT) 없으면 수집·전송하지 않음
        val accessToken = NativeSessionStore.readAccessToken(this)
        if (accessToken.isNullOrBlank()) {
            Log.d(TAG, "Skip: not logged in pkg=$packageName")
            return
        }

        val extras: Bundle = sbn.notification.extras ?: Bundle.EMPTY
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val messageText = collectNotificationText(extras)

        if (messageText.isEmpty()) return

        val appName = resolveAppName(packageName)
        val sender = title.ifBlank { "알 수 없음" }
        val urls = extractUrls(messageText)

        val payload = linkedMapOf<String, Any?>(
            "packageName" to packageName,
            "appName" to appName,
            "sender" to sender,
            "title" to title,
            "text" to messageText,
            "message" to messageText,
            "urls" to urls,
        )

        // 앱이 포그라운드(Flutter EventChannel 연결)면 Dart 파이프라인에 위임
        if (NotificationEventSink.isForegroundBridgeActive()) {
            NotificationEventSink.emit(payload)
            return
        }

        worker.execute {
            sendScanAndNotify(
                accessToken = accessToken,
                appName = appName,
                sender = sender,
                message = messageText.take(MAX_MESSAGE_LENGTH),
            )
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        worker.shutdownNow()
    }

    private fun isAllowedPackage(packageName: String): Boolean {
        if (ALLOWED_PACKAGES.contains(packageName)) return true
        return packageName.contains("messaging", ignoreCase = true) ||
            packageName.contains("mms", ignoreCase = true) ||
            packageName.contains("sms", ignoreCase = true)
    }

    private fun resolveAppName(packageName: String): String {
        return when (packageName) {
            "com.kakao.talk" -> "카카오톡"
            "com.samsung.android.messaging" -> "삼성 메시지"
            "com.google.android.apps.messaging" -> "Google 메시지"
            "com.android.mms" -> "문자"
            else -> packageName
        }
    }

    private fun collectNotificationText(extras: Bundle): String {
        val chunks = mutableListOf<String>()

        fun add(raw: CharSequence?) {
            val text = raw?.toString()?.trim().orEmpty()
            if (text.isNotEmpty()) chunks.add(text)
        }

        add(extras.getCharSequence(Notification.EXTRA_TITLE))
        add(extras.getCharSequence(Notification.EXTRA_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_BIG_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_SUB_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT))
        add(extras.getCharSequence(Notification.EXTRA_INFO_TEXT))

        extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES)
            ?.forEach { add(it) }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val parcelables = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (!parcelables.isNullOrEmpty()) {
                val messages =
                    Notification.MessagingStyle.Message.getMessagesFromBundleArray(parcelables)
                messages.forEach { add(it.text) }
            }
        }

        return chunks.joinToString(separator = "\n").trim()
    }

    private fun extractUrls(content: String): List<String> {
        return URL_REGEX.findAll(content)
            .map { normalizeDetectedUrl(it.value) }
            .filter { it.isNotBlank() }
            .distinct()
            .toList()
    }

    private fun normalizeDetectedUrl(value: String): String {
        val trimmed = value.trim().trimEnd('.', ',', ';', ':', ')', ']', '}', '>', '!', '?')
        return if (trimmed.startsWith("www.", ignoreCase = true)) {
            "https://$trimmed"
        } else {
            trimmed
        }
    }

    private fun sendScanAndNotify(
        accessToken: String,
        appName: String,
        sender: String,
        message: String,
    ) {
        var connection: HttpURLConnection? = null
        try {
            val baseUrl = NativeSessionStore.readBaseUrl(this)
            val endpoint = "$baseUrl/api/scans"
            val deviceId = readOrCreateDeviceId()

            connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15_000
                readTimeout = 15_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                setRequestProperty("Accept", "application/json")
                setRequestProperty("Authorization", "Bearer $accessToken")
            }

            val payload = JSONObject()
                .put("appName", appName)
                .put("sender", sender)
                .put("message", message)
                .put("device_id", deviceId)
                .toString()

            OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use { writer ->
                writer.write(payload)
            }

            val status = connection.responseCode
            val body = readResponseBody(connection, status)
            if (status !in 200..299) {
                Log.e(TAG, "Scan failed status=$status body=$body")
                return
            }

            val json = JSONObject(body)
            val riskLevel = json.optString("riskLevel", "SAFE").uppercase()
            if (riskLevel == "WARNING" || riskLevel == "CAUTION") {
                showLocalNotification(
                    appName = appName,
                    sender = sender,
                    preview = message,
                    riskLevel = riskLevel,
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "Scan request failed error=${e.message}", e)
        } finally {
            connection?.disconnect()
        }
    }

    private fun showLocalNotification(
        appName: String,
        sender: String,
        preview: String,
        riskLevel: String,
    ) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val isWarning = riskLevel == "WARNING"
        val channelId = if (isWarning) CHANNEL_WARNING else CHANNEL_CAUTION

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                if (isWarning) "스미싱 경고" else "스미싱 주의",
                if (isWarning) NotificationManager.IMPORTANCE_HIGH
                else NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)
        }

        val bodyPreview = if (preview.length > 80) preview.take(80) + "..." else preview
        val title = if (isWarning) "스미싱 위험 경고" else "스미싱 주의 알림"
        val body = "[$appName] $sender\n$bodyPreview\n등급: $riskLevel"

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(
                if (isWarning) NotificationCompat.PRIORITY_HIGH
                else NotificationCompat.PRIORITY_DEFAULT,
            )
            .setAutoCancel(true)
            .build()

        manager.notify(UUID.randomUUID().hashCode(), notification)
    }

    private fun readOrCreateDeviceId(): String {
        val prefs = getSharedPreferences("smishing_device", Context.MODE_PRIVATE)
        val existing = prefs.getString("device_id", null)
        if (!existing.isNullOrBlank()) return existing

        val generated = "android-native-${System.currentTimeMillis()}"
        prefs.edit().putString("device_id", generated).apply()
        return generated
    }

    private fun readResponseBody(connection: HttpURLConnection, status: Int): String {
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        if (stream == null) return ""
        return stream.bufferedReader().use(BufferedReader::readText)
    }

    companion object {
        private const val TAG = "AppNotifListener"
        private const val MAX_MESSAGE_LENGTH = 4000
        private const val CHANNEL_WARNING = "smishing_warning"
        private const val CHANNEL_CAUTION = "smishing_caution"

        private val ALLOWED_PACKAGES = setOf(
            "com.kakao.talk",
            "com.samsung.android.messaging",
            "com.google.android.apps.messaging",
            "com.android.mms",
        )

        private val URL_REGEX = Regex(
            """(?:https?://|www\.)[^\s<>"']+""",
            RegexOption.IGNORE_CASE,
        )
    }
}
