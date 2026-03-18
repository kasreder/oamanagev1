package com.oamanager.agent.windows

import com.oamanager.agent.AgentConfig
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.RealtimeManager
import com.oamanager.agent.network.SupabaseClient
import com.oamanager.agent.platform.SystemInfoCollector
import com.oamanager.agent.windows.data.WindowsPreferences
import com.oamanager.agent.windows.service.HeartbeatScheduler
import kotlinx.coroutines.*
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put

/**
 * Windows 에이전트 애플리케이션 메인 로직.
 *
 * - Heartbeat 주기 스케줄링
 * - Realtime WebSocket 연결 (Presence, 명령 수신, 알림 발신)
 * - 사용자 확인 / 자산 수령 확인
 */
class WindowsAgentApp(val prefs: WindowsPreferences) {

    private val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
    private val authManager = AuthManager(client, prefs)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var heartbeatScheduler: HeartbeatScheduler? = null
    private var realtimeManager: RealtimeManager? = null

    val isRunning: Boolean get() = heartbeatScheduler?.isRunning == true

    /**
     * Heartbeat + Realtime 시작.
     */
    fun start() {
        val assetUid = prefs.assetUid ?: return
        val interval = prefs.intervalMinutes

        // Heartbeat 스케줄러
        heartbeatScheduler = HeartbeatScheduler(
            intervalMinutes = interval,
            onHeartbeat = { sendHeartbeatOnce() },
        ).also { it.start() }

        // Realtime WebSocket
        scope.launch {
            startRealtime(assetUid)
        }

        println("OA Agent started: asset_uid=$assetUid, interval=${interval}min")
    }

    /**
     * 중지.
     */
    fun stop() {
        heartbeatScheduler?.stop()
        heartbeatScheduler = null
        scope.launch {
            realtimeManager?.disconnect()
            realtimeManager = null
        }
        println("OA Agent stopped.")
    }

    /**
     * Heartbeat 1회 전송.
     */
    suspend fun sendHeartbeatOnce() {
        val assetUid = prefs.assetUid ?: throw IllegalStateException("asset_uid not set")

        val token = authManager.getValidToken()
            ?: throw IllegalStateException("Authentication failed")

        val systemInfo = SystemInfoCollector(
            assetUserName = prefs.assetUserName ?: "",
            employeeId = prefs.employeeId ?: "",
            agentVersion = getVersionString(),
        ).collect()

        client.updateHeartbeat(token, assetUid, systemInfo)
        prefs.lastHeartbeatTime = System.currentTimeMillis()

        // 버전 확인
        checkVersion(token)
    }

    /**
     * 사용자 확인.
     */
    suspend fun verifyUser(userName: String, employeeId: String): Pair<Boolean, String> {
        val assetUid = prefs.assetUid ?: throw IllegalStateException("asset_uid not set")
        val token = authManager.getValidToken()
            ?: throw IllegalStateException("Authentication failed")

        val result = client.verifyUser(token, assetUid, userName, employeeId)
        val matched = result["matched"]?.let {
            kotlinx.serialization.json.JsonPrimitive(true) == it
        } ?: false
        val message = result["message"]?.toString()?.trim('"') ?: ""

        if (matched) {
            prefs.lastVerifiedAt = System.currentTimeMillis()
            prefs.assetUserName = userName
            prefs.employeeId = employeeId
        }

        return Pair(matched, message)
    }

    /**
     * 자산 수령 확인.
     */
    suspend fun confirmAssignment(userName: String): Pair<Boolean, String> {
        val assetUid = prefs.assetUid ?: throw IllegalStateException("asset_uid not set")
        val token = authManager.getValidToken()
            ?: throw IllegalStateException("Authentication failed")

        val result = client.confirmAssignment(token, assetUid, userName)
        val success = result["success"]?.toString() == "true"
        val message = result["message"]?.toString()?.trim('"') ?: ""

        return Pair(success, message)
    }

    // ─── Realtime ───────────────────────────────────────────────────────

    private suspend fun startRealtime(assetUid: String) {
        try {
            realtimeManager = RealtimeManager(authManager = authManager)
            realtimeManager?.connect(scope)
            realtimeManager?.joinPresence(assetUid, "windows", getVersionString())
            realtimeManager?.joinCommandChannel(assetUid)
            realtimeManager?.joinAlertChannel()

            realtimeManager?.onCommand { command, _ ->
                when (command) {
                    "request_heartbeat", "refresh_system_info" -> {
                        scope.launch { sendHeartbeatOnce() }
                    }
                }
            }
        } catch (e: Exception) {
            System.err.println("Realtime connection failed: ${e.message}")
        }
    }

    // ─── Version ────────────────────────────────────────────────────────

    private suspend fun checkVersion(token: String) {
        try {
            val settings = client.getAgentSettings(token)
            val current = getVersionString()
            val latest = settings["latest_agent_version"] ?: return
            if (compareVersions(current, latest) < 0) {
                println("Update available: $current → $latest")
            }
        } catch (_: Exception) { }
    }

    private fun compareVersions(a: String, b: String): Int {
        val ap = a.split(".").map { it.toIntOrNull() ?: 0 }
        val bp = b.split(".").map { it.toIntOrNull() ?: 0 }
        for (i in 0 until maxOf(ap.size, bp.size)) {
            val ai = ap.getOrElse(i) { 0 }
            val bi = bp.getOrElse(i) { 0 }
            if (ai != bi) return ai - bi
        }
        return 0
    }

    companion object {
        fun getVersionString(): String = "1.0.0"
    }
}
