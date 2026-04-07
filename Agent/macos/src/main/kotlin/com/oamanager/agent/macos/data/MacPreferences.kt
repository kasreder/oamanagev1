package com.oamanager.agent.macos.data

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
 * macOS 에이전트 설정 저장소.
 * AES-256-CBC 암호화. 저장 위치: ~/Library/Application Support/OAAgent/agent.enc
 */
class MacPreferences : TokenStorage {

    private val configDir: File = File(
        System.getProperty("user.home"),
        "Library/Application Support/OAAgent"
    ).also { it.mkdirs() }

    private val configFile = File(configDir, "agent.enc")
    private val props = Properties()

    init { load() }

    override var accessToken: String?
        get() = getString(KEY_ACCESS_TOKEN)
        set(value) = putString(KEY_ACCESS_TOKEN, value)

    override var refreshToken: String?
        get() = getString(KEY_REFRESH_TOKEN)
        set(value) = putString(KEY_REFRESH_TOKEN, value)

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

    private fun getString(key: String): String? = props.getProperty(key)

    private fun putString(key: String, value: String?) {
        if (value != null) props.setProperty(key, value) else props.remove(key)
        save()
    }

    private fun load() {
        if (!configFile.exists()) return
        try {
            val decrypted = decrypt(configFile.readBytes())
            props.load(decrypted.inputStream())
        } catch (_: Exception) { props.clear() }
    }

    private fun save() {
        try {
            val baos = java.io.ByteArrayOutputStream()
            props.store(baos, null)
            configFile.writeBytes(encrypt(baos.toByteArray()))
        } catch (_: Exception) { }
    }

    private fun encrypt(data: ByteArray): ByteArray {
        val iv = ByteArray(16).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, getSecretKey(), IvParameterSpec(iv))
        return iv + cipher.doFinal(data)
    }

    private fun decrypt(data: ByteArray): ByteArray {
        val iv = data.copyOfRange(0, 16)
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.DECRYPT_MODE, getSecretKey(), IvParameterSpec(iv))
        return cipher.doFinal(data.copyOfRange(16, data.size))
    }

    private fun getSecretKey(): SecretKeySpec {
        val machineId = getMachineId()
        val salt = "OAAgent_v1_salt_2026".toByteArray()
        val spec = PBEKeySpec(machineId.toCharArray(), salt, 65536, 256)
        val factory = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
        return SecretKeySpec(factory.generateSecret(spec).encoded, "AES")
    }

    private fun getMachineId(): String {
        return try {
            val process = ProcessBuilder("sh", "-c", "ioreg -rd1 -c IOPlatformExpertDevice | awk '/IOPlatformUUID/{print \$3}' | tr -d '\"'")
                .redirectErrorStream(true).start()
            val uuid = process.inputStream.bufferedReader().readText().trim()
            process.waitFor()
            uuid.ifEmpty { fallbackId() }
        } catch (_: Exception) { fallbackId() }
    }

    private fun fallbackId(): String =
        System.getProperty("user.name") + "@" + (System.getenv("HOSTNAME") ?: "mac")

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
