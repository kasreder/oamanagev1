package com.oamanager.agent.android.service

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/**
 * 관리자(웹)에서 발생한 명령에 대한 단말 측 처리 이벤트를 SetupActivity에 알리기 위한
 * 정적 SharedFlow 허브. ForegroundService와 Activity가 같은 프로세스에 있을 때 사용.
 */
object AdminCommandEvents {
    sealed class Event {
        object HeartbeatAck : Event()  // 즉시 Heartbeat / 시스템 정보 갱신 완료
    }

    private val _events = MutableSharedFlow<Event>(replay = 0, extraBufferCapacity = 8)
    val events: SharedFlow<Event> = _events.asSharedFlow()

    fun tryEmit(e: Event): Boolean = _events.tryEmit(e)
}
