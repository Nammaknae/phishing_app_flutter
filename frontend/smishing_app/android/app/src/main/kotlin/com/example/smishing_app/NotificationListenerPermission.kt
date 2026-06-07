package com.example.smishing_app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.provider.Settings

object NotificationListenerPermission {
    fun isEnabled(context: Context): Boolean {
        val packageName = context.packageName
        val flat = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners",
        ) ?: return false

        return flat.split(":")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .any { ComponentName.unflattenFromString(it)?.packageName == packageName }
    }

    fun openSettings(context: Context) {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }
}
