package com.oamanager.agent.android

import android.app.Application
import android.util.Log
import androidx.work.*
import com.oamanager.agent.android.service.HeartbeatForegroundService
import com.oamanager.agent.android.worker.HeartbeatWorker
import java.util.concurrent.TimeUnit

/**
 * Application 클래스.
 *
 * WorkManager 초기화 및 Heartbeat 작업 등록을 담당합니다.
 */
class OAAgentApp : Application(), Configuration.Provider {

    override fun getWorkManagerConfiguration(): Configuration {
        return Configuration.Builder()
            .setMinimumLoggingLevel(Log.INFO)
            .build()
    }

    /**
     * 사용자 설정 주기에 따라 Heartbeat 스케줄링 방식을 결정합니다.
     * - 5분: ForegroundService (WorkManager 최소 주기 15분 미만)
     * - 15분/30분: WorkManager PeriodicWorkRequest
     */
    fun enqueueHeartbeat(intervalMinutes: Int = 15) {
        // 기존 작업/서비스 정리
        WorkManager.getInstance(this).cancelUniqueWork("heartbeat")
        HeartbeatForegroundService.stop(this)

        if (intervalMinutes < 15) {
            // 5분 주기: ForegroundService 사용
            HeartbeatForegroundService.start(this, intervalMinutes)
        } else {
            // 15분/30분 주기: WorkManager 사용
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val heartbeatWork = PeriodicWorkRequestBuilder<HeartbeatWorker>(
                intervalMinutes.toLong(), TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    WorkRequest.MIN_BACKOFF_MILLIS,
                    TimeUnit.MILLISECONDS
                )
                .build()

            WorkManager.getInstance(this).enqueueUniquePeriodicWork(
                "heartbeat",
                ExistingPeriodicWorkPolicy.REPLACE,
                heartbeatWork
            )
        }
    }

    /**
     * OneTimeWorkRequest로 즉시 Heartbeat를 전송합니다.
     */
    fun sendHeartbeatNow() {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val oneTimeWork = OneTimeWorkRequestBuilder<HeartbeatWorker>()
            .setConstraints(constraints)
            .build()

        WorkManager.getInstance(this).enqueue(oneTimeWork)
    }
}
