package com.oamanager.agent.macos

import com.oamanager.agent.AgentConfig
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.RealtimeManager
import com.oamanager.agent.network.SupabaseClient
import com.oamanager.agent.platform.SystemInfoCollector
import com.oamanager.agent.macos.data.MacPreferences
import com.oamanager.agent.macos.service.HeartbeatScheduler
import kotlinx.coroutines.*

class MacAgentApp(val prefs: MacPreferences) {

    private val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
    private val authManager = AuthManager(client, prefs)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var heartbeatScheduler: HeartbeatScheduler? = null
    private var realtimeManager: RealtimeManager? = null

    val isRunning: Boolean get() = heartbeatScheduler?.isRunning == true
    val hasPersonalSession: Boolean
        get() = prefs.personalLoginConfigured && authManager.hasStoredSession()

    /**
     * 자산 담당자 또는 관리자 개인 OA 계정으로 로그인한다.
     * 비밀번호는 호출 범위를 벗어나 저장하지 않는다.
     */
    suspend fun signInWithPersonalAccount(account: String, password: String): Boolean {
        val loginEmail = account.trim().let {
            if (it.contains('@')) it else "$it@oamanager.internal"
        }
        val signedIn = authManager.signInWithPassword(loginEmail, password)
        if (signedIn) prefs.personalLoginConfigured = true
        return signedIn
    }

    fun start(): Boolean {
        if (!hasPersonalSession) {
            System.err.println("OA personal-account login is required before starting the agent.")
            return false
        }

        val assetUid = prefs.assetUid ?: return false
        if (heartbeatScheduler?.isRunning == true) return true
        val interval = prefs.intervalMinutes

        heartbeatScheduler = HeartbeatScheduler(
            intervalMinutes = interval,
            onHeartbeat = { sendHeartbeatOnce() },
        ).also { it.start() }

        scope.launch { startRealtime(assetUid) }

        println("OA Agent started: asset_uid=$assetUid, interval=${interval}min")
        return true
    }

    fun stop() {
        heartbeatScheduler?.stop()
        heartbeatScheduler = null
        scope.launch {
            realtimeManager?.disconnect()
            realtimeManager = null
        }
    }

    suspend fun sendHeartbeatOnce() {
        val assetUid = prefs.assetUid ?: throw IllegalStateException("asset_uid not set")
        val token = requireValidToken()

        val systemInfo = SystemInfoCollector(
            assetUserName = prefs.assetUserName ?: "",
            employeeId = prefs.employeeId ?: "",
            agentVersion = "1.0.0",
        ).collect()

        client.updateHeartbeat(token, assetUid, systemInfo)
        prefs.lastHeartbeatTime = System.currentTimeMillis()
    }

    suspend fun verifyUser(userName: String, employeeId: String): Pair<Boolean, String> {
        val assetUid = prefs.assetUid ?: throw IllegalStateException("asset_uid not set")
        val token = requireValidToken()

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

    private suspend fun startRealtime(assetUid: String) {
        if (!hasPersonalSession) return
        try {
            requireValidToken()
            realtimeManager = RealtimeManager(authManager = authManager)
            realtimeManager?.connect(scope)
            realtimeManager?.joinPresence(assetUid)
            realtimeManager?.joinCommandChannel(assetUid)

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

    private suspend fun requireValidToken(): String =
        authManager.getValidToken() ?: run {
            prefs.accessToken = null
            prefs.refreshToken = null
            prefs.personalLoginConfigured = false
            throw IllegalStateException("OA session expired. Sign in with a personal OA account again.")
        }
}
