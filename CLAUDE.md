# OA Manager v1 — Claude Code 가이드

## 문서 인덱스 (모든 문서 경로)

| 경로 | 역할 | 언제 읽나 |
|------|------|-----------|
| `CLAUDE.md` | 이 파일 — 문서 인덱스 + 공통 규칙 | 항상 (자동 로드) |
| `OA_backend/CLAUDE.md` | 백엔드 작업 규칙 (마이그레이션·RLS·RPC) | `OA_backend/` 작업 시 (자동 로드) |
| `OA_frontend/CLAUDE.md` | 프론트 작업 규칙 (Flutter) | `OA_frontend/` 작업 시 (자동 로드) |
| `Agent/CLAUDE.md` | 에이전트 작업 규칙 (KMP) | `Agent/` 작업 시 (자동 로드) |
| `OA_backend/SECURITY_HARDENING_RUNBOOK.md` | **보안 실행서 — 권한·정책의 최우선 기준** | 권한·RLS·계정·에이전트 인증을 건드릴 때 |
| `README.md` | 전체 개요, 구현 현황, 운영 절차, **알려진 이슈 표** | 현황·이슈 파악 |
| `OA_backend/README.md` | 백엔드 명세 — 스키마(§4), RLS 최종 상태(§5, §5.0 라이브 적용 표), Storage(§6), Edge Function(§8), RPC(§9), Realtime(§10), 마이그레이션 목록(§12.2) | DB·API 상세 |
| `OA_frontend/README.md` | 프론트 명세 — 기능(§4), 화면·메뉴(§5), API(§7), 모델(§8), 라우팅(§10) | 화면·흐름 상세 |
| `Agent/README.md` | 에이전트 명세 — 프로토콜(§3~5), 플랫폼(§6~7), 알림(§10), Realtime(§14), 재도입 설계(§15) | 에이전트 상세 |
| `Agent/BUILDING.md` | 에이전트 빌드 입력값(URL·anon key) 주입 규칙 | 에이전트 빌드 |
| `docs/asset_uid_spec.md` | 자산번호 규격 (두 형식 병행) | 자산번호 관련 |
| `docs/software_inventory_spec.md` | 자산별 설치 SW 계획 (**미구현, 계획 확정** — Windows·macOS·Linux·Android, 1단계 스크립트 → 2단계 에이전트) | 해당 기능 착수 시 |

명세와 코드가 다르면 **코드·마이그레이션이 우선**이고, 문서를 고친다. 권한 관련은 보안 실행서가 문서들보다 우선한다.

## 구조

- `OA_frontend/oa_app/` — Flutter 웹/모바일 앱 (Riverpod, GoRouter, supabase_flutter)
- `OA_backend/supabase/` — self-hosted Supabase: `migrations/`(SoT), `functions/`(Edge), `seed.sql`
- `Agent/` — 기기 에이전트 (Android / Windows / macOS)
- `docker-compose.yml`, `volumes/` — 라이브 서버 구성 (컨테이너 `oa-*`)

## 명령어

```bash
# 프론트 정적 검사 (OA_frontend/oa_app)
flutter analyze

# 웹 재배포 — 서비스명은 oa-frontend (frontend 아님). DB·Kong은 재생성 안 됨
docker compose up -d --dry-run --no-build oa-frontend   # 사전 확인
docker compose build oa-frontend && docker compose up -d oa-frontend

# DB 마이그레이션 적용 — supabase db push 불가 (마이그레이션 이력 테이블 없음)
docker exec -i oa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < OA_backend/supabase/migrations/<파일>.sql
# 리허설: 파일의 COMMIT; 을 ROLLBACK; 으로 바꿔 먼저 실행
```

## 공통 규칙

- **운영 DB·배포는 사용자 승인 후에만.** 라이브 서버가 곧 운영이다. 읽기 전용 조회는 자유.
- **시크릿 금지**: `.env`, `*.jks`, 비밀번호를 커밋·출력·문서화하지 않는다. 값은 `.env` 경로만 참조.
- **자산번호 정규식은 3곳 동기화**: DB CHECK + `validate_asset_uid()` 트리거, `OA_frontend/oa_app/lib/constants.dart` `assetUidRegex`, `docs/asset_uid_spec.md`.
  `^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$`
- **익명 접근 없음**: anon으로 열리는 테이블·RPC·버킷을 만들지 않는다.
- **에이전트 RPC**(`update_heartbeat`, `verify_user`, `confirm_assignment`)에 `authenticated` GRANT를 되살리지 않는다 — 기기별 신원 재도입(`Agent/README.md` §15) 전까지 의도된 차단.
- **화면 검증**: 호스트 `google-chrome` + `playwright-core`(scratchpad 설치)로 임시 관리자 계정을 만들어 확인하고, 끝나면 계정과 비밀번호 파일을 반드시 삭제.

## 운영 결정 (재론하지 말 것)

- 시드 계정 `admin01` / `oper01` / `user01`의 차단 해제·사용은 운영자가 **의도한 것**.
- 알림은 Edge Function `send-notification`이 아니라 RPC(`admin_force_verify`, `request_inspection_recheck`)나 `notifications` 직접 INSERT로 보낸다.

## 미해결 이슈

전체 목록은 `README.md` "알려진 이슈 / 결정 사항" 표. 요약: 서명키(`oaagent-release.jks`)가 원격 이력에 있어 에이전트 재배포 시 교체 필요, 계정 RPC가 마스터→admin으로 완화, 에이전트 재도입(§15) 보류 중.

**라이브 DB가 저장소보다 앞설 수 있다** — 정책·제약은 마이그레이션 파일만 보지 말고 라이브를 읽기 전용으로 조회해 확인할 것.
