package com.oamanager.agent.android.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.oamanager.agent.android.OAAgentApp
import com.oamanager.agent.android.data.AgentPreferences

/**
 * 기기 재부팅 시 Heartbeat 작업을 재등록합니다.
 *
 * WorkManager는 자체적으로 재부팅 후 복구하지만,
 * OEM 특성에 따른 안전장치로 추가 구현합니다.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i(TAG, "Boot completed, re-registering heartbeat")

            val prefs = AgentPreferences(context)
            val interval = prefs.intervalMinutes

            // asset_uid가 설정되어 있을 때만 재등록
            if (prefs.assetUid != null) {
                (context.applicationContext as OAAgentApp).enqueueHeartbeat(interval)
            }
        }
    }
}
