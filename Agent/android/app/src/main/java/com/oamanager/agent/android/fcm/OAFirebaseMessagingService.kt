package com.oamanager.agent.android.fcm

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.R
import com.oamanager.agent.android.data.AgentPreferences
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.SupabaseClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/**
 * FCM 메시징 서비스.
 *
 * - 토큰 갱신 시 서버에 자동 등록
 * - 푸시 알림 수신 → NotificationManager로 표시
 */
class OAFirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "OAFcmService"
        private const val CHANNEL_ID = "oa_push_channel"
    }

    override fun onNewToken(token: String) {
        Log.i(TAG, "FCM token refreshed")

        val prefs = AgentPreferences(this)
        prefs.fcmToken = token

        // 서버에 토큰 등록
        CoroutineScope(Dispatchers.IO).launch {
            registerTokenToServer(prefs.assetUid, token)
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val title = message.data["title"]
            ?: message.notification?.title
            ?: "OA Manager"
        val body = message.data["body"]
            ?: message.notification?.body
            ?: ""
        val type = message.data["type"] ?: "general"

        Log.i(TAG, "Push received: type=$type, title=$title")
        showNotification(title, body, type)
    }

    private fun showNotification(title: String, body: String, type: String) {
        val notificationManager = getSystemService(NotificationManager::class.java)

        // Android 8.0+ 알림 채널 생성
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OA 알림",
                NotificationManager.IMPORTANCE_HIGH,
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        notificationManager.notify(System.currentTimeMillis().toInt(), notification)
    }

    private suspend fun registerTokenToServer(assetUid: String?, token: String) {
        if (assetUid == null) return

        val prefs = AgentPreferences(this)
        val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
        val authManager = AuthManager(client, prefs)

        try {
            val accessToken = authManager.getValidToken() ?: return
            client.upsertDeviceToken(accessToken, assetUid, token)
            Log.i(TAG, "FCM token registered for $assetUid")
        } catch (e: Exception) {
            Log.e(TAG, "FCM token registration failed", e)
        } finally {
            client.close()
        }
    }
}
