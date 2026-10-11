package com.oamanager.agent.macos.data

import com.oamanager.agent.network.TokenStorage
import java.io.File
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

/**
 * macOS 에이전트 설정 저장소.
 *
 * 값은 로그인 사용자의 macOS Keychain generic-password 항목으로 저장한다. 정적
 * AES 키·머신 식별자 기반 키 파생·파일 기반 암호화는 사용하지 않는다.
 *
 * v2 이전의 `agent.enc`는 안전하게 이관할 수 없으므로 삭제하고 재설정을
 * 요구한다. 업데이트 후 사용자는 다시 로그인하고 자산을 확인해야 할 수 있다.
 */
class MacPreferences : TokenStorage {

    private val legacyConfigFile = File(
        System.getProperty("user.home"),
        "Library/Application Support/OAAgent/agent.enc",
    )

    init {
        removeLegacyInsecureStore()
    }

    override var accessToken: String?
        get() = getString(KEY_ACCESS_TOKEN)
        set(value) = putString(KEY_ACCESS_TOKEN, value)

    override var refreshToken: String?
        get() = getString(KEY_REFRESH_TOKEN)
        set(value) = putString(KEY_REFRESH_TOKEN, value)

    /**
     * 구버전 공용 계정 세션을 개인 OA 계정 세션으로 오인하지 않기 위한 전환 표시.
     * 실제 access/refresh token과 함께 같은 Keychain 항목으로 보관한다.
     */
    var personalLoginConfigured: Boolean
        get() = getString(KEY_PERSONAL_LOGIN_CONFIGURED) == "true"
        set(value) = putString(KEY_PERSONAL_LOGIN_CONFIGURED, value.toString())

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

    // ─── macOS Keychain ────────────────────────────────────────────────

    private fun getString(key: String): String? {
        val result = runSecurity(
            listOf("find-generic-password", "-a", accountName(key), "-s", KEYCHAIN_SERVICE, "-w"),
        )
        return when {
            result.exitCode == 0 -> decodeKeychainValue(result.stdout)
            result.isItemNotFound() -> null
            else -> throw IllegalStateException(
                "macOS Keychain is unavailable; refusing to use a non-Keychain session store.",
            )
        }
    }

    private fun putString(key: String, value: String?) {
        if (value == null) {
            deleteString(key)
            return
        }

        require(value.none { it == '\u0000' || it == '\r' || it == '\n' }) {
            "Keychain values cannot contain NUL or line terminators."
        }

        // security(1)의 interactive mode는 명령을 표준 입력에서 받는다. 값은
        // `-X`의 hex payload로 같은 stdin에만 전달하므로 실제 토큰과 PII가
        // 명령행 인수나 환경 변수에 나타나지 않는다.
        val result = runSecurityInteractive(
            "add-generic-password -a ${accountName(key)} -s $KEYCHAIN_SERVICE -U -X ${encodeKeychainValue(value)}",
        )
        if (result.exitCode != 0) {
            throw IllegalStateException("macOS Keychain write failed; refusing to retain the updated session.")
        }
    }

    private fun deleteString(key: String) {
        val result = runSecurity(
            listOf("delete-generic-password", "-a", accountName(key), "-s", KEYCHAIN_SERVICE),
        )
        if (result.exitCode != 0 && !result.isItemNotFound()) {
            throw IllegalStateException("macOS Keychain delete failed.")
        }
    }

    private fun accountName(key: String): String = "preference.$key"

    private fun runSecurity(arguments: List<String>): SecurityCommandResult {
        val process = ProcessBuilder(listOf(SECURITY_COMMAND) + arguments).start()
        try {
            process.outputStream.close()

            if (!process.waitFor(SECURITY_COMMAND_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                throw IllegalStateException("macOS Keychain command timed out.")
            }

            return SecurityCommandResult(
                exitCode = process.exitValue(),
                stdout = process.inputStream.readBytes(),
                stderr = String(process.errorStream.readBytes(), StandardCharsets.UTF_8),
            )
        } finally {
            process.inputStream.close()
            process.errorStream.close()
        }
    }

    private fun runSecurityInteractive(command: String): SecurityCommandResult {
        val process = ProcessBuilder(SECURITY_COMMAND, "-i").start()
        try {
            process.outputStream.bufferedWriter(StandardCharsets.UTF_8).use { output ->
                output.write(command)
                output.newLine()
                output.flush()
            }

            if (!process.waitFor(SECURITY_COMMAND_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                throw IllegalStateException("macOS Keychain command timed out.")
            }

            return SecurityCommandResult(
                exitCode = process.exitValue(),
                stdout = process.inputStream.readBytes(),
                stderr = String(process.errorStream.readBytes(), StandardCharsets.UTF_8),
            )
        } finally {
            process.inputStream.close()
            process.errorStream.close()
        }
    }

    private fun encodeKeychainValue(value: String): String =
        (byteArrayOf(KEYCHAIN_VALUE_FORMAT) + value.toByteArray(StandardCharsets.UTF_8)).toHex()

    private fun decodeKeychainValue(output: ByteArray): String {
        val payload = output.withoutTrailingLineEnding()
        check(payload.isNotEmpty() && payload[0] == KEYCHAIN_VALUE_FORMAT) {
            "Unexpected macOS Keychain value format."
        }
        return String(payload.copyOfRange(1, payload.size), StandardCharsets.UTF_8)
    }

    private fun ByteArray.toHex(): String = buildString(size * 2) {
        for (byte in this@toHex) {
            val value = byte.toInt() and 0xff
            append(HEX_DIGITS[value ushr 4])
            append(HEX_DIGITS[value and 0x0f])
        }
    }

    private fun ByteArray.withoutTrailingLineEnding(): ByteArray {
        var end = size
        if (end > 0 && this[end - 1] == '\n'.code.toByte()) {
            end -= 1
            if (end > 0 && this[end - 1] == '\r'.code.toByte()) end -= 1
        }
        return copyOf(end)
    }

    private fun removeLegacyInsecureStore() {
        if (legacyConfigFile.exists() && !legacyConfigFile.delete()) {
            throw IllegalStateException(
                "Legacy insecure preference storage could not be removed; refusing to start with it present.",
            )
        }
    }

    private data class SecurityCommandResult(
        val exitCode: Int,
        val stdout: ByteArray,
        val stderr: String,
    ) {
        fun isItemNotFound(): Boolean =
            exitCode == ITEM_NOT_FOUND_EXIT_CODE || stderr.contains("could not be found", ignoreCase = true)
    }

    companion object {
        private const val SECURITY_COMMAND = "/usr/bin/security"
        private const val KEYCHAIN_SERVICE = "com.oamanager.agent.preferences.v2"
        private const val SECURITY_COMMAND_TIMEOUT_SECONDS = 10L
        private const val ITEM_NOT_FOUND_EXIT_CODE = 44
        private const val KEYCHAIN_VALUE_FORMAT: Byte = 1
        private const val HEX_DIGITS = "0123456789abcdef"

        private const val KEY_ASSET_UID = "asset_uid"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_PERSONAL_LOGIN_CONFIGURED = "personal_login_configured"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat_time"
        private const val KEY_INTERVAL = "interval_minutes"
        private const val KEY_USER_NAME = "asset_user_name"
        private const val KEY_EMPLOYEE_ID = "employee_id"
        private const val KEY_LAST_VERIFIED = "last_verified_at"
    }
}
