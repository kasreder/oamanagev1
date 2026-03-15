package com.oamanager.agent.android.ui

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.text.Editable
import android.text.TextWatcher
import android.view.View
import android.widget.*
import androidx.activity.viewModels
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.R
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

/**
 * 초기 설정 화면.
 *
 * - asset_uid 입력 (정규식 실시간 검증)
 * - 전송 주기 선택 (5분/15분/30분)
 * - "시작" / "즉시 전송" 버튼
 * - 상태 정보 표시
 * - 사용자 확인 / 자산 수령 확인
 */
class SetupActivity : AppCompatActivity() {

    private val viewModel: SetupViewModel by viewModels()

    // Views
    private lateinit var etAssetUid: EditText
    private lateinit var tvAssetUidError: TextView
    private lateinit var spinnerInterval: Spinner
    private lateinit var btnStart: Button
    private lateinit var btnSendNow: Button
    private lateinit var tvStatus: TextView
    private lateinit var tvAssetUidDisplay: TextView
    private lateinit var tvInterval: TextView
    private lateinit var tvLastHeartbeat: TextView
    private lateinit var tvSendResult: TextView
    private lateinit var tvAgentVersion: TextView
    private lateinit var tvVerificationStatus: TextView
    private lateinit var tvLastVerified: TextView
    private lateinit var btnVerify: Button
    private lateinit var progressBar: ProgressBar

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_setup)

        bindViews()
        setupAssetUidValidation()
        setupIntervalSpinner()
        setupButtons()
        observeState()

        // 배터리 최적화 예외 요청
        requestBatteryOptimization()

        // 알림 권한 요청 (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(
                arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                1001
            )
        }
    }

    private fun bindViews() {
        etAssetUid = findViewById(R.id.et_asset_uid)
        tvAssetUidError = findViewById(R.id.tv_asset_uid_error)
        spinnerInterval = findViewById(R.id.spinner_interval)
        btnStart = findViewById(R.id.btn_start)
        btnSendNow = findViewById(R.id.btn_send_now)
        tvStatus = findViewById(R.id.tv_status)
        tvAssetUidDisplay = findViewById(R.id.tv_asset_uid_display)
        tvInterval = findViewById(R.id.tv_interval)
        tvLastHeartbeat = findViewById(R.id.tv_last_heartbeat)
        tvSendResult = findViewById(R.id.tv_send_result)
        tvAgentVersion = findViewById(R.id.tv_agent_version)
        tvVerificationStatus = findViewById(R.id.tv_verification_status)
        tvLastVerified = findViewById(R.id.tv_last_verified)
        btnVerify = findViewById(R.id.btn_verify)
        progressBar = findViewById(R.id.progress_bar)
    }

    private fun setupAssetUidValidation() {
        etAssetUid.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
            override fun afterTextChanged(s: Editable?) {
                val text = s?.toString() ?: ""
                val isValid = viewModel.isValidAssetUid(text)
                tvAssetUidError.visibility = if (text.isNotEmpty() && !isValid) View.VISIBLE else View.GONE
                btnStart.isEnabled = isValid
            }
        })
    }

    private fun setupIntervalSpinner() {
        val intervals = arrayOf("5분", "15분 (기본값)", "30분")
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, intervals)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spinnerInterval.adapter = adapter
        spinnerInterval.setSelection(1) // 기본값: 15분
    }

    private fun setupButtons() {
        btnStart.setOnClickListener {
            val assetUid = etAssetUid.text.toString().trim()
            val interval = when (spinnerInterval.selectedItemPosition) {
                0 -> 5
                2 -> 30
                else -> 15
            }
            viewModel.startAgent(assetUid, interval)
        }

        btnSendNow.setOnClickListener {
            viewModel.sendNow()
        }

        btnVerify.setOnClickListener {
            showVerificationDialog()
        }
    }

    private fun observeState() {
        lifecycleScope.launch {
            viewModel.uiState.collectLatest { state ->
                // 설정 영역
                if (state.isRunning) {
                    etAssetUid.setText(state.assetUid)
                    etAssetUid.isEnabled = false
                    btnSendNow.isEnabled = true
                }

                // 상태 표시
                tvAssetUidDisplay.text = "자산 번호: ${state.assetUid.ifEmpty { "-" }}"
                tvInterval.text = "전송 주기: ${state.intervalMinutes}분"
                tvLastHeartbeat.text = if (state.lastHeartbeatTime > 0) {
                    "마지막 전송: ${dateFormat.format(Date(state.lastHeartbeatTime))}"
                } else {
                    "마지막 전송: -"
                }
                tvSendResult.text = state.lastSendResult?.let { "전송 결과: $it" } ?: ""
                tvAgentVersion.text = "에이전트 버전: ${getVersionName()}"

                // 사용자 확인
                tvVerificationStatus.text = when (state.verificationStatus) {
                    "verified" -> "상태: ✓ 확인 완료"
                    "mismatch" -> "상태: ⚠ 불일치"
                    else -> "상태: 미확인"
                }
                tvLastVerified.text = if (state.lastVerifiedAt > 0) {
                    "마지막 확인: ${dateFormat.format(Date(state.lastVerifiedAt))}"
                } else {
                    "마지막 확인: -"
                }

                // 사용자 확인 필요 시 버튼 강조
                btnVerify.isEnabled = state.isRunning
                if (viewModel.needsVerification() && state.isRunning) {
                    btnVerify.text = "⚠ 사용자 확인 필요"
                } else {
                    btnVerify.text = "사용자 확인하기"
                }

                // 자산 수령 확인
                if (state.assignmentStatus == "pending") {
                    showAssignmentDialog()
                }

                // 로딩
                progressBar.visibility = if (state.isLoading) View.VISIBLE else View.GONE

                // 메시지
                state.message?.let {
                    Toast.makeText(this@SetupActivity, it, Toast.LENGTH_LONG).show()
                }
            }
        }
    }

    // ─── 다이얼로그 ─────────────────────────────────────────────────────

    private fun showVerificationDialog() {
        val dialogView = layoutInflater.inflate(R.layout.activity_setup, null)
        // 간단한 다이얼로그로 구현
        val etName = EditText(this).apply { hint = "이름" }
        val etEmpId = EditText(this).apply { hint = "사번" }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 24, 48, 24)
            addView(TextView(context).apply { text = "현재 사용자 정보를 확인합니다." })
            addView(etName)
            addView(etEmpId)
        }

        AlertDialog.Builder(this)
            .setTitle("사용자 확인")
            .setView(layout)
            .setPositiveButton("확인") { _, _ ->
                val name = etName.text.toString().trim()
                val empId = etEmpId.text.toString().trim()
                if (name.isNotEmpty() && empId.isNotEmpty()) {
                    viewModel.verifyUser(name, empId)
                }
            }
            .setNegativeButton("취소", null)
            .show()
    }

    private fun showAssignmentDialog() {
        val etName = EditText(this).apply { hint = "이름 입력" }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(48, 24, 48, 24)
            addView(TextView(context).apply {
                text = "이 자산이 배정되었습니다.\n수령을 확인하려면 본인 이름을 입력하세요."
            })
            addView(etName)
        }

        AlertDialog.Builder(this)
            .setTitle("자산 수령 확인")
            .setView(layout)
            .setCancelable(false)
            .setPositiveButton("수령 확인") { _, _ ->
                val name = etName.text.toString().trim()
                if (name.isNotEmpty()) {
                    viewModel.confirmAssignment(name)
                }
            }
            .show()
    }

    // ─── 배터리 최적화 ──────────────────────────────────────────────────

    private fun requestBatteryOptimization() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        } catch (_: Exception) { }
    }

    private fun getVersionName(): String {
        return try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }
    }
}
