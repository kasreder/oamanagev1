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

    fun start() {
        val assetUid = prefs.assetUid ?: return
        val interval = prefs.intervalMinutes

        heartbeatScheduler = HeartbeatScheduler(
            intervalMinutes = interval,
            onHeartbeat = { sendHeartbeatOnce() },
        ).also { it.start() }

        scope.launch { startRealtime(assetUid) }

        println("OA Agent started: asset_uid=$assetUid, interval=${interval}min")
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
        val token = authManager.getValidToken()
            ?: throw IllegalStateException("Authentication failed")

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

    private suspend fun startRealtime(assetUid: String) {
        try {
            realtimeManager = RealtimeManager(authManager = authManager)
            realtimeManager?.connect(scope)
            realtimeManager?.joinPresence(assetUid, "macos", "1.0.0")
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
}
