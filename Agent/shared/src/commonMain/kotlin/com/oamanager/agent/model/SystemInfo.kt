package com.oamanager.agent.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 시스템 모니터링 수집 항목 (18개 필드).
 *
 * 모든 플랫폼에서 동일한 구조를 사용합니다.
 * JSON 직렬화 시 snake_case 필드명으로 변환됩니다.
 */
@Serializable
data class SystemInfo(
    @SerialName("cpu_usage")            val cpuUsage: Float,
    @SerialName("memory_total_mb")      val memoryTotalMb: Int,
    @SerialName("memory_used_mb")       val memoryUsedMb: Int,
    @SerialName("storage_total_gb")     val storageTotalGb: Float,
    @SerialName("storage_used_gb")      val storageUsedGb: Float,
    @SerialName("battery_level")        val batteryLevel: Int,
    @SerialName("battery_charging")     val batteryCharging: Boolean,
    @SerialName("network_type")         val networkType: String,
    @SerialName("ip_address")           val ipAddress: String,
    @SerialName("os_version")           val osVersion: String,
    @SerialName("uptime_hours")         val uptimeHours: Float,
    @SerialName("os_detail_version")    val osDetailVersion: String,
    @SerialName("device_manufacturer")  val deviceManufacturer: String,
    @SerialName("device_model")         val deviceModel: String,
    @SerialName("device_user")          val deviceUser: String,
    @SerialName("asset_user_name")      val assetUserName: String,
    @SerialName("employee_id")          val employeeId: String,
    @SerialName("agent_version")        val agentVersion: String,
)
