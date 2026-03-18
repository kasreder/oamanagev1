package com.oamanager.agent.windows.ui

import com.oamanager.agent.windows.WindowsAgentApp
import java.awt.*
import java.awt.event.ActionListener
import java.text.SimpleDateFormat
import java.util.*
import javax.swing.SwingUtilities

/**
 * Windows 시스템 트레이 아이콘 관리.
 *
 * - 트레이 아이콘 + 우클릭 메뉴
 * - 상태 표시 (연결/전송 시각)
 * - 설정 다이얼로그 호출
 * - 즉시 전송 / 종료
 */
object TrayIconManager {

    private var trayIcon: TrayIcon? = null
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    fun setup(app: WindowsAgentApp) {
        if (!SystemTray.isSupported()) {
            System.err.println("System tray is not supported")
            return
        }

        val image = createTrayImage()
        val popup = PopupMenu()

        // ── 메뉴 항목 ──────────────────────────────────────────────────

        val statusItem = MenuItem("상태: 대기 중")
        statusItem.isEnabled = false
        popup.add(statusItem)

        val lastSentItem = MenuItem("마지막 전송: -")
        lastSentItem.isEnabled = false
        popup.add(lastSentItem)

        popup.addSeparator()

        val setupItem = MenuItem("설정...")
        setupItem.addActionListener { showSetupDialog(app) }
        popup.add(setupItem)

        val sendNowItem = MenuItem("즉시 전송")
        sendNowItem.addActionListener {
            Thread {
                try {
                    kotlinx.coroutines.runBlocking { app.sendHeartbeatOnce() }
                    updateStatus(app, statusItem, lastSentItem)
                    trayIcon?.displayMessage(
                        "OA Agent", "Heartbeat 전송 완료", TrayIcon.MessageType.INFO
                    )
                } catch (e: Exception) {
                    trayIcon?.displayMessage(
                        "OA Agent", "전송 실패: ${e.message}", TrayIcon.MessageType.ERROR
                    )
                }
            }.start()
        }
        popup.add(sendNowItem)

        val verifyItem = MenuItem("사용자 확인...")
        verifyItem.addActionListener {
            SwingUtilities.invokeLater { showVerificationDialog(app) }
        }
        popup.add(verifyItem)

        popup.addSeparator()

        val exitItem = MenuItem("종료")
        exitItem.addActionListener {
            app.stop()
            SystemTray.getSystemTray().remove(trayIcon)
            System.exit(0)
        }
        popup.add(exitItem)

        // ── 트레이 아이콘 등록 ──────────────────────────────────────────

        trayIcon = TrayIcon(image, "OA Agent", popup).apply {
            isImageAutoSize = true
            addActionListener { showSetupDialog(app) } // 더블클릭
        }

        try {
            SystemTray.getSystemTray().add(trayIcon)
        } catch (e: AWTException) {
            System.err.println("TrayIcon could not be added: ${e.message}")
        }

        // 주기적 상태 업데이트 (30초)
        Timer("tray-status", true).scheduleAtFixedRate(object : TimerTask() {
            override fun run() {
                updateStatus(app, statusItem, lastSentItem)
            }
        }, 0, 30_000)
    }

    fun showSetupDialog(app: WindowsAgentApp) {
        SwingUtilities.invokeLater {
            SetupDialog(app).isVisible = true
        }
    }

    private fun showVerificationDialog(app: WindowsAgentApp) {
        VerificationDialog(app).isVisible = true
    }

    private fun updateStatus(app: WindowsAgentApp, statusItem: MenuItem, lastSentItem: MenuItem) {
        val assetUid = app.prefs.assetUid
        statusItem.label = if (app.isRunning) {
            "상태: ● 실행 중 ($assetUid)"
        } else if (assetUid != null) {
            "상태: ○ 중지됨 ($assetUid)"
        } else {
            "상태: 설정 필요"
        }

        val lastTime = app.prefs.lastHeartbeatTime
        lastSentItem.label = if (lastTime > 0) {
            "마지막 전송: ${dateFormat.format(Date(lastTime))}"
        } else {
            "마지막 전송: -"
        }
    }

    /**
     * 16x16 트레이 아이콘 이미지 생성 (프로그래밍 방식).
     */
    private fun createTrayImage(): Image {
        val size = 16
        val image = java.awt.image.BufferedImage(size, size, java.awt.image.BufferedImage.TYPE_INT_ARGB)
        val g = image.createGraphics()
        g.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON)

        // 배경 원 (파란색)
        g.color = Color(0x42, 0x85, 0xF4)
        g.fillOval(0, 0, size, size)

        // 모니터 아이콘 (흰색)
        g.color = Color.WHITE
        g.fillRect(3, 3, 10, 7)
        g.color = Color(0x42, 0x85, 0xF4)
        g.fillRect(4, 4, 8, 5)
        g.color = Color.WHITE
        g.fillRect(6, 10, 4, 1)
        g.fillRect(5, 11, 6, 1)

        g.dispose()
        return image
    }
}
