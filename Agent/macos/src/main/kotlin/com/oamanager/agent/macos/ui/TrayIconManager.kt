package com.oamanager.agent.macos.ui

import com.oamanager.agent.macos.MacAgentApp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.awt.*
import javax.swing.JOptionPane

object TrayIconManager {

    private var trayIcon: TrayIcon? = null

    fun setup(app: MacAgentApp) {
        if (!SystemTray.isSupported()) {
            println("System tray not supported")
            return
        }

        val popup = PopupMenu()

        val statusItem = MenuItem("OA Agent")
        statusItem.isEnabled = false
        popup.add(statusItem)
        popup.addSeparator()

        val setupItem = MenuItem("설정")
        setupItem.addActionListener { showSetupDialog(app) }
        popup.add(setupItem)

        val sendItem = MenuItem("즉시 전송")
        sendItem.addActionListener {
            GlobalScope.launch(Dispatchers.IO) {
                try {
                    app.sendHeartbeatOnce()
                    showMessage("전송 성공")
                } catch (e: Exception) {
                    showMessage("전송 실패: ${e.message}")
                }
            }
        }
        popup.add(sendItem)

        popup.addSeparator()
        val exitItem = MenuItem("종료")
        exitItem.addActionListener {
            app.stop()
            System.exit(0)
        }
        popup.add(exitItem)

        // 기본 아이콘 (16x16 파란색 사각형)
        val image = createDefaultIcon()
        trayIcon = TrayIcon(image, "OA Agent", popup).apply {
            isImageAutoSize = true
        }

        try {
            SystemTray.getSystemTray().add(trayIcon!!)
        } catch (e: AWTException) {
            System.err.println("Tray icon failed: ${e.message}")
        }
    }

    fun showSetupDialog(app: MacAgentApp) {
        val uid = JOptionPane.showInputDialog(
            null,
            "자산번호를 입력하세요 (예: D00001, BDT00001)",
            "OA Agent 설정",
            JOptionPane.PLAIN_MESSAGE,
        ) ?: return

        val trimmed = uid.trim().uppercase()
        if (trimmed.isEmpty()) return

        app.prefs.assetUid = trimmed
        app.start()
        showMessage("에이전트 시작: $trimmed")
    }

    private fun showMessage(msg: String) {
        trayIcon?.displayMessage("OA Agent", msg, TrayIcon.MessageType.INFO)
    }

    private fun createDefaultIcon(): Image {
        val size = 16
        val img = java.awt.image.BufferedImage(size, size, java.awt.image.BufferedImage.TYPE_INT_ARGB)
        val g = img.createGraphics()
        g.color = Color(21, 101, 192)
        g.fillRoundRect(0, 0, size, size, 4, 4)
        g.color = Color.WHITE
        g.font = Font("SansSerif", Font.BOLD, 10)
        g.drawString("A", 3, 12)
        g.dispose()
        return img
    }
}
