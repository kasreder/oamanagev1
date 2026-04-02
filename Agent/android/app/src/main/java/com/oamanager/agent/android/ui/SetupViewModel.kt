package com.oamanager.agent.android.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.oamanager.agent.AgentConfig
import com.oamanager.agent.android.OAAgentApp
import com.oamanager.agent.android.data.AgentPreferences
import com.oamanager.agent.network.AuthManager
import com.oamanager.agent.network.SupabaseClient
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.jsonPrimitive

/**
 * SetupActivity ViewModel.
 *
 * 에이전트 설정 상태, Heartbeat 전송, 사용자 확인, 자산 수령 확인을 관리합니다.
 */
class SetupViewModel(application: Application) : AndroidViewModel(application) {

    private val prefs = AgentPreferences(application)
    private val client = SupabaseClient(AgentConfig.SUPABASE_URL, AgentConfig.SUPABASE_ANON_KEY)
    private val authManager = AuthManager(client, prefs)

    // ─── UI State ───────────────────────────────────────────────────────

    data class UiState(
        val assetUid: String = "",
        val intervalMinutes: Int = 15,
        val isRunning: Boolean = false,
        val lastHeartbeatTime: Long = 0L,
        val lastSendResult: String? = null,
        val verificationStatus: String? = null,
        val lastVerifiedAt: Long = 0L,
        val assignmentStatus: String? = null,
        val isLoading: Boolean = false,
        val message: String? = null,
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        loadSavedState()
        fetchServerInterval()
    }

    private fun loadSavedState() {
        _uiState.value = _uiState.value.copy(
            assetUid = prefs.assetUid ?: "",
            intervalMinutes = prefs.intervalMinutes,
            lastHeartbeatTime = prefs.lastHeartbeatTime,
            isRunning = prefs.assetUid != null,
            lastVerifiedAt = prefs.lastVerifiedAt,
        )
    }

    /**
     * 서버 agent_settings에서 heartbeat_interval을 가져와 UI에 반영합니다.
     * 서버 값이 있으면 로컬 설정을 덮어씁니다.
     */
    private fun fetchServerInterval() {
        viewModelScope.launch {
            try {
                val token = authManager.getValidToken() ?: return@launch
                val settings = client.getAgentSettings(token)
                val serverInterval = settings["heartbeat_interval"]?.toIntOrNull()
                if (serverInterval != null && serverInterval > 0) {
                    prefs.intervalMinutes = serverInterval
                    _uiState.value = _uiState.value.copy(
                        intervalMinutes = serverInterval,
                    )
                    // 이미 실행 중이면 새 주기로 재시작
                    if (prefs.assetUid != null) {
                        val app = getApplication<OAAgentApp>()
                        app.enqueueHeartbeat(serverInterval)
                    }
                }
            } catch (_: Exception) {
                // 서버 조회 실패 시 로컬 설정 유지
            }
        }
    }

    // ─── Asset UID 검증 ─────────────────────────────────────────────────

    fun isValidAssetUid(uid: String): Boolean {
        return AgentConfig.ASSET_UID_REGEX.matches(uid)
    }

    // ─── 시작/설정 저장 ─────────────────────────────────────────────────

    fun startAgent(assetUid: String, intervalMinutes: Int) {
        if (!isValidAssetUid(assetUid)) return

        prefs.assetUid = assetUid
        prefs.intervalMinutes = intervalMinutes

        val app = getApplication<OAAgentApp>()
        app.enqueueHeartbeat(intervalMinutes)

        _uiState.value = _uiState.value.copy(
            assetUid = assetUid,
            intervalMinutes = intervalMinutes,
            isRunning = true,
        )

        // 배정 상태 확인
        checkAssignmentStatus()
    }

    // ─── 즉시 전송 ──────────────────────────────────────────────────────

    fun sendNow() {
        val assetUid = prefs.assetUid ?: return
        _uiState.value = _uiState.value.copy(lastSendResult = "전송 중...")

        viewModelScope.launch {
            try {
                val token = authManager.getValidToken()
                    ?: throw IllegalStateException("인증 실패")

                val systemInfo = com.oamanager.agent.platform.SystemInfoCollector(
                    context = getApplication(),
                    assetUserName = prefs.assetUserName ?: "",
                    employeeId = prefs.employeeId ?: "",
                    agentVersion = "1.0.0",
                ).collect()

                client.updateHeartbeat(token, assetUid, systemInfo)
                prefs.lastHeartbeatTime = System.currentTimeMillis()

                _uiState.value = _uiState.value.copy(
                    lastSendResult = "전송 성공!",
                    lastHeartbeatTime = System.currentTimeMillis(),
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    lastSendResult = "전송 실패: ${e.message}",
                )
            }
        }
    }

    // ─── 사용자 확인 ────────────────────────────────────────────────────

    fun needsVerification(): Boolean {
        val intervalDays = 30 // 기본값, 서버에서 조회 가능
        val lastVerified = prefs.lastVerifiedAt
        if (lastVerified == 0L) return true
        val daysSince = (System.currentTimeMillis() - lastVerified) / (1000L * 60 * 60 * 24)
        return daysSince >= intervalDays
    }

    fun verifyUser(userName: String, employeeId: String) {
        val assetUid = prefs.assetUid ?: return
        _uiState.value = _uiState.value.copy(isLoading = true)

        viewModelScope.launch {
            try {
                val token = authManager.getValidToken()
                    ?: throw IllegalStateException("인증 실패")

                val result = client.verifyUser(token, assetUid, userName, employeeId)
                val matched = result["matched"]?.jsonPrimitive?.boolean ?: false
                val message = result["message"]?.jsonPrimitive?.content ?: ""

                if (matched) {
                    prefs.lastVerifiedAt = System.currentTimeMillis()
                    prefs.assetUserName = userName
                    prefs.employeeId = employeeId
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    verificationStatus = if (matched) "verified" else "mismatch",
                    lastVerifiedAt = if (matched) System.currentTimeMillis() else prefs.lastVerifiedAt,
                    message = message,
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    message = "확인 실패: ${e.message}",
                )
            }
        }
    }

    // ─── 자산 수령 확인 ─────────────────────────────────────────────────

    private fun checkAssignmentStatus() {
        val assetUid = prefs.assetUid ?: return
        viewModelScope.launch {
            try {
                val token = authManager.getValidToken() ?: return@launch
                val assignment = client.getAssetAssignment(token, assetUid)
                val status = assignment?.get("assignment_status")?.jsonPrimitive?.content
                _uiState.value = _uiState.value.copy(assignmentStatus = status)
            } catch (_: Exception) { }
        }
    }

    fun confirmAssignment(userName: String) {
        val assetUid = prefs.assetUid ?: return
        _uiState.value = _uiState.value.copy(isLoading = true)

        viewModelScope.launch {
            try {
                val token = authManager.getValidToken()
                    ?: throw IllegalStateException("인증 실패")

                val result = client.confirmAssignment(token, assetUid, userName)
                val success = result["success"]?.jsonPrimitive?.boolean ?: false
                val message = result["message"]?.jsonPrimitive?.content ?: ""

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    assignmentStatus = if (success) "confirmed" else "pending",
                    message = message,
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    message = "수령 확인 실패: ${e.message}",
                )
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        client.close()
    }
}
