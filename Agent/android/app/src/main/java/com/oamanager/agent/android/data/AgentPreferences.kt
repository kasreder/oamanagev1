package com.oamanager.agent.android.data

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import com.oamanager.agent.network.TokenStorage

/**
 * EncryptedSharedPreferences를 래핑한 보안 저장소.
 *
 * AES-256-GCM으로 모든 값을 암호화합니다.
 * [TokenStorage] 인터페이스를 구현하여 AuthManager에 주입됩니다.
 */
class AgentPreferences(context: Context) : TokenStorage {

    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        "oa_agent_prefs",
        MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC),
        context,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
    )

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
        get() = prefs.getInt(KEY_INTERVAL, 15)
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

    // ─── FCM ────────────────────────────────────────────────────────────

    var fcmToken: String?
        get() = prefs.getString(KEY_FCM_TOKEN, null)
        set(value) = prefs.edit().putString(KEY_FCM_TOKEN, value).apply()

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
        private const val KEY_FCM_TOKEN = "fcm_token"
    }
}
