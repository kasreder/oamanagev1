package com.oamanager.agent.android.service

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.R
import com.oamanager.agent.android.data.AgentPreferences
import com.oamanager.agent.android.ui.SetupActivity
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.RealtimeManager
import com.oamanager.agent.network.SupabaseClient
import com.oamanager.agent.platform.SystemInfoCollector
import kotlinx.coroutines.*

/**
 * 5분 주기 Heartbeat용 포그라운드 서비스.
 *
 * WorkManager 최소 주기(15분) 미만인 5분 주기를 구현합니다.
 * 동시에 RealtimeManager(WebSocket)도 이 서비스 내에서 관리합니다.
 */
class HeartbeatForegroundService : Service() {

    companion object {
        private const val TAG = "HeartbeatFgService"
        private const val CHANNEL_ID = "heartbeat_channel"
        private const val NOTIFICATION_ID = 1001
        private const val EXTRA_INTERVAL = "interval_minutes"

        fun start(context: Context, intervalMinutes: Int = 5) {
            val intent = Intent(context, HeartbeatForegroundService::class.java).apply {
                putExtra(EXTRA_INTERVAL, intervalMinutes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, HeartbeatForegroundService::class.java))
        }
    }

    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val handler = Handler(Looper.getMainLooper())
    private var heartbeatRunnable: Runnable? = null
    private var intervalMs: Long = 5 * 60 * 1000L

    private var realtimeManager: RealtimeManager? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val interval = intent?.getIntExtra(EXTRA_INTERVAL, 5) ?: 5
        intervalMs = interval * 60 * 1000L

        // 포그라운드 알림 표시
        val notification = buildNotification(interval)
        startForeground(NOTIFICATION_ID, notification)

        // Heartbeat 타이머 시작
        startHeartbeatTimer()

        // Realtime WebSocket 연결
        startRealtimeConnection()

        return START_STICKY
    }

    override fun onDestroy() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }
        serviceScope.launch {
            realtimeManager?.disconnect()
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ─── Heartbeat Timer ────────────────────────────────────────────────

    private fun startHeartbeatTimer() {
        heartbeatRunnable?.let { handler.removeCallbacks(it) }

        heartbeatRunnable = object : Runnable {
            override fun run() {
                serviceScope.launch { sendHeartbeat() }
                handler.postDelayed(this, intervalMs)
            }
        }

        // 즉시 첫 전송 + 주기 반복
        handler.post(heartbeatRunnable!!)
    }

    private suspend fun sendHeartbeat() {
        val prefs = AgentPreferences(this)
        val assetUid = prefs.assetUid ?: return
        val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
        val authManager = AuthManager(client, prefs)

        try {
            val token = authManager.getValidToken() ?: return
            val systemInfo = SystemInfoCollector(
                context = this,
                assetUserName = prefs.assetUserName ?: "",
                employeeId = prefs.employeeId ?: "",
                agentVersion = getVersionName(),
            ).collect()

            client.updateHeartbeat(token, assetUid, systemInfo)
            prefs.lastHeartbeatTime = System.currentTimeMillis()
            Log.i(TAG, "ForegroundService heartbeat sent for $assetUid")
        } catch (e: Exception) {
            Log.e(TAG, "ForegroundService heartbeat failed", e)
        } finally {
            client.close()
        }
    }

    // ─── Realtime WebSocket ─────────────────────────────────────────────

    private fun startRealtimeConnection() {
        val prefs = AgentPreferences(this)
        val assetUid = prefs.assetUid ?: return
        val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
        val authManager = AuthManager(client, prefs)

        realtimeManager = RealtimeManager(authManager = authManager)

        serviceScope.launch {
            try {
                realtimeManager?.connect(serviceScope)
                realtimeManager?.joinPresence(
                    assetUid = assetUid,
                    platform = "android",
                    agentVersion = getVersionName(),
                )
                realtimeManager?.joinCommandChannel(assetUid)
                realtimeManager?.joinAlertChannel()

                // 명령 수신 처리
                realtimeManager?.onCommand { command, _ ->
                    when (command) {
                        "request_heartbeat", "refresh_system_info" -> {
                            serviceScope.launch { sendHeartbeat() }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Realtime connection failed", e)
            }
        }
    }

    // ─── Notification ───────────────────────────────────────────────────

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Heartbeat 서비스",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "OA Agent Heartbeat 전송 서비스"
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(intervalMinutes: Int): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, SetupActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE,
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("OA Agent 실행 중")
            .setContentText("${intervalMinutes}분 주기로 Heartbeat 전송 중")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun getVersionName(): String {
        return try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }
    }
}
