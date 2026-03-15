package com.oamanager.agent.android.worker

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.android.data.AgentPreferences
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.SupabaseClient
import com.oamanager.agent.platform.SystemInfoCollector

/**
 * WorkManager CoroutineWorker 구현.
 *
 * 핵심 Heartbeat 전송 로직:
 * 1. 설정 로드 (asset_uid)
 * 2. 시스템 정보 수집 (18개 항목)
 * 3. 인증 확인/갱신
 * 4. Heartbeat 전송 (update_heartbeat RPC)
 * 5. 버전 확인 (agent_settings 조회)
 */
class HeartbeatWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "HeartbeatWorker"
    }

    override suspend fun doWork(): Result {
        // 1. 설정 로드
        val prefs = AgentPreferences(applicationContext)
        val assetUid = prefs.assetUid ?: run {
            Log.w(TAG, "asset_uid not configured")
            return Result.failure()
        }

        // 2. 시스템 정보 수집
        val systemInfo = SystemInfoCollector(
            context = applicationContext,
            assetUserName = prefs.assetUserName ?: "",
            employeeId = prefs.employeeId ?: "",
            agentVersion = getVersionName(),
        ).collect()

        // 3. 인증 확인/갱신
        val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
        val authManager = AuthManager(client, prefs)
        val token = authManager.getValidToken() ?: run {
            Log.w(TAG, "Failed to get valid token")
            client.close()
            return Result.retry()
        }

        // 4. Heartbeat 전송
        return try {
            client.updateHeartbeat(token, assetUid, systemInfo)
            prefs.lastHeartbeatTime = System.currentTimeMillis()
            Log.i(TAG, "Heartbeat sent successfully for $assetUid")

            // 5. 버전 확인
            checkVersion(client, token, prefs)

            client.close()
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Heartbeat failed", e)
            client.close()
            Result.retry()
        }
    }

    /**
     * 에이전트 버전을 서버와 비교합니다.
     */
    private suspend fun checkVersion(
        client: SupabaseClient,
        token: String,
        prefs: AgentPreferences,
    ) {
        try {
            val settings = client.getAgentSettings(token)
            val currentVersion = getVersionName()
            val latestVersion = settings["latest_agent_version"] ?: return
            val minVersion = settings["min_agent_version"] ?: return

            if (compareVersions(currentVersion, latestVersion) < 0) {
                Log.i(TAG, "Update available: $currentVersion → $latestVersion")
                // TODO: 업데이트 알림 표시
            }
            if (compareVersions(currentVersion, minVersion) < 0) {
                Log.w(TAG, "Force update required: $currentVersion < $minVersion")
                // TODO: 강제 업데이트 알림
            }
        } catch (e: Exception) {
            Log.w(TAG, "Version check failed", e)
        }
    }

    private fun getVersionName(): String {
        return try {
            applicationContext.packageManager
                .getPackageInfo(applicationContext.packageName, 0)
                .versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }
    }

    /**
     * 시맨틱 버전 비교.
     * @return 음수 (a < b), 0 (같음), 양수 (a > b)
     */
    private fun compareVersions(a: String, b: String): Int {
        val aParts = a.split(".").map { it.toIntOrNull() ?: 0 }
        val bParts = b.split(".").map { it.toIntOrNull() ?: 0 }
        val maxLen = maxOf(aParts.size, bParts.size)
        for (i in 0 until maxLen) {
            val ai = aParts.getOrElse(i) { 0 }
            val bi = bParts.getOrElse(i) { 0 }
            if (ai != bi) return ai - bi
        }
        return 0
    }
}
