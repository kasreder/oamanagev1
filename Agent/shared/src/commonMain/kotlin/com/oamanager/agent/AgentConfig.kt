package com.oamanager.agent

/**
 * 에이전트 공통 설정.
 *
 * 실제 빌드 시 BuildConfig 또는 환경변수로 주입할 수 있습니다.
 * 여기서는 기본값을 정의합니다.
 */
object AgentConfig {
    /** Supabase 프로젝트 URL (예: https://<project-id>.supabase.co) */
    const val SUPABASE_URL: String = "https://YOUR_PROJECT.supabase.co"

    /** Supabase Anon Key (공개 가능 — RLS로 보호) */
    const val SUPABASE_ANON_KEY: String = "YOUR_ANON_KEY"

    /** 에이전트 전용 서비스 계정 이메일 */
    const val AGENT_EMAIL: String = "agent@oamanager.internal"

    /** 에이전트 전용 서비스 계정 비밀번호 */
    const val AGENT_PASSWORD: String = "AGENT_PASSWORD"

    /** 기본 Heartbeat 전송 주기 (분) */
    const val DEFAULT_INTERVAL_MINUTES: Int = 15

    /** Supabase Realtime WebSocket URL */
    val REALTIME_URL: String
        get() = SUPABASE_URL
            .replace("https://", "wss://")
            .plus("/realtime/v1/websocket?apikey=$SUPABASE_ANON_KEY&vsn=1.0.0")

    /** Phoenix Heartbeat 간격 (밀리초) */
    const val PHOENIX_HEARTBEAT_INTERVAL_MS: Long = 30_000L

    /** WebSocket 재연결 최소 대기 (밀리초) */
    const val RECONNECT_MIN_DELAY_MS: Long = 5_000L

    /** WebSocket 재연결 최대 대기 (밀리초) */
    const val RECONNECT_MAX_DELAY_MS: Long = 60_000L

    /** asset_uid 정규식 패턴 */
    val ASSET_UID_REGEX = Regex("^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$")
}
