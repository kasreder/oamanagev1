package com.oamanager.agent.android.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.oamanager.agent.network.TokenStorage

/**
 * 보안 저장소.
 *
 * EncryptedSharedPreferences 사용을 시도하고,
 * 실패 시 일반 SharedPreferences로 fallback합니다.
 */
class AgentPreferences(context: Context) : TokenStorage {

    private val prefs: SharedPreferences = try {
        androidx.security.crypto.EncryptedSharedPreferences.create(
            "oa_agent_prefs",
            androidx.security.crypto.MasterKeys.getOrCreate(
                androidx.security.crypto.MasterKeys.AES256_GCM_SPEC
            ),
            context,
            androidx.security.crypto.EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            androidx.security.crypto.EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (e: Exception) {
        Log.w("AgentPreferences", "EncryptedSharedPreferences 실패, 일반 모드 사용", e)
        context.getSharedPreferences("oa_agent_prefs_plain", Context.MODE_PRIVATE)
    }

    // ─── 자산 식별자 ────────────────────────────────────────────────────

    var assetUid: String?
        get() = prefs.getString(KEY_ASSET_UID, null)
        set(value) = prefs.edit().putString(KEY_ASSET_UID, value).apply()

    // ─── 인증 토큰 (TokenStorage 구현) ──────────────────────────────────

    override var accessToken: String?
        get() = prefs.getString(KEY_ACCESS_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_ACCESS_TOKEN, value).apply()

    override var refreshToken: String?
        get() = prefs.getString(KEY_REFRESH_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_REFRESH_TOKEN, value).apply()

    // ─── Heartbeat ──────────────────────────────────────────────────────

    var lastHeartbeatTime: Long
        get() = prefs.getLong(KEY_LAST_HEARTBEAT, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_HEARTBEAT, value).apply()

    var intervalMinutes: Int
        get() = prefs.getInt(KEY_INTERVAL, 5)
        set(value) = prefs.edit().putInt(KEY_INTERVAL, value).apply()

    // ─── 사용자 정보 ────────────────────────────────────────────────────

    var assetUserName: String?
        get() = prefs.getString(KEY_USER_NAME, null)
        set(value) = prefs.edit().putString(KEY_USER_NAME, value).apply()

    var employeeId: String?
        get() = prefs.getString(KEY_EMPLOYEE_ID, null)
        set(value) = prefs.edit().putString(KEY_EMPLOYEE_ID, value).apply()

    var lastVerifiedAt: Long
        get() = prefs.getLong(KEY_LAST_VERIFIED, 0L)
        set(value) = prefs.edit().putLong(KEY_LAST_VERIFIED, value).apply()

    // ─── Keys ───────────────────────────────────────────────────────────

    companion object {
        private const val KEY_ASSET_UID = "asset_uid"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat_time"
        private const val KEY_INTERVAL = "interval_minutes"
        private const val KEY_USER_NAME = "asset_user_name"
        private const val KEY_EMPLOYEE_ID = "employee_id"
        private const val KEY_LAST_VERIFIED = "last_verified_at"
    }
}
