package com.oamanager.agent

/**
 * 에이전트 공통 설정.
 *
 * Supabase endpoint와 anon key는 Gradle이 빌드 시 생성하는
 * [GeneratedAgentRuntimeConfig]에서만 가져온다. 서비스 계정 자격증명은
 * 클라이언트에 절대 포함하지 않는다.
 */
object AgentConfig {
    /** Supabase 프로젝트 URL */
    val SUPABASE_URL: String
        get() = GeneratedAgentRuntimeConfig.SUPABASE_URL

    /** Supabase Anon Key (공개 가능 — RLS로 보호) */
    val SUPABASE_ANON_KEY: String
        get() = GeneratedAgentRuntimeConfig.SUPABASE_ANON_KEY

    /** 기본 Heartbeat 전송 주기 (분) — 서버 agent_settings에서 동적으로 변경 가능 */
    const val DEFAULT_INTERVAL_MINUTES: Int = 5

    /** Supabase Realtime WebSocket URL */
    val REALTIME_URL: String
        get() = SUPABASE_URL
            .replace("https://", "wss://")
            .plus("/realtime/v1/websocket?apikey=$SUPABASE_ANON_KEY")

    /** Phoenix Heartbeat 간격 (밀리초) */
    const val PHOENIX_HEARTBEAT_INTERVAL_MS: Long = 30_000L

    /** WebSocket 재연결 최소 대기 (밀리초) */
    const val RECONNECT_MIN_DELAY_MS: Long = 5_000L

    /** WebSocket 재연결 최대 대기 (밀리초) */
    const val RECONNECT_MAX_DELAY_MS: Long = 60_000L

    /** asset_uid 정규식 패턴 */
    val ASSET_UID_REGEX = Regex("^[A-Za-z0-9_-]+$")
}
