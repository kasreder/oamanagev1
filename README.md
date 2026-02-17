# OA Manager v1

이 저장소는 Flutter 앱(프론트엔드) + Supabase(백엔드)으로 구성된 자산/실사 관리 시스템입니다.

## 폴더 구조

- `OA_frontend/` : Flutter 앱
- `OA_backend/` : Supabase 프로젝트(마이그레이션, Edge Function, SQL)

## 테스트/실행 가이드 (상위 공통)

### 0. 사전 준비
- Flutter 3.22.x+, Dart 3.4.4+
- Node.js 18+
- Supabase CLI
- Docker Desktop (Supabase 로컬 실행)

### 1) 백엔드(로컬) 실행

```bash
cd OA_backend

# Supabase CLI 설치(최초 1회)
npm install -g supabase

# 로컬 Supabase 시작
supabase start

# DB 준비
supabase db reset

# SQL/마이그레이션/함수 반영
supabase db push
supabase functions deploy
```

### 2) 프론트엔드 실행

```bash
cd OA_frontend/oa_app
flutter pub get

# 웹(예시)
flutter run -d chrome

# 런타임 Supabase 주입(권장)
flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>

# Android/iOS 예시
flutter run -d <device-id>
flutter run -d <device-id> --dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>
```

### 3) 기본 동작 체크리스트
- 로그인(로컬/Google/Kakao) 후 홈 화면 진입
- 자산 목록/상세 이동
- QR 스캔 등록 흐름
- 실사/도면/서명 기능 기본 동작

### 4) 테스트/정적 검사

```bash
# 프론트
cd OA_frontend/oa_app
flutter test
flutter analyze

# 백엔드(필요 시)
cd OA_backend
supabase functions serve
```

## 문서 체계
- `OA_frontend/README.md` : 프론트엔드 실행/개발 가이드
- `OA_backend/README.md` : 백엔드(Supabase) 실행/운영 가이드

## Supabase 환경 변수 주입
- `OA_frontend/oa_app/lib/main.dart`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`는 `String.fromEnvironment`로 읽습니다.
- 미지정 시 다음 기본값이 사용됩니다.
  - `SUPABASE_URL`: `http://localhost:54321`
  - `SUPABASE_ANON_KEY`: 샘플 키
- 로컬/CI에서는 `--dart-define`로 동일 키를 주입해 실행하세요.

## 버전 관리

- 버전: `v1.0.0`
- 버전 규칙: [SemVer](https://semver.org/) (`MAJOR.MINOR.PATCH`)
- 릴리스 기준: 기능 추가/호환성 변경은 MINOR, 버그 수정은 PATCH, 구조 변경은 MAJOR
- 변경 이력: 이 파일의 하단에 날짜 기준 기록을 남깁니다.

### 변경 이력

- `2026-02-17` : README 통합 정비(테스트/실행 가이드 중심으로 정리), 코드 기준 버전/환경 변수/인증 예시 정합화

