package com.oamanager.agent.macos.service

import kotlinx.coroutines.*
import java.util.Timer
import java.util.TimerTask

class HeartbeatScheduler(
    private val intervalMinutes: Int = 15,
    private val onHeartbeat: suspend () -> Unit,
) {
    private var timer: Timer? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val isRunning: Boolean get() = timer != null

    fun start() {
        stop()
        val intervalMs = intervalMinutes * 60 * 1000L
        timer = Timer("heartbeat-scheduler", true).apply {
            scheduleAtFixedRate(object : TimerTask() {
                override fun run() {
                    scope.launch {
                        try { onHeartbeat() }
                        catch (e: Exception) { System.err.println("Heartbeat failed: ${e.message}") }
                    }
                }
            }, 0L, intervalMs)
        }
        println("HeartbeatScheduler started: interval=${intervalMinutes}min")
    }

    fun stop() {
        timer?.cancel()
        timer = null
    }
}
