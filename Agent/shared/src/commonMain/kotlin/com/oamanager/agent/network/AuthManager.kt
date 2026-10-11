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
 * - 둘 다 실패 → 사용자에게 다시 로그인을 요청
 *
 * 공용 서비스 계정은 사용하지 않는다. 각 설치본은 자산 담당자 또는 관리자
 * 개인 OA 계정으로 명시적으로 로그인해야 하며, 토큰 갱신에 실패해도 APK에
 * 포함된 자격증명으로 자동 재로그인하지 않는다.
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

        // 3) 자격증명 자동 재로그인은 금지한다. UI에서 명시적으로 로그인해야 한다.
        return null
    }

    /**
     * 자산 담당자 또는 관리자 OA 계정으로 명시적으로 로그인한다.
     *
     * 비밀번호는 호출 중에만 사용하며 저장하지 않는다. 성공 시 Supabase 세션의
     * access/refresh token만 [TokenStorage]에 저장한다.
     */
    suspend fun signInWithPassword(email: String, password: String): Boolean {
        val normalizedEmail = email.trim()
        if (normalizedEmail.isEmpty() || password.isEmpty()) return false

        return try {
            val response = client.signIn(normalizedEmail, password)
            saveTokens(response)
            true
        } catch (_: Exception) {
            false
        }
    }

    /**
     * 저장된 세션이 있는지 확인한다. 실제 유효성은 [getValidToken]이 갱신 시점에
     * 검증하므로, 이 값은 UI에서 로그인 필요 여부를 표시하는 용도로만 사용한다.
     */
    fun hasStoredSession(): Boolean =
        storage.accessToken != null || storage.refreshToken != null

    private fun saveTokens(response: AuthResponse) {
        storage.accessToken = response.accessToken
        storage.refreshToken = response.refreshToken
        tokenExpiresAt = System.currentTimeMillis() + (response.expiresIn * 1000L) - 60_000L
    }
}
