package com.oamanager.agent.windows

import com.oamanager.agent.windows.data.WindowsPreferences
import com.oamanager.agent.windows.service.HeartbeatScheduler
import com.oamanager.agent.windows.ui.TrayIconManager
import kotlinx.coroutines.runBlocking
import javax.swing.UIManager

/**
 * Windows 에이전트 엔트리 포인트.
 *
 * 실행 모드:
 * - 일반 실행: 시스템 트레이 아이콘 + 설정 다이얼로그
 * - `--service` 인자: UI 없이 백그라운드 Heartbeat만 실행 (Windows 서비스용)
 * - `--send-now` 인자: 즉시 Heartbeat 1회 전송 후 종료 (Task Scheduler용)
 */
fun main(args: Array<String>) {
    when {
        "--service" in args -> runAsService()
        "--send-now" in args -> runSendNow()
        else -> runWithTray()
    }
}

/**
 * 시스템 트레이 모드 (기본).
 * 트레이 아이콘 + Heartbeat 스케줄러 동시 실행.
 */
private fun runWithTray() {
    // Windows Look & Feel 적용
    try {
        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName())
    } catch (_: Exception) { }

    val prefs = WindowsPreferences()
    val app = WindowsAgentApp(prefs)

    // 트레이 아이콘 등록
    TrayIconManager.setup(app)

    // asset_uid 미설정 시 설정 다이얼로그 표시
    if (prefs.assetUid == null) {
        TrayIconManager.showSetupDialog(app)
    } else {
        // 이미 설정됨 → Heartbeat 시작
        app.start()
    }

    // JVM 종료 방지 (트레이 아이콘이 살아있는 동안 유지)
    Thread.currentThread().join()
}

/**
 * Windows 서비스 모드 (--service).
 * UI 없이 Heartbeat만 실행.
 */
private fun runAsService() {
    val prefs = WindowsPreferences()
    val app = WindowsAgentApp(prefs)

    if (prefs.assetUid == null) {
        System.err.println("ERROR: asset_uid not configured. Run without --service first.")
        System.exit(1)
    }

    app.start()
    Thread.currentThread().join()
}

/**
 * 즉시 전송 모드 (--send-now).
 * Task Scheduler에서 호출용. 1회 전송 후 종료.
 */
private fun runSendNow() {
    val prefs = WindowsPreferences()
    val app = WindowsAgentApp(prefs)

    if (prefs.assetUid == null) {
        System.err.println("ERROR: asset_uid not configured.")
        System.exit(1)
    }

    runBlocking {
        try {
            app.sendHeartbeatOnce()
            println("Heartbeat sent successfully.")
        } catch (e: Exception) {
            System.err.println("Heartbeat failed: ${e.message}")
            System.exit(1)
        }
    }
}
