# Agent — Claude Code 가이드

상세 명세: `Agent/README.md` · 빌드 입력: `Agent/BUILDING.md` · 문서 인덱스: 루트 `CLAUDE.md`

모듈: `shared`(KMP 공용) · `android:app` · `windows` · `macos`.

## 현재 상태

서버가 에이전트 RPC(`update_heartbeat`, `verify_user`, `confirm_assignment`) 실행 권한을 회수한 상태다. 데이터 갱신은 실패하는 것이 정상이며, 재도입 조건은 `Agent/README.md` §15. 서버 권한을 완화해서 우회하지 않는다.

## 작업 규칙

- 공용 서비스 계정·비밀번호를 코드에 넣지 않는다. 인증은 자산 담당자·관리자 개인 계정, 토큰만 플랫폼 보안 저장소(Android Keystore / DPAPI / Keychain)에 저장.
- Supabase URL·anon key는 빌드 시 `OA_AGENT_SUPABASE_URL` / `OA_AGENT_SUPABASE_ANON_KEY`로만 주입 (`GeneratedAgentRuntimeConfig`). `AgentConfig.kt`에 하드코딩 금지.
- 릴리스 서명은 `OA_AGENT_SIGNING_*` 4개 값으로만. 키스토어(`*.jks`)는 커밋 금지 (현재 키는 git 이력 노출 → 교체 필요).
- Realtime 조인은 `private: true`. Presence payload는 `asset_uid`만, 전역 알림(`agent-alerts:global`) 발신 금지.
- `SystemInfo` 필드(현재 26개)를 바꾸면 세 플랫폼 수집기와 `Agent/README.md` §3.2를 함께 갱신.
