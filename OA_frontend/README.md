# OA Manager v1 Frontend

Flutter + Riverpod + GoRouter 기반의 클라이언트 애플리케이션입니다.

## 현재 버전
- App Version: `1.0.0`

## 기술 스택
- Flutter 3.22+
- Dart 3.4.4+
- Riverpod
- GoRouter
- Supabase Flutter SDK
- mobile_scanner, signature

## 폴더 구조

- `lib/main.dart` : 앱 엔트리(Supabase 초기화)
- `lib/app_router.dart` : 라우팅/인증 가드
- `lib/notifiers/` : 전역 상태(Riverpod Notifier)
- `lib/services/` : API/인증 서비스
- `lib/screens/` : 화면 모음
- `lib/widgets/` : 공통 UI
- `lib/models/` : 타입/엔티티

## 실행/빌드

```bash
cd OA_frontend/oa_app
flutter pub get
flutter run -d chrome
```

지원 환경:
- Android: `flutter run -d <android-device>`
- iOS: `flutter run -d <ios-device>`
- Web: `flutter run -d chrome`

### 릴리스 빌드

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

## 핵심 인증 흐름
- 로컬 로그인: `employeeId + password`
- SNS 로그인: Google/Kakao
- 인증 상태는 `auth_notifier`에서 Supabase Auth state listener로 관리
- `app_router`에서 `go_router`의 `redirect` + `refreshListenable`로 인증 필요 화면 진입시 미인증일 때 `/login`으로 이동
- 라우팅 상 인증 필요 화면(현재 코드 기준): `/asset/new`, `/signature`, `/asset/:id`(숫자형 id)

## 설정/환경
- Supabase 초기화는 `lib/main.dart`에서 수행
- 환경 변수는 Dart 컴파일 타임 변수로 주입:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
- 기본값:
  - `SUPABASE_URL`: `http://localhost:54321`
  - `SUPABASE_ANON_KEY`: 기본 샘플 키(코드 기본값)

실행 예:
`flutter run -d chrome --dart-define=SUPABASE_URL=http://localhost:54321 --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>`

## 백엔드 연동 포인트
- API: Supabase PostgREST + Edge Functions
- 저장소: Supabase Storage

## 테스트

```bash
flutter test
flutter analyze
```

## 버전 관리 규칙(Frontend)
- 버전: `1.0.0`
- 브랜치 기준: `main`, `develop`, `feature/*`
- 버전 증가: SemVer(`MAJOR.MINOR.PATCH`)

### 변경 이력

- `2026-02-17` : 프론트 README 통합 및 실제 코드(라우팅/환경 변수) 기준으로 정합화

