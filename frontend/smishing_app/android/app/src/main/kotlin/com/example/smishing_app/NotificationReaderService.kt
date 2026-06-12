package com.example.smishing_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.Locale
import java.util.concurrent.Executors
import kotlin.math.roundToInt

class NotificationReaderService : NotificationListenerService() {
    private val worker = Executors.newSingleThreadExecutor()
    private val recentScanCache = mutableMapOf<String, Long>()

    override fun onCreate() {
        super.onCreate()
        createRiskNotificationChannel()
    }

    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "listener connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.d(TAG, "listener disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        Log.d(TAG, "received packageName=${sbn.packageName}")
        if (shouldSkipNotification(sbn)) return

        val extras = sbn.notification.extras ?: Bundle.EMPTY
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val content = collectNotificationContent(extras).take(MAX_CONTENT_LENGTH)

        if (content.length < MIN_CONTENT_LENGTH) {
            Log.d(TAG, "skipped packageName=${sbn.packageName}, reason=short_content")
            return
        }
        if (isDuplicateScan(sbn.packageName, content)) {
            Log.d(TAG, "skipped packageName=${sbn.packageName}, reason=duplicate")
            return
        }

        Log.d(TAG, "scanning packageName=${sbn.packageName}, title=$title, content=$content")

        worker.execute {
            sendToBackend(
                content = content,
                sender = sbn.packageName.ifBlank { title.ifBlank { "notification" } },
            )
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }

    private fun shouldSkipNotification(sbn: StatusBarNotification): Boolean {
        val sourcePackage = sbn.packageName
        if (sourcePackage == packageName) {
            Log.d(TAG, "skipped packageName=$sourcePackage, reason=self")
            return true
        }
        if (sourcePackage !in ALLOWED_PACKAGES) {
            Log.d(TAG, "skipped packageName=$sourcePackage, reason=not_allowed")
            return true
        }

        val notification = sbn.notification
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) {
            Log.d(TAG, "skipped packageName=$sourcePackage, reason=group_summary")
            return true
        }

        val isSystemCategory = notification.category == Notification.CATEGORY_SYSTEM ||
            notification.category == Notification.CATEGORY_SERVICE ||
            notification.category == Notification.CATEGORY_STATUS

        if (isSystemCategory && sourcePackage != ADB_TEST_PACKAGE) {
            Log.d(TAG, "skipped packageName=$sourcePackage, reason=system_category")
            return true
        }
        return false
    }

    private fun collectNotificationContent(extras: Bundle): String {
        val chunks = mutableListOf<String>()

        fun add(raw: CharSequence?) {
            val text = raw?.toString()?.trim().orEmpty()
            if (text.isNotEmpty() && !chunks.contains(text)) {
                chunks.add(text)
            }
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
            @Suppress("DEPRECATION")
            val rawMessages = extras.getParcelableArray(Notification.EXTRA_MESSAGES)
            if (!rawMessages.isNullOrEmpty()) {
                val messages =
                    Notification.MessagingStyle.Message.getMessagesFromBundleArray(rawMessages)
                messages.forEach { add(it.text) }
            }
        }

        return chunks.joinToString(separator = "\n").trim()
    }

    private fun isDuplicateScan(packageName: String, content: String): Boolean {
        val now = System.currentTimeMillis()
        recentScanCache.entries.removeAll { now - it.value > DUPLICATE_WINDOW_MS }

        val key = "$packageName|$content"
        val lastScannedAt = recentScanCache[key]
        if (lastScannedAt != null && now - lastScannedAt <= DUPLICATE_WINDOW_MS) {
            return true
        }

        recentScanCache[key] = now
        return false
    }

    private fun sendToBackend(content: String, sender: String) {
        var connection: HttpURLConnection? = null

        try {
            connection = (URL(SCAN_TEXT_URL).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 10_000
                readTimeout = 10_000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=UTF-8")
                setRequestProperty("Accept", "application/json")
            }

            val payload = JSONObject()
                .put("device_id", DEVICE_ID)
                .put("content", content)
                .put("source_app", "notification")
                .put("sender", sender)
                .toString()

            OutputStreamWriter(connection.outputStream, StandardCharsets.UTF_8).use { writer ->
                writer.write(payload)
            }

            val status = connection.responseCode
            val body = readResponseBody(connection, status)
            if (status !in 200..299) {
                Log.w(TAG, "scan failed status=$status body=$body")
                return
            }

            val response = JSONObject(body)
            val grade = response
                .optString("final_risk_grade", "")
                .uppercase(Locale.US)
            val score = readRiskScore(response)

            Log.d(TAG, "scan result grade=$grade score=$score")

            if (shouldShowRiskAlert(grade, score)) {
                showRiskNotification(score)
            }
        } catch (e: Exception) {
            Log.e(TAG, "scan request failed: ${e.message}", e)
        } finally {
            connection?.disconnect()
        }
    }

    private fun readResponseBody(connection: HttpURLConnection, status: Int): String {
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        if (stream == null) return ""
        return stream.bufferedReader().use(BufferedReader::readText)
    }

    private fun readRiskScore(response: JSONObject): Int {
        val raw = response.opt("final_risk_score") ?: return 0
        return when (raw) {
            is Number -> raw.toDouble().roundToInt()
            is String -> raw.toDoubleOrNull()?.roundToInt() ?: 0
            else -> 0
        }
    }

    private fun shouldShowRiskAlert(grade: String, score: Int): Boolean {
        return when (grade) {
            "MALICIOUS", "DANGER" -> true
            "SUSPICIOUS" -> score >= MIN_ALERT_SCORE
            else -> false
        }
    }

    private fun createRiskNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            RISK_CHANNEL_ID,
            "스미싱 위험 알림",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "스미싱 위험 알림을 표시합니다."
        }

        notificationManager.createNotificationChannel(channel)
    }

    private fun showRiskNotification(score: Int) {
        createRiskNotificationChannel()

        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pendingIntent = launchIntent?.let {
            PendingIntent.getActivity(
                this,
                0,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        val message = "위험도 ${score}점: 링크를 열지 마세요."

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, RISK_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("스미싱 의심 알림")
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .setPriority(Notification.PRIORITY_HIGH)

        if (pendingIntent != null) {
            builder.setContentIntent(pendingIntent)
        }

        notificationManager.notify(RISK_NOTIFICATION_ID, builder.build())
        Log.d(TAG, "warning notification shown")
    }

    private val notificationManager: NotificationManager
        get() = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    companion object {
        private const val TAG = "NotificationReader"
        private const val DEVICE_ID = "android-notification-listener"
        private const val SCAN_TEXT_URL = "https://api.maknae.synology.me/api/scans/text"
        private const val RISK_CHANNEL_ID = "smishing_risk_alerts"
        private const val RISK_NOTIFICATION_ID = 20260612
        private const val MAX_CONTENT_LENGTH = 4000
        private const val MIN_CONTENT_LENGTH = 8
        private const val MIN_ALERT_SCORE = 70
        private const val DUPLICATE_WINDOW_MS = 60_000L
        private const val ADB_TEST_PACKAGE = "com.android.shell"

        private val ALLOWED_PACKAGES = setOf(
            "com.samsung.android.messaging",
            "com.google.android.apps.messaging",
            "com.kakao.talk",
            "com.ktcs.whowho",
            ADB_TEST_PACKAGE, // 테스트용
        )
    }
}
