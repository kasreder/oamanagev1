package com.oamanager.agent.windows.data

import com.oamanager.agent.network.TokenStorage
import java.io.File
import java.security.SecureRandom
import java.util.*
import javax.crypto.Cipher
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.PBEKeySpec
import javax.crypto.spec.SecretKeySpec

/**
 * Windows 에이전트 설정 저장소.
 *
 * AES-256-CBC 암호화로 모든 값을 보호합니다.
 * 키는 머신 고유 식별자 + 고정 솔트에서 파생됩니다 (DPAPI 대안).
 *
 * 저장 위치: %APPDATA%\OAAgent\agent.enc
 * [TokenStorage] 인터페이스를 구현하여 AuthManager에 주입됩니다.
 */
class WindowsPreferences : TokenStorage {

    private val configDir: File = File(
        System.getenv("APPDATA") ?: System.getProperty("user.home"),
        "OAAgent"
    ).also { it.mkdirs() }

    private val configFile = File(configDir, "agent.enc")
    private val props = Properties()

    init {
        load()
    }

    // ─── TokenStorage 구현 ──────────────────────────────────────────────

    override var accessToken: String?
        get() = getString(KEY_ACCESS_TOKEN)
        set(value) = putString(KEY_ACCESS_TOKEN, value)

    override var refreshToken: String?
        get() = getString(KEY_REFRESH_TOKEN)
        set(value) = putString(KEY_REFRESH_TOKEN, value)

    // ─── 에이전트 설정 ──────────────────────────────────────────────────

    var assetUid: String?
        get() = getString(KEY_ASSET_UID)
        set(value) = putString(KEY_ASSET_UID, value)

    var intervalMinutes: Int
        get() = getString(KEY_INTERVAL)?.toIntOrNull() ?: 15
        set(value) = putString(KEY_INTERVAL, value.toString())

    var lastHeartbeatTime: Long
        get() = getString(KEY_LAST_HEARTBEAT)?.toLongOrNull() ?: 0L
        set(value) = putString(KEY_LAST_HEARTBEAT, value.toString())

    var assetUserName: String?
        get() = getString(KEY_USER_NAME)
        set(value) = putString(KEY_USER_NAME, value)

    var employeeId: String?
        get() = getString(KEY_EMPLOYEE_ID)
        set(value) = putString(KEY_EMPLOYEE_ID, value)

    var lastVerifiedAt: Long
        get() = getString(KEY_LAST_VERIFIED)?.toLongOrNull() ?: 0L
        set(value) = putString(KEY_LAST_VERIFIED, value.toString())

    var fcmToken: String?
        get() = getString(KEY_FCM_TOKEN)
        set(value) = putString(KEY_FCM_TOKEN, value)

    // ─── 내부 ───────────────────────────────────────────────────────────

    private fun getString(key: String): String? {
        return props.getProperty(key)
    }

    private fun putString(key: String, value: String?) {
        if (value != null) {
            props.setProperty(key, value)
        } else {
            props.remove(key)
        }
        save()
    }

    // ─── 암호화 저장/로드 ───────────────────────────────────────────────

    private fun load() {
        if (!configFile.exists()) return
        try {
            val encrypted = configFile.readBytes()
            val decrypted = decrypt(encrypted)
            props.load(decrypted.inputStream())
        } catch (e: Exception) {
            System.err.println("Failed to load preferences: ${e.message}")
            // 파일 손상 시 초기화
            props.clear()
        }
    }

    private fun save() {
        try {
            val baos = java.io.ByteArrayOutputStream()
            props.store(baos, null)
            val encrypted = encrypt(baos.toByteArray())
            configFile.writeBytes(encrypted)
        } catch (e: Exception) {
            System.err.println("Failed to save preferences: ${e.message}")
        }
    }

    // ─── AES-256-CBC 암호화 ─────────────────────────────────────────────

    private fun encrypt(data: ByteArray): ByteArray {
        val iv = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey(), IvParameterSpec(iv))
        val encrypted = cipher.doFinal(data)
        return iv + encrypted // IV를 앞에 붙임
    }

    private fun decrypt(data: ByteArray): ByteArray {
        val iv = data.copyOfRange(0, 16)
        val encrypted = data.copyOfRange(16, data.size)
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), IvParameterSpec(iv))
        return cipher.doFinal(encrypted)
    }

    private fun getSecretKey(): SecretKeySpec {
        // 머신 고유 식별자 기반 키 파생 (DPAPI 대안)
        val machineId = getMachineId()
        val salt = "OAAgent_v1_salt_2026".toByteArray()
        val spec = PBEKeySpec(machineId.toCharArray(), salt, 65536, 256)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        val keyBytes = factory.generateSecret(spec).encoded
        return SecretKeySpec(keyBytes, "AES")
    }

    /**
     * 머신 고유 식별자 조합.
     * BIOS 시리얼 + 머신 GUID → 다른 PC에서는 복호화 불가.
     */
    private fun getMachineId(): String {
        return try {
            val process = ProcessBuilder(
                "powershell.exe", "-NoProfile", "-NonInteractive", "-Command",
                "(Get-CimInstance Win32_ComputerSystemProduct).UUID"
            )
                .redirectErrorStream(true)
                .start()
            val uuid = process.inputStream.bufferedReader().readText().trim()
            process.waitFor()
            if (uuid.isNotEmpty()) uuid else fallbackMachineId()
        } catch (_: Exception) {
            fallbackMachineId()
        }
    }

    private fun fallbackMachineId(): String {
        return System.getProperty("user.name") + "@" + (
            System.getenv("COMPUTERNAME") ?: System.getenv("HOSTNAME") ?: "unknown"
        )
    }

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
