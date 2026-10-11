package com.oamanager.agent.android.data

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.oamanager.agent.network.TokenStorage

/**
 * 보안 저장소.
 *
 * Android Keystore 기반 [EncryptedSharedPreferences]만 사용한다. 보안 저장소를
 * 열 수 없으면 일반 SharedPreferences로 내려가지 않고 앱이 세션을 사용하지
 * 못하도록 실패한다.
 *
 * v2 전환 시 이전의 평문 fallback 저장소와 기존 세션을 삭제한다. 따라서
 * 업데이트 후에는 사용자가 다시 로그인해야 할 수 있다.
 */
class AgentPreferences(context: Context) : TokenStorage {

    private val appContext = context.applicationContext
    private val prefs: SharedPreferences

    init {
        removeLegacyPlaintextStore(appContext)
        prefs = createEncryptedPreferences(appContext)

        // Background worker/service가 Activity보다 먼저 시작해도 구 공용 세션을
        // 사용할 수 없도록 저장소를 여는 즉시 전환을 적용한다. 보안 저장소
        // 전환 전의 토큰은 신뢰하지 않으므로 명시적 재로그인을 요구한다.
        if (!prefs.getBoolean(KEY_SECURE_STORAGE_MIGRATED, false)) {
            val committed = prefs.edit()
                .remove(KEY_ACCESS_TOKEN)
                .remove(KEY_REFRESH_TOKEN)
                .putBoolean(KEY_PERSONAL_ACCOUNT_AUTH_MIGRATED, true)
                .putBoolean(KEY_SECURE_STORAGE_MIGRATED, true)
                .commit()
            check(committed) { "Encrypted token-store migration could not be persisted." }
        }
    }

    private fun createEncryptedPreferences(context: Context): SharedPreferences = try {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

        EncryptedSharedPreferences.create(
            context,
            SECURE_PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    } catch (e: Exception) {
        throw IllegalStateException(
            "Android Keystore-backed storage is unavailable; refusing to use a plaintext session store.",
            e,
        )
    }

    private fun removeLegacyPlaintextStore(context: Context) {
        val legacyPrefs = context.getSharedPreferences(LEGACY_PLAINTEXT_PREFS_NAME, Context.MODE_PRIVATE)
        if (legacyPrefs.all.isNotEmpty()) {
            check(legacyPrefs.edit().clear().commit()) {
                "Legacy plaintext token store could not be cleared."
            }
        }
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
        private const val SECURE_PREFS_NAME = "oa_agent_prefs"
        private const val LEGACY_PLAINTEXT_PREFS_NAME = "oa_agent_prefs_plain"
        private const val KEY_ASSET_UID = "asset_uid"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_PERSONAL_ACCOUNT_AUTH_MIGRATED = "personal_account_auth_migrated_v1"
        private const val KEY_SECURE_STORAGE_MIGRATED = "secure_storage_migrated_v2"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat_time"
        private const val KEY_INTERVAL = "interval_minutes"
        private const val KEY_USER_NAME = "asset_user_name"
        private const val KEY_EMPLOYEE_ID = "employee_id"
        private const val KEY_LAST_VERIFIED = "last_verified_at"
    }
}
