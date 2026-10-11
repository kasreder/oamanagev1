package com.oamanager.agent.windows.ui

import com.oamanager.agent.AgentConfig
import com.oamanager.agent.windows.WindowsAgentApp
import java.awt.*
import java.text.SimpleDateFormat
import java.util.*
import javax.swing.*
import javax.swing.border.EmptyBorder

/**
 * 에이전트 초기 설정 다이얼로그 (Swing).
 *
 * - asset_uid 입력 (정규식 실시간 검증)
 * - 전송 주기 선택 (5분/15분/30분)
 * - 시작/즉시 전송 버튼
 * - 상태 정보 표시
 */
class SetupDialog(private val app: WindowsAgentApp) : JDialog() {

    private val tfAssetUid = JTextField(15)
    private val lblError = JLabel(" ").apply { foreground = Color.RED; font = font.deriveFont(11f) }
    private val lblAuthentication = JLabel("OA 계정: 로그인 필요")
    private val btnSignIn = JButton("OA 계정 로그인")
    private val cbInterval = JComboBox(arrayOf("5분", "15분 (기본값)", "30분"))
    private val btnStart = JButton("시작").apply { isEnabled = false }
    private val btnSendNow = JButton("즉시 전송").apply { isEnabled = false }

    // 상태 표시
    private val lblAssetUid = JLabel("자산 번호: -")
    private val lblInterval = JLabel("전송 주기: -")
    private val lblLastSent = JLabel("마지막 전송: -")
    private val lblVersion = JLabel("에이전트 버전: ${WindowsAgentApp.getVersionString()}")
    private val lblVerification = JLabel("사용자 확인: 미확인")

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    init {
        title = "OA Agent 설정"
        isModal = false
        defaultCloseOperation = DISPOSE_ON_CLOSE
        isResizable = false

        contentPane = buildUI()
        pack()
        setLocationRelativeTo(null)

        loadSavedState()
    }

    private fun buildUI(): JPanel {
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = EmptyBorder(16, 16, 16, 16)

        // ── OA 계정 로그인 ──────────────────────────────────────────────

        panel.add(createSectionLabel("OA 계정 인증"))
        panel.add(lblAuthentication)
        btnSignIn.alignmentX = Component.LEFT_ALIGNMENT
        btnSignIn.addActionListener { onSignIn() }
        panel.add(Box.createVerticalStrut(4))
        panel.add(btnSignIn)

        // ── 자산 번호 입력 ──────────────────────────────────────────────

        panel.add(Box.createVerticalStrut(16))
        panel.add(createSectionLabel("자산 번호 (asset_uid)"))

        tfAssetUid.maximumSize = Dimension(Int.MAX_VALUE, 30)
        tfAssetUid.document.addDocumentListener(object : javax.swing.event.DocumentListener {
            override fun insertUpdate(e: javax.swing.event.DocumentEvent?) = validate()
            override fun removeUpdate(e: javax.swing.event.DocumentEvent?) = validate()
            override fun changedUpdate(e: javax.swing.event.DocumentEvent?) = validate()
            private fun validate() {
                val text = tfAssetUid.text.trim()
                val valid = AgentConfig.ASSET_UID_REGEX.matches(text)
                lblError.text = if (text.isNotEmpty() && !valid) {
                    "형식: [B|R|C|L|S][유형코드][5자리 숫자]"
                } else " "
                updateActionState()
            }
        })
        panel.add(tfAssetUid)
        panel.add(lblError)

        // ── 전송 주기 ──────────────────────────────────────────────────

        panel.add(Box.createVerticalStrut(8))
        panel.add(createSectionLabel("전송 주기"))

        cbInterval.maximumSize = Dimension(Int.MAX_VALUE, 30)
        cbInterval.selectedIndex = 1
        panel.add(cbInterval)

        // ── 버튼 ────────────────────────────────────────────────────────

        panel.add(Box.createVerticalStrut(12))
        val btnPanel = JPanel(FlowLayout(FlowLayout.CENTER))

        btnStart.addActionListener { onStart() }
        btnSendNow.addActionListener { onSendNow() }

        btnPanel.add(btnStart)
        btnPanel.add(btnSendNow)
        panel.add(btnPanel)

        // ── 구분선 ──────────────────────────────────────────────────────

        panel.add(Box.createVerticalStrut(8))
        panel.add(JSeparator())
        panel.add(Box.createVerticalStrut(8))

        // ── 상태 정보 ──────────────────────────────────────────────────

        panel.add(createSectionLabel("상태 정보"))
        panel.add(lblAssetUid)
        panel.add(lblInterval)
        panel.add(lblLastSent)
        panel.add(lblVersion)

        panel.add(Box.createVerticalStrut(8))
        panel.add(JSeparator())
        panel.add(Box.createVerticalStrut(8))

        panel.add(createSectionLabel("사용자 확인"))
        panel.add(lblVerification)

        return panel
    }

    private fun loadSavedState() {
        val uid = app.prefs.assetUid
        if (uid != null) {
            tfAssetUid.text = uid
            if (app.isRunning) {
                tfAssetUid.isEditable = false
                btnStart.text = "실행 중"
            }
        }

        updateStatusLabels()
        updateActionState()
    }

    private fun updateActionState() {
        val validAssetUid = AgentConfig.ASSET_UID_REGEX.matches(tfAssetUid.text.trim())
        val authenticated = app.hasPersonalSession
        btnStart.isEnabled = validAssetUid && authenticated && !app.isRunning
        btnSendNow.isEnabled = app.isRunning && authenticated
        btnSignIn.text = if (authenticated) "다른 OA 계정으로 로그인" else "OA 계정 로그인"
        lblAuthentication.text = if (authenticated) {
            "OA 계정: 로그인됨 (자산 담당자 또는 관리자)"
        } else {
            "OA 계정: 로그인 필요"
        }
    }

    private fun updateStatusLabels() {
        lblAssetUid.text = "자산 번호: ${app.prefs.assetUid ?: "-"}"
        lblInterval.text = "전송 주기: ${app.prefs.intervalMinutes}분"

        val lastTime = app.prefs.lastHeartbeatTime
        lblLastSent.text = if (lastTime > 0) {
            "마지막 전송: ${dateFormat.format(Date(lastTime))}"
        } else {
            "마지막 전송: -"
        }

        val lastVerified = app.prefs.lastVerifiedAt
        lblVerification.text = if (lastVerified > 0) {
            "사용자 확인: ✓ 완료 (${dateFormat.format(Date(lastVerified))})"
        } else {
            "사용자 확인: 미확인"
        }

        updateActionState()
    }

    private fun onStart() {
        if (!app.hasPersonalSession) {
            JOptionPane.showMessageDialog(
                this,
                "Heartbeat를 시작하려면 자산 담당자 또는 관리자 OA 계정으로 로그인하세요.",
                "OA 계정 로그인 필요",
                JOptionPane.WARNING_MESSAGE,
            )
            return
        }

        val assetUid = tfAssetUid.text.trim()
        val interval = when (cbInterval.selectedIndex) {
            0 -> 5
            2 -> 30
            else -> 15
        }

        app.prefs.assetUid = assetUid
        app.prefs.intervalMinutes = interval
        if (!app.start()) {
            updateActionState()
            return
        }

        tfAssetUid.isEditable = false
        btnStart.isEnabled = false
        btnStart.text = "실행 중"
        btnSendNow.isEnabled = true

        updateStatusLabels()
        JOptionPane.showMessageDialog(
            this,
            "OA Agent가 시작되었습니다.\n자산 번호: $assetUid\n전송 주기: ${interval}분",
            "시작 완료",
            JOptionPane.INFORMATION_MESSAGE,
        )
    }

    private fun onSignIn() {
        val tfAccount = JTextField(24)
        val pfPassword = JPasswordField(24)
        val form = JPanel(GridLayout(0, 1, 0, 6)).apply {
            add(JLabel("자산 담당자 또는 관리자 개인 OA 계정으로 로그인하세요."))
            add(JLabel("사번 또는 OA 계정 이메일"))
            add(tfAccount)
            add(JLabel("비밀번호"))
            add(pfPassword)
        }

        val choice = JOptionPane.showConfirmDialog(
            this,
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
                this,
                "OA 계정과 비밀번호를 모두 입력하세요.",
                "입력 확인",
                JOptionPane.WARNING_MESSAGE,
            )
            return
        }

        btnSignIn.isEnabled = false
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

            SwingUtilities.invokeLater {
                btnSignIn.isEnabled = true
                updateActionState()
                if (signedIn) {
                    JOptionPane.showMessageDialog(
                        this,
                        "개인 OA 계정으로 로그인했습니다. 자산 번호를 확인한 뒤 시작하세요.",
                        "로그인 완료",
                        JOptionPane.INFORMATION_MESSAGE,
                    )
                } else {
                    JOptionPane.showMessageDialog(
                        this,
                        "로그인에 실패했습니다. 계정 또는 자산 담당자/관리자 권한을 확인하세요.",
                        "로그인 실패",
                        JOptionPane.ERROR_MESSAGE,
                    )
                }
            }
        }.start()
    }

    private fun onSendNow() {
        btnSendNow.isEnabled = false
        btnSendNow.text = "전송 중..."

        Thread {
            try {
                kotlinx.coroutines.runBlocking { app.sendHeartbeatOnce() }
                SwingUtilities.invokeLater {
                    btnSendNow.isEnabled = true
                    btnSendNow.text = "즉시 전송"
                    updateStatusLabels()
                    JOptionPane.showMessageDialog(
                        this, "Heartbeat 전송 완료", "성공", JOptionPane.INFORMATION_MESSAGE
                    )
                }
            } catch (e: Exception) {
                SwingUtilities.invokeLater {
                    btnSendNow.isEnabled = true
                    btnSendNow.text = "즉시 전송"
                    JOptionPane.showMessageDialog(
                        this, "전송 실패: ${e.message}", "오류", JOptionPane.ERROR_MESSAGE
                    )
                }
            }
        }.start()
    }

    private fun createSectionLabel(text: String): JLabel {
        return JLabel(text).apply {
            font = font.deriveFont(Font.BOLD, 12f)
            alignmentX = Component.LEFT_ALIGNMENT
            border = EmptyBorder(0, 0, 4, 0)
        }
    }
}
