package com.oamanager.agent.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Heartbeat 전송 페이로드.
 *
 * `update_heartbeat` RPC 호출 시 JSON body로 사용됩니다.
 */
@Serializable
data class HeartbeatPayload(
    @SerialName("p_asset_uid")   val assetUid: String,
    @SerialName("p_system_info") val systemInfo: SystemInfo,
)
