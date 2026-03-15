package com.oamanager.agent.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Supabase Auth 응답 모델.
 */
@Serializable
data class AuthResponse(
    @SerialName("access_token")  val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String,
    @SerialName("expires_in")    val expiresIn: Long,
    @SerialName("token_type")    val tokenType: String = "bearer",
)

/**
 * 토큰 저장소 인터페이스.
 *
 * 플랫폼별(Android: EncryptedSharedPreferences 등) 구현을 주입받습니다.
 */
interface TokenStorage {
    var accessToken: String?
    var refreshToken: String?
}

/**
 * 인증 토큰 관리.
 *
 * - access_token 유효 → 그대로 반환
 * - access_token 만료 → refresh_token으로 갱신
 * - 둘 다 실패 → email/password 재로그인
 */
class AuthManager(
    private val client: SupabaseClient,
    private val storage: TokenStorage,
) {
    /** access_token 만료 시각 (epoch millis) */
    private var tokenExpiresAt: Long = 0L

    /**
     * 유효한 access_token을 반환합니다.
     * 만료되었으면 자동 갱신을 시도합니다.
     *
     * @return 유효한 access_token, 또는 모든 갱신 실패 시 null
     */
    suspend fun getValidToken(): String? {
        // 1) 기존 토큰이 유효하면 반환
        val current = storage.accessToken
        if (current != null && System.currentTimeMillis() < tokenExpiresAt) {
            return current
        }

        // 2) refresh_token으로 갱신 시도
        val refresh = storage.refreshToken
        if (refresh != null) {
            try {
                val response = client.refreshToken(refresh)
                saveTokens(response)
                return response.accessToken
            } catch (_: Exception) {
                // refresh 실패 → 재로그인
            }
        }

        // 3) email/password 재로그인
        return try {
            val response = client.signIn(
                com.oamanager.agent.AgentConfig.AGENT_EMAIL,
                com.oamanager.agent.AgentConfig.AGENT_PASSWORD,
            )
            saveTokens(response)
            response.accessToken
        } catch (_: Exception) {
            null
        }
    }

    private fun saveTokens(response: AuthResponse) {
        storage.accessToken = response.accessToken
        storage.refreshToken = response.refreshToken
        tokenExpiresAt = System.currentTimeMillis() + (response.expiresIn * 1000L) - 60_000L
    }
}
