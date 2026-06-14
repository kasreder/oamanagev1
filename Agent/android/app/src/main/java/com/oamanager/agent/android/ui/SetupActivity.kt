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
import android.graphics.Color
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.R
import com.oamanager.agent.android.service.AdminCommandEvents
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
    private lateinit var tvUserName: TextView
    private lateinit var tvEmployeeId: TextView
    private lateinit var btnVerify: Button
    private lateinit var progressBar: ProgressBar

    // OS 정보 (접기/펼치기)
    private lateinit var headerOsInfo: LinearLayout
    private lateinit var sectionOsInfo: LinearLayout
    private lateinit var tvOsToggleIndicator: TextView
    private lateinit var tvOsVersion: TextView
    private lateinit var tvOsDetail: TextView
    private lateinit var tvOsBuild: TextView
    private lateinit var tvOsSecurityPatch: TextView
    private lateinit var tvOsVendorPatch: TextView
    private lateinit var tvOsUbr: TextView
    private lateinit var tvOsKbList: TextView
    private lateinit var tvOsPatchStatus: TextView

    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())

    override fun onResume() {
        super.onResume()
        viewModel.refreshFromPrefs()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            setContentView(R.layout.activity_setup)

            bindViews()
            setupAssetUidValidation()
            setupIntervalSpinner()
            setupButtons()
            observeState()
            observeAdminCommandEvents()

            // 배터리 최적화 예외 요청
            try { requestBatteryOptimization() } catch (_: Exception) {}

            // 알림 권한 요청 (Android 13+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                requestPermissions(
                    arrayOf(android.Manifest.permission.POST_NOTIFICATIONS),
                    1001
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("SetupActivity", "onCreate 크래시", e)
            Toast.makeText(this, "초기화 오류: ${e.message}", Toast.LENGTH_LONG).show()
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
        tvUserName = findViewById(R.id.tv_user_name)
        tvEmployeeId = findViewById(R.id.tv_employee_id)
        btnVerify = findViewById(R.id.btn_verify)
        progressBar = findViewById(R.id.progress_bar)

        headerOsInfo = findViewById(R.id.header_os_info)
        sectionOsInfo = findViewById(R.id.section_os_info)
        tvOsToggleIndicator = findViewById(R.id.tv_os_toggle_indicator)
        tvOsVersion = findViewById(R.id.tv_os_version)
        tvOsDetail = findViewById(R.id.tv_os_detail)
        tvOsBuild = findViewById(R.id.tv_os_build)
        tvOsSecurityPatch = findViewById(R.id.tv_os_security_patch)
        tvOsVendorPatch = findViewById(R.id.tv_os_vendor_patch)
        tvOsUbr = findViewById(R.id.tv_os_ubr)
        tvOsKbList = findViewById(R.id.tv_os_kb_list)
        tvOsPatchStatus = findViewById(R.id.tv_os_patch_status)

        headerOsInfo.setOnClickListener {
            val expanded = sectionOsInfo.visibility == View.VISIBLE
            sectionOsInfo.visibility = if (expanded) View.GONE else View.VISIBLE
            tvOsToggleIndicator.text = if (expanded) "▼" else "▲"
        }
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
        // 주기는 관리자가 서버(agent_settings)에서 설정 — 스피너는 읽기 전용으로 현재 값 표시
        val intervals = arrayOf("5분", "15분", "30분")
        val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, intervals)
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        spinnerInterval.adapter = adapter
        spinnerInterval.isEnabled = false // 서버 설정 기반 — 수동 변경 불가
        updateSpinnerSelection()
    }

    private fun updateSpinnerSelection() {
        val interval = viewModel.uiState.value.intervalMinutes
        val index = when (interval) {
            5 -> 0
            30 -> 2
            else -> 1
        }
        spinnerInterval.setSelection(index)
    }

    private fun setupButtons() {
        btnStart.setOnClickListener {
            val assetUid = etAssetUid.text.toString().trim()
            val interval = viewModel.uiState.value.intervalMinutes
            viewModel.startAgent(assetUid, interval)
        }

        btnSendNow.setOnClickListener {
            viewModel.sendNow()
        }

        btnVerify.setOnClickListener {
            showVerificationDialog()
        }
    }

    private fun observeAdminCommandEvents() {
        lifecycleScope.launch {
            AdminCommandEvents.events.collect { event ->
                when (event) {
                    is AdminCommandEvents.Event.HeartbeatAck -> {
                        viewModel.refreshFromPrefs()
                        viewModel.flashAdminHighlight()
                    }
                }
            }
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
                tvInterval.text = if (state.intervalMinutes >= 60)
                    "전송 주기: ${state.intervalMinutes / 60}시간 (서버 설정)"
                else
                    "전송 주기: ${state.intervalMinutes}분 (서버 설정)"
                updateSpinnerSelection()
                tvLastHeartbeat.text = if (state.lastHeartbeatTime > 0) {
                    "마지막 전송: ${dateFormat.format(Date(state.lastHeartbeatTime))}"
                } else {
                    "마지막 전송: -"
                }
                // 관리자 명령으로 트리거된 직후 3초간 강조 (노란 배경)
                tvLastHeartbeat.setBackgroundColor(
                    if (state.highlightHeartbeat) Color.parseColor("#FFF59D") else Color.TRANSPARENT
                )
                tvSendResult.text = state.lastSendResult?.let { "전송 결과: $it" } ?: ""
                tvAgentVersion.text = "에이전트 버전: ${getVersionName()}"

                // 사용자 확인
                tvVerificationStatus.text = when (state.verificationStatus) {
                    "verified" -> "상태: ✓ 확인 완료"
                    "mismatch" -> "상태: ⚠ 불일치"
                    else -> "상태: 미확인"
                }
                tvUserName.text = "사용자 이름: ${state.assetUserName?.takeIf { it.isNotBlank() } ?: "-"}"
                tvEmployeeId.text = "사번: ${state.employeeId?.takeIf { it.isNotBlank() } ?: "-"}"
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

                // OS / 보안패치 정보
                bindOsInfo(state.systemInfo)

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

    /** OS/보안패치 정보 바인딩 — null이면 "수집 중" 표시. */
    private fun bindOsInfo(info: com.oamanager.agent.model.SystemInfo?) {
        if (info == null) {
            tvOsVersion.text = "OS 버전: 수집 중..."
            return
        }
        tvOsVersion.text = "OS 버전: ${info.osVersion.ifEmpty { "-" }}"
        tvOsDetail.text = "OS 상세: ${info.osDetailVersion.ifEmpty { "-" }}"
        tvOsBuild.text = "빌드 번호: ${info.osBuildNumber.ifEmpty { "-" }}"
        tvOsSecurityPatch.text =
            "보안패치 날짜: ${info.osSecurityPatch.ifEmpty { "-" }}"
        tvOsVendorPatch.text =
            "벤더 패치: ${info.osVendorSecurityPatch.ifEmpty { "-" }}"
        tvOsUbr.text = "UBR: ${info.osUbr}"
        tvOsUbr.visibility = if (info.osUbr.isNotEmpty()) View.VISIBLE else View.GONE
        val kbShort = if (info.osKbList.length > 80)
            info.osKbList.substring(0, 80) + "..."
        else info.osKbList
        tvOsKbList.text = "적용 KB: $kbShort"
        tvOsKbList.visibility =
            if (info.osKbList.isNotEmpty()) View.VISIBLE else View.GONE

        // 보안 패치 신선도 평가 (Android만 기준 — 6개월=빨강, 3개월=주황)
        val patch = info.osSecurityPatch
        if (patch.matches(Regex("^\\d{4}-\\d{2}-\\d{2}$"))) {
            val now = System.currentTimeMillis()
            val patchMs = try {
                java.text.SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
                    .parse(patch)?.time ?: 0L
            } catch (_: Exception) { 0L }
            val ageDays = if (patchMs > 0) (now - patchMs) / (1000L * 60 * 60 * 24) else -1
            when {
                ageDays < 0 -> {
                    tvOsPatchStatus.text = ""
                }
                ageDays > 180 -> {
                    tvOsPatchStatus.text = "⚠ 보안 패치 ${ageDays}일 경과 — 위험 (180일 초과)"
                    tvOsPatchStatus.setTextColor(Color.parseColor("#D32F2F"))
                }
                ageDays > 90 -> {
                    tvOsPatchStatus.text = "⚠ 보안 패치 ${ageDays}일 경과 — 주의 (90일 초과)"
                    tvOsPatchStatus.setTextColor(Color.parseColor("#F57C00"))
                }
                else -> {
                    tvOsPatchStatus.text = "✓ 보안 패치 양호 (${ageDays}일 경과)"
                    tvOsPatchStatus.setTextColor(Color.parseColor("#388E3C"))
                }
            }
        } else {
            tvOsPatchStatus.text = ""
        }
    }

    private fun getVersionName(): String {
        return try {
            packageManager.getPackageInfo(packageName, 0).versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }
    }
}
