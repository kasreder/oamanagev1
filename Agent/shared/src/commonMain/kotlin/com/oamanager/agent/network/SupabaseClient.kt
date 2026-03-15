package com.oamanager.agent.network

import com.oamanager.agent.model.HeartbeatPayload
import com.oamanager.agent.model.SystemInfo
import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

/**
 * Ktor 기반 Supabase HTTP 클라이언트.
 *
 * KMP shared 모듈의 commonMain에 위치하며, 플랫폼별 엔진은
 * androidMain(OkHttp), iosMain(Darwin) 등에서 주입합니다.
 */
class SupabaseClient(
    private val supabaseUrl: String,
    private val anonKey: String,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val client = HttpClient {
        install(ContentNegotiation) {
            json(this@SupabaseClient.json)
        }
    }

    // ─── Auth ───────────────────────────────────────────────────────────────

    /**
     * 이메일/비밀번호 로그인.
     */
    suspend fun signIn(email: String, password: String): AuthResponse {
        val response: HttpResponse = client.post("$supabaseUrl/auth/v1/token?grant_type=password") {
            header("apikey", anonKey)
            contentType(ContentType.Application.Json)
            setBody(mapOf("email" to email, "password" to password))
        }
        check(response.status == HttpStatusCode.OK) {
            "Login failed: ${response.status}"
        }
        return response.body()
    }

    /**
     * refresh_token으로 토큰 갱신.
     */
    suspend fun refreshToken(refreshToken: String): AuthResponse {
        val response: HttpResponse =
            client.post("$supabaseUrl/auth/v1/token?grant_type=refresh_token") {
                header("apikey", anonKey)
                contentType(ContentType.Application.Json)
                setBody(mapOf("refresh_token" to refreshToken))
            }
        check(response.status == HttpStatusCode.OK) {
            "Token refresh failed: ${response.status}"
        }
        return response.body()
    }

    // ─── Heartbeat ──────────────────────────────────────────────────────────

    /**
     * Heartbeat 전송 (update_heartbeat RPC 호출).
     */
    suspend fun updateHeartbeat(
        accessToken: String,
        assetUid: String,
        systemInfo: SystemInfo,
    ) {
        val payload = HeartbeatPayload(assetUid, systemInfo)
        val response: HttpResponse =
            client.post("$supabaseUrl/rest/v1/rpc/update_heartbeat") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(payload)
            }
        if (response.status == HttpStatusCode.Unauthorized) {
            throw UnauthorizedException()
        }
        check(response.status == HttpStatusCode.OK) {
            "Heartbeat failed: ${response.status} ${response.bodyAsText()}"
        }
    }

    // ─── User Verification ──────────────────────────────────────────────────

    /**
     * 사용자 확인 (verify_user RPC 호출).
     *
     * @return RPC 반환 jsonb (matched, message, verified_at)
     */
    suspend fun verifyUser(
        accessToken: String,
        assetUid: String,
        userName: String,
        employeeId: String,
    ): JsonObject {
        val response: HttpResponse =
            client.post("$supabaseUrl/rest/v1/rpc/verify_user") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(
                    mapOf(
                        "p_asset_uid" to assetUid,
                        "p_user_name" to userName,
                        "p_employee_id" to employeeId,
                    )
                )
            }
        check(response.status == HttpStatusCode.OK) {
            "verify_user failed: ${response.status}"
        }
        return json.parseToJsonElement(response.bodyAsText()).jsonObject
    }

    // ─── Assignment Confirmation ────────────────────────────────────────────

    /**
     * 자산 수령 확인 (confirm_assignment RPC 호출).
     *
     * @return RPC 반환 jsonb (success, message, confirmed_at)
     */
    suspend fun confirmAssignment(
        accessToken: String,
        assetUid: String,
        userName: String,
    ): JsonObject {
        val response: HttpResponse =
            client.post("$supabaseUrl/rest/v1/rpc/confirm_assignment") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                contentType(ContentType.Application.Json)
                setBody(
                    mapOf(
                        "p_asset_uid" to assetUid,
                        "p_user_name" to userName,
                    )
                )
            }
        check(response.status == HttpStatusCode.OK) {
            "confirm_assignment failed: ${response.status}"
        }
        return json.parseToJsonElement(response.bodyAsText()).jsonObject
    }

    // ─── Agent Settings ─────────────────────────────────────────────────────

    /**
     * agent_settings 테이블에서 설정 조회.
     *
     * @return key → value 맵 (예: latest_agent_version → "1.0.0")
     */
    suspend fun getAgentSettings(accessToken: String): Map<String, String> {
        val response: HttpResponse =
            client.get("$supabaseUrl/rest/v1/agent_settings") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                parameter(
                    "setting_key",
                    "in.(latest_agent_version,min_agent_version,agent_download_url)"
                )
                parameter("select", "setting_key,setting_value")
            }
        check(response.status == HttpStatusCode.OK) {
            "getAgentSettings failed: ${response.status}"
        }
        val arr = json.parseToJsonElement(response.bodyAsText()).jsonArray
        return arr.associate { elem ->
            val obj = elem.jsonObject
            obj["setting_key"]!!.jsonPrimitive.content to
                obj["setting_value"]!!.jsonPrimitive.content
        }
    }

    // ─── FCM Token ──────────────────────────────────────────────────────────

    /**
     * FCM 토큰 등록/갱신 (device_tokens upsert).
     */
    suspend fun upsertDeviceToken(
        accessToken: String,
        assetUid: String,
        fcmToken: String,
        platform: String = "android",
    ) {
        val response: HttpResponse =
            client.post("$supabaseUrl/rest/v1/device_tokens") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                header("Prefer", "resolution=merge-duplicates")
                contentType(ContentType.Application.Json)
                setBody(
                    mapOf(
                        "asset_uid" to assetUid,
                        "fcm_token" to fcmToken,
                        "platform" to platform,
                    )
                )
            }
        check(response.status.value in 200..299) {
            "upsertDeviceToken failed: ${response.status}"
        }
    }

    // ─── Asset Query ────────────────────────────────────────────────────────

    /**
     * 특정 자산의 assignment_status, user_name 조회.
     */
    suspend fun getAssetAssignment(
        accessToken: String,
        assetUid: String,
    ): JsonObject? {
        val response: HttpResponse =
            client.get("$supabaseUrl/rest/v1/assets") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                parameter("asset_uid", "eq.$assetUid")
                parameter("select", "assignment_status,user_name")
            }
        check(response.status == HttpStatusCode.OK) {
            "getAssetAssignment failed: ${response.status}"
        }
        val arr = json.parseToJsonElement(response.bodyAsText()).jsonArray
        return arr.firstOrNull()?.jsonObject
    }

    // ─── Access Settings ────────────────────────────────────────────────────

    /**
     * access_settings에서 verification_interval_days 조회.
     */
    suspend fun getVerificationIntervalDays(accessToken: String): Int {
        val response: HttpResponse =
            client.get("$supabaseUrl/rest/v1/access_settings") {
                header("apikey", anonKey)
                header("Authorization", "Bearer $accessToken")
                parameter("setting_key", "eq.verification_interval_days")
                parameter("select", "setting_value")
            }
        check(response.status == HttpStatusCode.OK) {
            "getVerificationIntervalDays failed: ${response.status}"
        }
        val arr = json.parseToJsonElement(response.bodyAsText()).jsonArray
        return arr.firstOrNull()
            ?.jsonObject?.get("setting_value")
            ?.jsonPrimitive?.content?.toIntOrNull()
            ?: 30
    }

    fun close() {
        client.close()
    }
}

class UnauthorizedException : Exception("Unauthorized (401)")
