# OA Manager v1

OA 자산 실사 관리 시스템 — 웹/모바일 통합 애플리케이션

## 프로젝트 구조

```
OAmanagerv1/
├── OA_frontend/          # 프론트엔드 (Flutter)
│   └── README.md         # 프론트엔드 명세서
├── OA_backend/           # 백엔드 (Supabase)
│   └── README.md         # 백엔드 명세서
└── README.md             # 본 문서 (프로젝트 개요 + 기본 세팅)
```

## 기술 스택

| 구분 | 기술 | 버전 |
|------|------|------|
| 프론트엔드 | Flutter / Dart | 3.22.x+ / 3.7+ |
| 상태 관리 | Riverpod | ^2.5.0 |
| 라우팅 | GoRouter | ^14.0.0 |
| 백엔드 | Supabase (PostgreSQL 15+) | — |
| 인증 | Supabase Auth (JWT, OAuth 2.0) | — |
| API | PostgREST (자동 REST) | — |
| 서버리스 함수 | Supabase Edge Functions (Deno/TS) | — |
| 파일 저장 | Supabase Storage (S3 호환) | — |
| 실시간 | Supabase Realtime (WebSocket) | — |

## 주요 기능

| 기능 | 설명 |
|------|------|
| 자산 관리 | 자산 등록/수정/삭제, 유형별 사양(JSONB), QR 코드 기반 자산 식별 |
| 자산 실사 | QR 스캔 → 실사 생성, 위치/사진/친필서명 기록, 완료건 관리자 권한 제어 |
| 도면 관리 | 건물/층별 도면 등록, 격자 기반 자산 위치 시각화 |
| 대시보드 | 자산 현황 통계, 만료 임박 자산, 실사 진행률 |
| 인증 | 사번 로그인, 구글/카카오 SNS 로그인, JWT 토큰 관리 |
| 오프라인 | 로컬 저장 후 온라인 복귀 시 동기화 (Server Wins) |

## 기본 세팅

### 1. 사전 요구사항

```bash
# Flutter SDK
flutter --version   # 3.22.x 이상 확인

# Supabase CLI
npm install -g supabase
supabase --version

# Node.js (Edge Functions 배포용)
node --version      # 18.x 이상 권장
```

### 2. Supabase 프로젝트 설정

1. [Supabase Dashboard](https://supabase.com/dashboard)에서 새 프로젝트 생성
   - 리전: `Northeast Asia (ap-northeast-2)` 권장
2. 프로젝트 생성 후 **Settings > API**에서 키 확인

```
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=eyJ...           # 공개 키 (RLS 적용, 클라이언트에서 사용)
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # 서비스 키 (RLS 우회, Edge Function 전용 — 클라이언트 노출 금지)
```

### 3. 백엔드 마이그레이션

```bash
cd OA_backend

# 로컬 개발 환경 시작
supabase init
supabase start

# 마이그레이션 적용 (로컬)
supabase db reset

# 원격 적용
supabase db push

# Edge Functions 배포
supabase functions deploy
```

마이그레이션 파일 순서 및 상세 내용은 **[OA_backend/README.md](OA_backend/README.md) § 12.2** 참고

### 4. Flutter 프로젝트 설정

```bash
cd OA_frontend

# 의존성 설치
flutter pub get

# 환경 변수 설정 (main.dart 내 Supabase.initialize)
# url: SUPABASE_URL
# anonKey: SUPABASE_ANON_KEY
```

```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://<project-id>.supabase.co',
    anonKey: '<SUPABASE_ANON_KEY>',
  );
  runApp(const ProviderScope(child: MyApp()));
}
```

### 5. 실행

```bash
# 웹 (Chrome)
flutter run -d chrome

# Android
flutter run -d <device-id>

# iOS
flutter run -d <device-id>
```

> **참고**: QR 스캔 기능은 **HTTPS 환경에서만** 정상 작동합니다. 로컬 개발 시 `--web-port` + HTTPS 프록시 또는 실제 기기 디버깅을 권장합니다.

### 6. Auth 설정 (Supabase Dashboard)

| 설정 항목 | 값 | 위치 |
|-----------|-----|------|
| Access Token 만료 | 1800초 (30분) | Dashboard > Auth > Settings |
| Refresh Token 만료 | 7일 | Dashboard > Auth > Settings |
| Google OAuth | Client ID/Secret 등록 | Dashboard > Auth > Providers |
| Kakao OAuth | Edge Function으로 처리 | `supabase/functions/auth-kakao/` |

## 명세서 참조

| 문서 | 경로 | 내용 |
|------|------|------|
| **프론트엔드 명세서** | [OA_frontend/README.md](OA_frontend/README.md) | 화면 구성, UI/UX, 상태 관리, 라우팅, 데이터 스키마, API 연동 |
| **백엔드 명세서** | [OA_backend/README.md](OA_backend/README.md) | DB 스키마(DDL), RLS, Storage, API 매핑, Edge Functions, 트리거 |

## DB 스키마 요약

| 테이블 | 설명 | 상세 |
|--------|------|------|
| `users` | 사원 정보 (Supabase Auth 연동) | 백엔드 § 4.2 |
| `assets` | 자산 정보 + specifications JSONB | 백엔드 § 4.3 |
| `asset_inspections` | 실사 기록 (사진/서명/위치) | 백엔드 § 4.5 |
| `drawings` | 도면 정보 (건물/층/격자) | 백엔드 § 4.6 |

### asset_uid 형식
```
[등록경로 1자리][등록장비 2자리][숫자 5자리]
예: BDT00001 (Buy + DeskTop + 00001)
```

| 등록경로 | B(Buy) | R(Rental) | C(Contact) | L(Lease) | S(Spot) |
|---------|--------|-----------|------------|----------|---------|

| 등록장비 | DT(DeskTop) | NB(NoteBook) | MN(MoNitor) | PR(PRinter) | TB(TaBlet) | SC(SCanner) | IP(IP Phone) | NW(NetWork) | SV(SerVer) | WR(Wearable) | SD(SpecialDevice) | SM(SMartphone) |
|---------|-------------|-------------|-------------|-------------|------------|-------------|-------------|-------------|-----------|-------------|-------------------|----------------|

## API 정책 요약

| 구분 | 인증 | 설명 |
|------|------|------|
| `GET` (조회) | 불필요 | RLS `anon + authenticated` 허용 |
| `POST/PUT/DELETE` (등록/수정/삭제) | 필요 | `Authorization: Bearer {token}` 헤더 필수 |
| 실사 완료건 수정 | 관리자만 | JWT `is_admin=true` 클레임 기반 |

## 개발 참고

- **다크 모드**: 기본 ON, Drawer 내 토글로 전환
- **반응형**: 600px 기준으로 모바일(BottomNavigationBar) / 웹(NavigationRail) 전환
- **페이지네이션**: 30건 단위, Range 헤더 기반
- **오프라인**: 로컬 저장 → 온라인 복귀 시 `synced=false` 건 자동 전송
- **파일 저장**: Supabase Storage 3개 버킷 (`inspection-photos`, `inspection-signatures`, `drawing-images`)
