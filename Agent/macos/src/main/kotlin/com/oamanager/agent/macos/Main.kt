package com.oamanager.agent.macos

import com.oamanager.agent.macos.data.MacPreferences
import com.oamanager.agent.macos.service.HeartbeatScheduler
import com.oamanager.agent.macos.ui.TrayIconManager
import kotlinx.coroutines.runBlocking
import javax.swing.UIManager

/**
 * macOS 에이전트 엔트리 포인트.
 *
 * 실행 모드:
 * - 일반 실행: 시스템 메뉴바 아이콘 + 설정 다이얼로그
 * - `--service` 인자: UI 없이 백그라운드 Heartbeat만 실행 (launchd용)
 * - `--send-now` 인자: 즉시 Heartbeat 1회 전송 후 종료
 */
fun main(args: Array<String>) {
    // macOS에서 메뉴바 앱 이름 설정
    System.setProperty("apple.awt.application.name", "OA Agent")
    System.setProperty("apple.laf.useScreenMenuBar", "true")

    when {
        "--service" in args -> runAsService()
        "--send-now" in args -> runSendNow()
        else -> runWithTray()
    }
}

private fun runWithTray() {
    try {
        UIManager.setLookAndFeel(UIManager.getSystemLookAndFeelClassName())
    } catch (_: Exception) { }

    val prefs = MacPreferences()
    val app = MacAgentApp(prefs)

    TrayIconManager.setup(app)

    if (prefs.assetUid == null) {
        TrayIconManager.showSetupDialog(app)
    } else {
        app.start()
    }

    Thread.currentThread().join()
}

private fun runAsService() {
    val prefs = MacPreferences()
    val app = MacAgentApp(prefs)

    if (prefs.assetUid == null) {
        System.err.println("ERROR: asset_uid not configured. Run without --service first.")
        System.exit(1)
    }

    app.start()
    Thread.currentThread().join()
}

private fun runSendNow() {
    val prefs = MacPreferences()
    val app = MacAgentApp(prefs)

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
