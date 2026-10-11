# OA_backend — Claude Code 가이드

상세 명세: `OA_backend/README.md` · 권한 기준: `OA_backend/SECURITY_HARDENING_RUNBOOK.md` · 문서 인덱스: 루트 `CLAUDE.md`

## 마이그레이션 작성 규칙

- 파일명 `supabase/migrations/YYYYMMDDHHMMSS_<설명>.sql`, 내용은 `BEGIN; … COMMIT;`으로 감싼다.
- 추가 후 `README.md` §12.2 목록과 §5.0 적용 상태 표, 루트 `README.md` 건수를 갱신한다.
- **기본 ACL이 회수돼 있다** — 새 테이블·시퀀스·함수는 필요한 역할에 **명시적 GRANT**를 넣어야 PostgREST에서 보인다.
- 새 테이블은 RLS를 켜고, `auth_banned_account_block`·`legacy_agent_block` RESTRICTIVE 정책 대상에도 추가한다.
- `SECURITY DEFINER` 함수는 `SET search_path = pg_catalog, public, auth, pg_temp`를 고정하고, 함수 안에서 호출자 권한(`is_admin()` 등)을 다시 검사한다.
- 기존 함수를 고칠 때는 라이브 정의를 기준으로 한다: `SELECT pg_get_functiondef('public.<fn>(<args>)'::regprocedure)` → 최소 수정 → diff 확인.
- `auth.users`에 직접 INSERT할 때 `confirmation_token`, `recovery_token`, `email_change_token_new`, `email_change`는 `''`로 채운다 (NULL이면 GoTrue 로그인 500).

## 적용 절차

1. 리허설: `sed 's/^COMMIT;$/ROLLBACK;/' <파일> | docker exec -i oa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1`
2. 사용자 승인 후 실제 적용 (루트 `CLAUDE.md` 명령)
3. 읽기 전용 조회로 결과 검증, 권한은 `SET LOCAL ROLE authenticated` + `request.jwt.claims`로 계정별 시뮬레이션 (롤백 트랜잭션)

## 권한 모델 요약

- 역할: `admin` / `operator1` / `operator2` (= 관리자 그룹) / `user`, 마스터 관리자 최대 4명
- 조회: 관리자 그룹 전체, 일반 사용자는 본인 배정 자산(`assets.user_id`)·참여 실사만
- 변경: 자산·도면·라운드는 관리자 그룹, 실사 수정·초기화·삭제와 라운드 재오픈·삭제는 admin
- Storage: 전 버킷 private, 사진·서명 경로 첫 폴더는 업로더 Auth UUID
- Realtime: 전 채널 private, 토픽별 정책은 `20260817000001`
