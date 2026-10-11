package com.oamanager.agent.windows.data

import com.oamanager.agent.network.TokenStorage
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.charset.StandardCharsets
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.util.Base64
import java.util.Properties
import java.util.concurrent.TimeUnit

/**
 * Windows 에이전트 설정 저장소.
 *
 * 모든 값은 Windows DPAPI의 CurrentUser 범위로 암호화한다. 따라서 같은 Windows
 * 사용자 컨텍스트에서만 복호화할 수 있고, 정적 키·머신 식별자 기반 키 파생을
 * 사용하지 않는다.
 *
 * v2 이전의 `agent.enc`는 안전하게 이관할 수 없으므로 삭제하고 재설정을
 * 요구한다. 업데이트 후 사용자는 다시 로그인하고 자산을 확인해야 할 수 있다.
 */
class WindowsPreferences : TokenStorage {

    private val configDir = File(
        System.getenv("APPDATA") ?: System.getProperty("user.home"),
        "OAAgent",
    )
    private val configFile = File(configDir, "agent.dpapi")
    private val legacyConfigFile = File(configDir, "agent.enc")
    private val props = Properties()

    init {
        ensureConfigDirectory()
        removeLegacyInsecureStore()
        load()
    }

    // ─── TokenStorage 구현 ──────────────────────────────────────────────

    override var accessToken: String?
        get() = getString(KEY_ACCESS_TOKEN)
        set(value) = putString(KEY_ACCESS_TOKEN, value)

    override var refreshToken: String?
        get() = getString(KEY_REFRESH_TOKEN)
        set(value) = putString(KEY_REFRESH_TOKEN, value)

    /**
     * 구버전 공용 계정 세션을 개인 OA 계정 세션으로 오인하지 않기 위한 전환 표시.
     * 실제 access/refresh token과 함께 같은 DPAPI 보호 저장소에 보관한다.
     */
    var personalLoginConfigured: Boolean
        get() = getString(KEY_PERSONAL_LOGIN_CONFIGURED) == "true"
        set(value) = putString(KEY_PERSONAL_LOGIN_CONFIGURED, value.toString())

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

    // ─── DPAPI 보호 저장/로드 ───────────────────────────────────────────

    private fun getString(key: String): String? = props.getProperty(key)

    private fun putString(key: String, value: String?) {
        val previous = props.getProperty(key)
        if (value == null) {
            props.remove(key)
        } else {
            props.setProperty(key, value)
        }

        try {
            save()
        } catch (e: Exception) {
            if (previous == null) {
                props.remove(key)
            } else {
                props.setProperty(key, previous)
            }
            throw IllegalStateException(
                "Windows DPAPI storage failed; refusing to retain the updated session.",
                e,
            )
        }
    }

    private fun load() {
        if (!configFile.exists()) return

        try {
            val stored = configFile.readBytes()
            require(stored.hasPrefix(FORMAT_MAGIC)) { "Unsupported DPAPI preference format." }
            val plaintext = dpapiUnprotect(stored.copyOfRange(FORMAT_MAGIC.size, stored.size))
            props.load(ByteArrayInputStream(plaintext))
        } catch (_: Exception) {
            // DPAPI 복호화에 실패한 저장소(다른 사용자 프로필·손상 파일 등)는
            // 사용하지 않는다. 서비스/트레이 앱은 세션이 없다고 판단해 재로그인을
            // 요구하므로 약한 저장소로 fallback하지 않는다.
            props.clear()
        }
    }

    private fun save() {
        val plaintext = ByteArrayOutputStream().use { output ->
            props.store(output, null)
            output.toByteArray()
        }
        val protected = dpapiProtect(plaintext)
        writeAtomically(FORMAT_MAGIC + protected)
    }

    private fun writeAtomically(contents: ByteArray) {
        val temporary = Files.createTempFile(configDir.toPath(), "agent-", ".tmp")
        try {
            Files.write(temporary, contents)
            try {
                Files.move(
                    temporary,
                    configFile.toPath(),
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING,
                )
            } catch (_: AtomicMoveNotSupportedException) {
                Files.move(temporary, configFile.toPath(), StandardCopyOption.REPLACE_EXISTING)
            }
        } finally {
            Files.deleteIfExists(temporary)
        }
    }

    private fun dpapiProtect(data: ByteArray): ByteArray =
        runPowerShell(DPAPI_PROTECT_SCRIPT, data)

    private fun dpapiUnprotect(data: ByteArray): ByteArray =
        runPowerShell(DPAPI_UNPROTECT_SCRIPT, data)

    /**
     * PowerShell에는 정적 스크립트만 인수로 전달하고 실제 토큰·설정값은 표준 입력의
     * 원시 바이트로 전달한다. 비밀 값을 명령행이나 환경 변수에 노출하지 않는다.
     */
    private fun runPowerShell(script: String, input: ByteArray): ByteArray {
        val encodedScript = Base64.getEncoder().encodeToString(script.toByteArray(Charsets.UTF_16LE))
        val process = ProcessBuilder(
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-EncodedCommand",
            encodedScript,
        ).start()

        try {
            process.outputStream.use { output ->
                output.write(input)
                output.flush()
            }

            if (!process.waitFor(POWER_SHELL_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
                process.destroyForcibly()
                throw IllegalStateException("Windows DPAPI command timed out.")
            }

            val result = process.inputStream.readBytes()
            process.errorStream.readBytes()
            if (process.exitValue() != 0 || result.isEmpty()) {
                throw IllegalStateException("Windows DPAPI command failed.")
            }
            return result
        } finally {
            process.inputStream.close()
            process.errorStream.close()
        }
    }

    private fun ensureConfigDirectory() {
        if (!configDir.isDirectory && !configDir.mkdirs()) {
            throw IllegalStateException("Could not create the OA Agent configuration directory.")
        }
    }

    private fun removeLegacyInsecureStore() {
        if (legacyConfigFile.exists() && !legacyConfigFile.delete()) {
            throw IllegalStateException(
                "Legacy insecure preference storage could not be removed; refusing to start with it present.",
            )
        }
    }

    private fun ByteArray.hasPrefix(prefix: ByteArray): Boolean =
        size > prefix.size && prefix.indices.all { index -> this[index] == prefix[index] }

    // ─── Keys ───────────────────────────────────────────────────────────

    companion object {
        private val FORMAT_MAGIC = "OAAGENT_DPAPI_V1\n".toByteArray(StandardCharsets.US_ASCII)
        private const val POWER_SHELL_TIMEOUT_SECONDS = 10L

        private val DPAPI_PROTECT_SCRIPT = """
            ${'$'}ErrorActionPreference = 'Stop'
            ${'$'}inputStream = [Console]::OpenStandardInput()
            ${'$'}memory = New-Object System.IO.MemoryStream
            ${'$'}inputStream.CopyTo(${ '$'}memory)
            ${'$'}data = ${'$'}memory.ToArray()
            if (${ '$'}data.Length -eq 0) { throw 'Empty DPAPI input.' }
            ${'$'}protected = [System.Security.Cryptography.ProtectedData]::Protect(
                ${'$'}data,
                ${'$'}null,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )
            ${'$'}output = [Console]::OpenStandardOutput()
            ${'$'}output.Write(${ '$'}protected, 0, ${'$'}protected.Length)
        """.trimIndent()

        private val DPAPI_UNPROTECT_SCRIPT = """
            ${'$'}ErrorActionPreference = 'Stop'
            ${'$'}inputStream = [Console]::OpenStandardInput()
            ${'$'}memory = New-Object System.IO.MemoryStream
            ${'$'}inputStream.CopyTo(${ '$'}memory)
            ${'$'}data = ${'$'}memory.ToArray()
            if (${ '$'}data.Length -eq 0) { throw 'Empty DPAPI input.' }
            ${'$'}plaintext = [System.Security.Cryptography.ProtectedData]::Unprotect(
                ${'$'}data,
                ${'$'}null,
                [System.Security.Cryptography.DataProtectionScope]::CurrentUser
            )
            ${'$'}output = [Console]::OpenStandardOutput()
            ${'$'}output.Write(${ '$'}plaintext, 0, ${'$'}plaintext.Length)
        """.trimIndent()

        private const val KEY_ASSET_UID = "asset_uid"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_PERSONAL_LOGIN_CONFIGURED = "personal_login_configured"
        private const val KEY_LAST_HEARTBEAT = "last_heartbeat_time"
        private const val KEY_INTERVAL = "interval_minutes"
        private const val KEY_USER_NAME = "asset_user_name"
        private const val KEY_EMPLOYEE_ID = "employee_id"
        private const val KEY_LAST_VERIFIED = "last_verified_at"
        private const val KEY_FCM_TOKEN = "fcm_token"
    }
}
