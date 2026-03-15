package com.oamanager.agent.platform

import com.oamanager.agent.model.SystemInfo

/**
 * 시스템 정보 수집기 (expect 선언).
 *
 * 각 플랫폼의 actual 구현에서 18개 필드를 수집합니다.
 */
expect class SystemInfoCollector {
    suspend fun collect(): SystemInfo
}
