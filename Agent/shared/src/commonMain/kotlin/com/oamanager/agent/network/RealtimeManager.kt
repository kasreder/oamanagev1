package com.oamanager.agent.network

import com.oamanager.agent.AgentConfig
import io.ktor.client.*
import io.ktor.client.plugins.websocket.*
import io.ktor.websocket.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.*
import kotlin.math.min

/**
 * Supabase Realtime WebSocket 연결 관리.
 *
 * Phoenix Channels v1 프로토콜 기반으로 Presence, Broadcast 채널을 관리합니다.
 * - Presence: `agent-presence:global` 채널로 접속 상태 공유
 * - Broadcast 명령 수신: `agent-commands:{asset_uid}` 채널
 * - Broadcast 알림 발신: `agent-alerts:global` 채널
 */
class RealtimeManager(
    private val config: AgentConfig = AgentConfig,
    private val authManager: AuthManager,
) {
    /** WebSocket 연결 상태 */
    enum class ConnectionState { DISCONNECTED, CONNECTING, CONNECTED }

    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val client = HttpClient {
        install(WebSockets)
    }

    private var session: WebSocketSession? = null
    private var heartbeatJob: Job? = null
    private var receiveJob: Job? = null
    private var reconnectAttempt = 0
    private var scope: CoroutineScope? = null

    // Phoenix Channel 참조 번호
    private var refCounter = 0
    private fun nextRef(): String = (++refCounter).toString()

    // 채널 join 상태 추적
    private val joinedChannels = mutableSetOf<String>()

    // 명령 수신 콜백
    private var commandHandler: ((command: String, params: JsonObject) -> Unit)? = null

    private val json = Json { ignoreUnknownKeys = true }

    // ─── 연결 ────────────────────────────────────────────────────────────

    /**
     * WebSocket 연결을 시작합니다.
     */
    suspend fun connect(coroutineScope: CoroutineScope) {
        if (_connectionState.value == ConnectionState.CONNECTED) return
        scope = coroutineScope
        _connectionState.value = ConnectionState.CONNECTING

        try {
            val token = authManager.getValidToken()
                ?: throw IllegalStateException("No valid token")

            val url = config.REALTIME_URL
            session = client.webSocketSession(url) {
                headers.append("Authorization", "Bearer $token")
            }

            _connectionState.value = ConnectionState.CONNECTED
            reconnectAttempt = 0

            // Phoenix heartbeat 시작
            startPhoenixHeartbeat()
            // 수신 루프 시작
            startReceiveLoop()
        } catch (e: Exception) {
            _connectionState.value = ConnectionState.DISCONNECTED
            reconnectWithBackoff()
        }
    }

    /**
     * 연결을 종료합니다.
     */
    suspend fun disconnect() {
        heartbeatJob?.cancel()
        receiveJob?.cancel()
        joinedChannels.clear()
        try {
            session?.close(CloseReason(CloseReason.Codes.NORMAL, "Client disconnect"))
        } catch (_: Exception) { }
        session = null
        _connectionState.value = ConnectionState.DISCONNECTED
    }

    // ─── 채널 참여 ──────────────────────────────────────────────────────

    /**
     * Presence 채널(`agent-presence:global`)에 참여합니다.
     */
    suspend fun joinPresence(assetUid: String, platform: String, agentVersion: String) {
        val topic = "realtime:agent-presence:global"
        val presenceState = buildJsonObject {
            put("asset_uid", assetUid)
            put("platform", platform)
            put("agent_version", agentVersion)
            put("connected_at", kotlinx.datetime.Clock.System.now().toString())
        }
        sendPhoenixMessage(topic, "phx_join", buildJsonObject {
            put("config", buildJsonObject {
                put("presence", buildJsonObject {
                    put("key", assetUid)
                })
            })
            put("presence", presenceState)
        })
        joinedChannels.add(topic)
    }

    /**
     * 명령 수신 채널(`agent-commands:{asset_uid}`)에 참여합니다.
     */
    suspend fun joinCommandChannel(assetUid: String) {
        val topic = "realtime:agent-commands:$assetUid"
        sendPhoenixMessage(topic, "phx_join", buildJsonObject {
            put("config", buildJsonObject {
                put("broadcast", buildJsonObject {
                    put("self", JsonPrimitive(false))
                })
            })
        })
        joinedChannels.add(topic)
    }

    /**
     * 알림 발신 채널(`agent-alerts:global`)에 참여합니다.
     */
    suspend fun joinAlertChannel() {
        val topic = "realtime:agent-alerts:global"
        sendPhoenixMessage(topic, "phx_join", buildJsonObject {
            put("config", buildJsonObject {
                put("broadcast", buildJsonObject {
                    put("self", JsonPrimitive(false))
                })
            })
        })
        joinedChannels.add(topic)
    }

    // ─── Broadcast 전송 ─────────────────────────────────────────────────

    /**
     * 알림을 Broadcast로 전송합니다.
     */
    suspend fun sendAlert(
        assetUid: String,
        alertType: String,
        message: String,
        data: JsonObject = buildJsonObject {},
    ) {
        val topic = "realtime:agent-alerts:global"
        sendPhoenixMessage(topic, "broadcast", buildJsonObject {
            put("event", "alert")
            put("payload", buildJsonObject {
                put("asset_uid", assetUid)
                put("alert_type", alertType)
                put("message", message)
                put("data", data)
                put("timestamp", kotlinx.datetime.Clock.System.now().toString())
            })
        })
    }

    // ─── 명령 수신 콜백 ─────────────────────────────────────────────────

    /**
     * Broadcast 명령 수신 시 호출될 콜백을 등록합니다.
     */
    fun onCommand(handler: (command: String, params: JsonObject) -> Unit) {
        commandHandler = handler
    }

    // ─── Phoenix 프로토콜 내부 ──────────────────────────────────────────

    private suspend fun sendPhoenixMessage(
        topic: String,
        event: String,
        payload: JsonObject = buildJsonObject {},
    ) {
        val message = buildJsonArray {
            add(JsonNull)                // join_ref
            add(JsonPrimitive(nextRef())) // ref
            add(JsonPrimitive(topic))    // topic
            add(JsonPrimitive(event))    // event
            add(payload)                 // payload
        }
        session?.send(Frame.Text(message.toString()))
    }

    private fun startPhoenixHeartbeat() {
        heartbeatJob?.cancel()
        heartbeatJob = scope?.launch {
            while (isActive) {
                delay(AgentConfig.PHOENIX_HEARTBEAT_INTERVAL_MS)
                try {
                    sendPhoenixMessage("phoenix", "heartbeat")
                } catch (_: Exception) {
                    break
                }
            }
        }
    }

    private fun startReceiveLoop() {
        receiveJob?.cancel()
        receiveJob = scope?.launch {
            try {
                val ws = session ?: return@launch
                for (frame in ws.incoming) {
                    if (frame is Frame.Text) {
                        handleMessage(frame.readText())
                    }
                }
            } catch (_: Exception) { }

            // 수신 루프 종료 = 연결 끊김
            _connectionState.value = ConnectionState.DISCONNECTED
            reconnectWithBackoff()
        }
    }

    private fun handleMessage(raw: String) {
        try {
            val arr = json.parseToJsonElement(raw).jsonArray
            val event = arr[3].jsonPrimitive.content
            val payload = arr[4].jsonObject

            if (event == "broadcast") {
                val innerEvent = payload["event"]?.jsonPrimitive?.content
                if (innerEvent == "command") {
                    val cmdPayload = payload["payload"]?.jsonObject ?: return
                    val command = cmdPayload["command"]?.jsonPrimitive?.content ?: return
                    val params = cmdPayload["params"]?.jsonObject ?: buildJsonObject {}
                    commandHandler?.invoke(command, params)
                }
            }
        } catch (_: Exception) {
            // 파싱 실패 무시
        }
    }

    // ─── 재연결 ─────────────────────────────────────────────────────────

    private suspend fun reconnectWithBackoff() {
        val delay = min(
            AgentConfig.RECONNECT_MIN_DELAY_MS * (1L shl reconnectAttempt),
            AgentConfig.RECONNECT_MAX_DELAY_MS,
        )
        reconnectAttempt++
        delay(delay)

        val currentScope = scope ?: return
        try {
            connect(currentScope)
            // 재연결 성공 시 기존 채널 재참여
            rejoinChannels()
        } catch (_: Exception) {
            // 다음 시도는 receiveLoop 종료 시 자동
        }
    }

    private suspend fun rejoinChannels() {
        // 채널 재참여 로직은 connect 호출 측에서 다시 join*() 메서드를 호출하도록
        // 이벤트 기반으로 처리합니다.
    }
}
