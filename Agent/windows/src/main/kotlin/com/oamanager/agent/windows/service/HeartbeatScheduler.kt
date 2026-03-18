package com.oamanager.agent.windows.service

import kotlinx.coroutines.*
import java.util.Timer
import java.util.TimerTask

/**
 * Heartbeat 주기 스케줄러.
 *
 * 내부 Timer 기반으로 지정 주기마다 [onHeartbeat]를 호출합니다.
 * Windows 서비스/트레이 모드 모두에서 사용 가능합니다.
 */
class HeartbeatScheduler(
    private val intervalMinutes: Int = 15,
    private val onHeartbeat: suspend () -> Unit,
) {
    private var timer: Timer? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val isRunning: Boolean get() = timer != null

    /**
     * 스케줄러 시작. 즉시 첫 전송 + 주기 반복.
     */
    fun start() {
        stop()

        val intervalMs = intervalMinutes * 60 * 1000L
        timer = Timer("heartbeat-scheduler", true).apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    scope.launch {
                        try {
                            onHeartbeat()
                        } catch (e: Exception) {
                            System.err.println("Heartbeat failed: ${e.message}")
                        }
                    }
                }
            }, 0L, intervalMs)
        }

        println("HeartbeatScheduler started: interval=${intervalMinutes}min")
    }

    /**
     * 스케줄러 중지.
     */
    fun stop() {
        timer?.cancel()
        timer = null
    }
}
