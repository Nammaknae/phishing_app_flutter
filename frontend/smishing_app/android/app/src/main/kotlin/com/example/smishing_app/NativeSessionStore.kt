package com.example.smishing_app

import android.content.Context

object NativeSessionStore {
    private const val PREFS = "smishing_native_session"
    private const val KEY_TOKEN = "access_token"
    private const val KEY_BASE_URL = "base_url"

    fun syncSession(context: Context, accessToken: String, baseUrl: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_TOKEN, accessToken)
            .putString(KEY_BASE_URL, baseUrl.trimEnd('/'))
            .apply()
    }

    fun clearSession(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    fun readAccessToken(context: Context): String? {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TOKEN, null)
            ?.takeIf { it.isNotBlank() }
    }

    fun readBaseUrl(context: Context): String {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BASE_URL, null)
            ?.takeIf { it.isNotBlank() }
            ?: ApiConstants.DEFAULT_BASE_URL
    }
}
