package com.oamanager.agent.windows.ui

import com.oamanager.agent.windows.WindowsAgentApp
import java.awt.*
import javax.swing.*
import javax.swing.border.EmptyBorder

/**
 * 사용자 확인 다이얼로그 (Swing).
 *
 * 이름 + 사번 입력 → verify_user RPC 호출.
 */
class VerificationDialog(private val app: WindowsAgentApp) : JDialog() {

    private val tfName = JTextField(15)
    private val tfEmployeeId = JTextField(15)
    private val btnVerify = JButton("확인")
    private val lblResult = JLabel(" ")

    init {
        title = "사용자 확인"
        isModal = true
        defaultCloseOperation = DISPOSE_ON_CLOSE
        isResizable = false

        contentPane = buildUI()
        pack()
        setLocationRelativeTo(null)
    }

    private fun buildUI(): JPanel {
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = EmptyBorder(16, 16, 16, 16)

        panel.add(JLabel("현재 사용자 정보를 확인합니다.").apply {
            alignmentX = Component.LEFT_ALIGNMENT
        })
        panel.add(Box.createVerticalStrut(12))

        // 이름
        panel.add(JLabel("이름").apply { font = font.deriveFont(Font.BOLD) })
        tfName.maximumSize = Dimension(Int.MAX_VALUE, 30)
        panel.add(tfName)
        panel.add(Box.createVerticalStrut(8))

        // 사번
        panel.add(JLabel("사번").apply { font = font.deriveFont(Font.BOLD) })
        tfEmployeeId.maximumSize = Dimension(Int.MAX_VALUE, 30)
        panel.add(tfEmployeeId)
        panel.add(Box.createVerticalStrut(12))

        // 버튼
        btnVerify.addActionListener { onVerify() }
        val btnPanel = JPanel(FlowLayout(FlowLayout.CENTER))
        btnPanel.add(btnVerify)
        panel.add(btnPanel)

        // 결과
        lblResult.alignmentX = Component.LEFT_ALIGNMENT
        panel.add(lblResult)

        return panel
    }

    private fun onVerify() {
        val name = tfName.text.trim()
        val empId = tfEmployeeId.text.trim()

        if (name.isEmpty() || empId.isEmpty()) {
            lblResult.text = "이름과 사번을 모두 입력하세요."
            lblResult.foreground = Color.RED
            return
        }

        btnVerify.isEnabled = false
        lblResult.text = "확인 중..."
        lblResult.foreground = Color.GRAY

        Thread {
            try {
                val (matched, message) = kotlinx.coroutines.runBlocking {
                    app.verifyUser(name, empId)
                }
                SwingUtilities.invokeLater {
                    btnVerify.isEnabled = true
                    lblResult.text = message
                    lblResult.foreground = if (matched) Color(0x2E, 0x7D, 0x32) else Color.RED

                    if (matched) {
                        JOptionPane.showMessageDialog(
                            this, "✓ 사용자 확인 완료", "확인 완료", JOptionPane.INFORMATION_MESSAGE
                        )
                        dispose()
                    }
                }
            } catch (e: Exception) {
                SwingUtilities.invokeLater {
                    btnVerify.isEnabled = true
                    lblResult.text = "오류: ${e.message}"
                    lblResult.foreground = Color.RED
                }
            }
        }.start()
    }
}
