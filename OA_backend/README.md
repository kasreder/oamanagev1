# OA Manager v1 Backend

Supabase(PostgreSQL, Auth, Edge Functions, Storage, Realtime) 기반 백엔드 구성입니다.

## 현재 버전
- Backend Version: `1.0.0`

## 기술 스택
- Supabase 2.x
- PostgreSQL 15+
- PostgREST
- Supabase Edge Functions (TypeScript/Deno)
- RLS + Realtime

## 폴더 구조

- `supabase/`
  - `migrations/` : DB 스키마/정책 SQL
  - `seed.sql` : 초기 데이터
  - `functions/` : Edge Function
    - `auth-kakao/`
    - `dashboard-stats/`
    - `expiring-assets/`
  - `config.toml`
- `README.md` : 현재 파일(백엔드 운영/개발 문서)

## 로컬 실행 (필수 순서)

```bash
cd OA_backend

# 설치/준비
npm install -g supabase

# 로컬 프로젝트 초기화(이미 했으면 생략)
supabase init

# 로컬 DB/Storage/Functions 시작
supabase start

# DB 마이그레이션 반영
supabase db reset
supabase db push

# 함수 배포(로컬)
supabase functions deploy
```

## 인증 테스트

### 로컬 계정 테스트
- seed 기준 계정으로 로그인 후 발급받은 사용자 access token을 사용해 API 호출
- 사용자 JWT는 `Authorization: Bearer <access_token>` 형식

### SNS(예시)
- Google/Kakao 인증은 Provider 설정 후 OAuth 리디렉션 동작 확인

## 자주 쓰는 SQL/함수 명령

```bash
# 사용자/권한 관련 뷰/함수 확인
supabase db remote commit

# SQL 점검 예시
supabase migration list

# 스키마/함수 점검
supabase db diff
```

> 참고: 실제 운영에 반영 전에는 `supabase db diff` 또는 migration 리뷰를 통해 스키마 변경사항을 확인합니다.

## 배포 워크플로우

```bash
# 운영 반영
supabase db push
supabase functions deploy
```

## 테스트

```bash
# 로컬 함수 실행
supabase functions serve

# API/DB 확인은 Postman 또는 curl
curl -X GET http://localhost:54321/rest/v1/assets \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN"
```

## 버전 관리 규칙(Backend)

- 버전: `1.0.0`
- SemVer 기준(`MAJOR.MINOR.PATCH`)
- 변경 전후의 migration은 반드시 `supabase/migrations`에 반영
- 함수 변경은 `supabase/functions/*/index.ts` 버전 확인

### 변경 이력

- `2026-02-17` : 백엔드 README 정합화(커먼 seed 경로, REST 인증 헤더를 사용자 JWT 기준으로 통일)

