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

        val loginItem = MenuItem("OA 계정 로그인...")
        loginItem.addActionListener { showPersonalLoginDialog(app) }
        popup.add(loginItem)

        val sendItem = MenuItem("즉시 전송")
        sendItem.addActionListener {
            if (!app.hasPersonalSession) {
                showMessage("개인 OA 계정 로그인이 필요합니다.")
                return@addActionListener
            }
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
        if (!app.hasPersonalSession) {
            showPersonalLoginDialog(app) { showSetupDialog(app) }
            return
        }

        val uid = JOptionPane.showInputDialog(
            null,
            "자산번호를 입력하세요 (예: D00001, BDT00001)",
            "OA Agent 설정",
            JOptionPane.PLAIN_MESSAGE,
        ) ?: return

        val trimmed = uid.trim().uppercase()
        if (trimmed.isEmpty()) return

        app.prefs.assetUid = trimmed
        if (app.start()) {
            showMessage("에이전트 시작: $trimmed")
        } else {
            JOptionPane.showMessageDialog(
                null,
                "Heartbeat를 시작하려면 개인 OA 계정 로그인이 필요합니다.",
                "OA 계정 로그인 필요",
                JOptionPane.WARNING_MESSAGE,
            )
        }
    }

    /**
     * 자산 담당자 또는 관리자 개인 OA 계정 로그인 화면.
     * 비밀번호는 UI 입력과 인증 요청 사이에서만 사용하고 저장하지 않는다.
     */
    private fun showPersonalLoginDialog(app: MacAgentApp, onSuccess: (() -> Unit)? = null) {
        val tfAccount = javax.swing.JTextField(24)
        val pfPassword = javax.swing.JPasswordField(24)
        val form = javax.swing.JPanel(java.awt.GridLayout(0, 1, 0, 6)).apply {
            add(javax.swing.JLabel("자산 담당자 또는 관리자 개인 OA 계정으로 로그인하세요."))
            add(javax.swing.JLabel("사번 또는 OA 계정 이메일"))
            add(tfAccount)
            add(javax.swing.JLabel("비밀번호"))
            add(pfPassword)
        }

        val choice = JOptionPane.showConfirmDialog(
            null,
            form,
            "OA 계정 로그인",
            JOptionPane.OK_CANCEL_OPTION,
            JOptionPane.PLAIN_MESSAGE,
        )
        if (choice != JOptionPane.OK_OPTION) return

        val account = tfAccount.text
        val password = pfPassword.password
        if (account.isBlank() || password.isEmpty()) {
            password.fill('\u0000')
            JOptionPane.showMessageDialog(
                null,
                "OA 계정과 비밀번호를 모두 입력하세요.",
                "입력 확인",
                JOptionPane.WARNING_MESSAGE,
            )
            return
        }

        Thread {
            val signedIn = try {
                val passwordText = password.concatToString()
                kotlinx.coroutines.runBlocking {
                    app.signInWithPersonalAccount(account, passwordText)
                }
            } catch (_: Exception) {
                false
            } finally {
                password.fill('\u0000')
            }

            EventQueue.invokeLater {
                if (signedIn) {
                    JOptionPane.showMessageDialog(
                        null,
                        "개인 OA 계정으로 로그인했습니다.",
                        "로그인 완료",
                        JOptionPane.INFORMATION_MESSAGE,
                    )
                    onSuccess?.invoke()
                } else {
                    JOptionPane.showMessageDialog(
                        null,
                        "로그인에 실패했습니다. 계정 또는 자산 담당자/관리자 권한을 확인하세요.",
                        "로그인 실패",
                        JOptionPane.ERROR_MESSAGE,
                    )
                }
            }
        }.start()
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
