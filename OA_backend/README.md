# OA Manager v1 - 백엔드 명세서 (Supabase)

## ⚠️ 중요 사항
> **본 문서는 OA 자산관리 시스템의 백엔드(Supabase) 개발 명세서입니다.**
> **프론트엔드 명세서(`OA_frontend/README.md`)와 반드시 동기화하여 관리합니다.**
> **DB 스키마 및 API 변경 시 프론트엔드팀과 사전 협의가 필요합니다.**

### 예제 코드 정책 (Example Code Policy)

| 구분 | 구속력 | 설명 |
|------|--------|------|
| SQL DDL / RLS 정책 | **고정** | 테이블 구조, 컬럼, 보안 정책은 반드시 준수 |
| Edge Function 시그니처 | **고정** | 함수명, 파라미터, 반환 형식은 반드시 준수 |
| 예제 코드 (SQL 쿼리, Dart 클라이언트 코드) | **변경 가능** | 동일한 기능을 수행하는 다른 구현도 허용 |
| 내부 구현 로직 | **구현자 재량** | 동일한 입출력을 보장하는 범위 내에서 자유롭게 구현 |

---

## 1. 프로젝트 개요

### 1.1 목적
OA 자산의 효율적인 관리 및 실사를 위한 웹/모바일 통합 애플리케이션의 **백엔드 시스템** 구축

### 1.2 주요 기능 (백엔드 관점)
| 기능 | 설명 |
|------|------|
| 인증/인가 | JWT 기반 인증, SNS 로그인 (카카오/구글), 역할 기반 RLS (admin/operator1/operator2/user) |
| 자산 CRUD | 자산 등록/조회/수정/삭제, 유형별 specifications JSONB 관리 |
| 실사 관리 | 실사 기록 CRUD, 전사 실사 라운드(차수) 관리, 사진/서명 파일 저장 |
| 도면 관리 | 도면 이미지 업로드/조회, 격자 좌표 기반 자산 위치 관리 |
| 대시보드 통계 | 자산 현황 집계, 만료 임박 자산 조회, 실사 진행률 |
| 오프라인 동기화 | synced 필드 기반 동기화 상태 관리, 충돌 해결 (Server Wins) |

### 1.3 기술 스택
| 구분 | 기술 |
|------|------|
| BaaS | **Supabase** (PostgreSQL 17) |
| 인증 | Supabase Auth (JWT, OAuth 2.0) |
| API | PostgREST (자동 생성 REST API) |
| 서버리스 함수 | Supabase Edge Functions (Deno/TypeScript) |
| 파일 저장 | Supabase Storage (S3 호환) |
| 실시간 | Supabase Realtime (WebSocket) |
| CLI | Supabase CLI (마이그레이션, 로컬 개발) |

### 1.4 시스템 아키텍처
```
┌─────────────────────────────────────────────────┐
│                Flutter App (Client)              │
│  supabase_flutter SDK                           │
└──────┬──────────┬──────────┬──────────┬─────────┘
       │          │          │          │
       ▼          ▼          ▼          ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────┐
│ Supabase ││PostgREST ││ Storage  ││ Realtime │
│   Auth   ││  (API)   ││ (Files)  ││(WebSocket│
└──────────┘└──────────┘└──────────┘└──────────┘
       │          │          │          │
       ▼          ▼          ▼          ▼
┌─────────────────────────────────────────────────┐
│              PostgreSQL Database                 │
│  Tables + RLS + Functions + Triggers             │
└─────────────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────────┐
│           Edge Functions (Deno)                  │
│  SNS 로그인 검증, 통계 집계, 비즈니스 로직        │
└─────────────────────────────────────────────────┘
```

---

## 2. Supabase 프로젝트 설정

### 2.1 프로젝트 생성
1. [Supabase Dashboard](https://supabase.com/dashboard) 접속
2. "New Project" 생성
3. 리전: **Northeast Asia (ap-northeast-2)** 권장
4. 데이터베이스 비밀번호 설정 (안전한 곳에 보관)

### 2.2 환경 변수
```env
# .env (프론트엔드 + 백엔드 공통)
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIs...        # 공개 키 (RLS 적용)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIs... # 서비스 키 (RLS 우회, 서버 전용)
```

> **보안**: `SUPABASE_SERVICE_ROLE_KEY`는 절대 클라이언트에 노출하지 않습니다. Edge Function 내부에서만 사용합니다.

### 2.3 Flutter 클라이언트 설정
```dart
// main.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  await Supabase.initialize(
    url: 'https://<project-id>.supabase.co',
    anonKey: '<SUPABASE_ANON_KEY>',
  );
  runApp(const ProviderScope(child: MyApp()));
}

final supabase = Supabase.instance.client;
```

### 2.4 Supabase CLI 설정
```bash
# CLI 설치
npm install -g supabase

# 프로젝트 초기화
supabase init

# 로컬 개발 환경 시작
supabase start

# 마이그레이션 생성
supabase migration new create_tables

# 마이그레이션 적용 (로컬)
supabase db reset

# 원격 적용
supabase db push
```

### 2.5 마이그레이션 파일 목록
전체 목록(60건)과 역할은 12.2를 참고합니다. `OA_backend/supabase/migrations/`가 소스 오브 트루스입니다.

```bash
# 로컬 반영
supabase db reset

# 원격 반영
supabase db push
```

```sql
-- 배포 후 asset_uid 형식 점검 (현재기준 + 변경후 두 형식 허용)
SELECT id, asset_uid
FROM public.assets
WHERE asset_uid !~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$';
```

> **보안 마이그레이션 적용 절차**: `20260816000000_security_hardening.sql` 이후 보안 마이그레이션은 `SECURITY_HARDENING_RUNBOOK.md` 순서대로 적용합니다.

---

## 3. 인증 (Authentication)

### 3.1 인증 방식
Supabase Auth 내장 JWT 기반 인증을 사용합니다.

| 항목 | 설명 |
|------|------|
| 인증 방식 | JWT (JSON Web Token) — Supabase Auth 자동 관리 |
| 일반 로그인 | 사번(employee_id) + 비밀번호 → `signInWithPassword()` |
| SNS 로그인 | 카카오 OAuth, 구글 OAuth → `signInWithOAuth()` |
| Access Token 만료 | 3600초 (1시간, config.toml `jwt_expiry` 기준) |
| Refresh Token 만료 | 7일 |
| 토큰 자동 갱신 | `supabase_flutter` SDK 자동 처리 |

### 3.1.1 계정 프로비저닝

`supabase db reset`은 Auth 계정이나 기본 비밀번호를 생성하지 않습니다. 초기 master
관리자는 통제된 운영 절차로 생성하고, 이후 계정은 보안 관리자 RPC로 발급합니다.
서버가 생성한 임시 비밀번호는 안전한 별도 채널로만 전달합니다.

로그인 이메일은 `{사번}@oamanager.internal` 형식으로 내부 변환됩니다.

### 3.2 일반 로그인 (사번 + 비밀번호)

Supabase Auth는 기본적으로 이메일 로그인을 사용합니다. 사번 기반 로그인을 구현하기 위해 **사번을 이메일 형태로 변환**합니다.

```
사번: employee-id-example → 이메일: employee-id-example@oamanager.internal
```

#### 회원가입 (관리자 또는 초기 데이터 투입 시)
```dart
// Edge Function 또는 관리자 도구에서 실행 (service_role_key 사용)
final res = await supabase.auth.admin.createUser(AdminUserAttributes(
  email: '${employeeId}@oamanager.internal',
  password: password,
  emailConfirm: true,  // 이메일 확인 스킵
  userMetadata: {
    'employee_id': employeeId,
    'employee_name': '홍길동',
    'employment_type': '정규직',
  },
));
```

#### 로그인
```dart
// 클라이언트
final res = await supabase.auth.signInWithPassword(
  email: '${employeeId}@oamanager.internal',
  password: password,
);
// res.session → access_token, refresh_token
// res.user → id, email, user_metadata
```

#### 로그인 응답 매핑 (프론트엔드 7.2 호환)
```json
// Supabase Auth 응답 → 프론트엔드 기대 형식으로 변환
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "Bearer",
  "expires_in": 1800,
  "user": {
    "id": 42,
    "employee_id": "employee-id-example",
    "employee_name": "홍길동",
    "employment_type": "정규직",
    "organization_hq": "IT본부",
    "organization_dept": "개발부",
    "organization_team": "플랫폼팀",
    "work_building": "본관",
    "work_floor": "3F"
  }
}
```
> **구현 방식**: Supabase Auth 로그인 후 `users` 테이블에서 사원 정보를 JOIN하여 반환합니다.

### 3.3 SNS 로그인 (카카오 / 구글)

#### Supabase Dashboard 설정
1. **Authentication > Providers** 메뉴
2. **Google**: Client ID / Secret 입력 (Google Cloud Console에서 발급)
3. **Kakao**: Supabase 기본 Provider에 없으므로 **Edge Function으로 구현**

#### 구글 로그인
```dart
// 클라이언트 — Supabase 내장 OAuth
final res = await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'io.supabase.oamanager://callback',
);
```

#### 카카오 로그인 (Edge Function)
```dart
// 1단계: 클라이언트에서 카카오 SDK로 토큰 획득
final kakaoToken = await kakaoLogin();

// 2단계: Edge Function 호출
final res = await supabase.functions.invoke(
  'auth-kakao',
  body: {'kakao_token': kakaoToken},
);
// res.data → { access_token, refresh_token, user }
```

### 3.4 로그아웃
```dart
await supabase.auth.signOut();
// 클라이언트 토큰 자동 삭제
```

### 3.5 토큰 관리
| 항목 | Supabase 기본 | 커스텀 설정 |
|------|-------------|-----------|
| Access Token 만료 | 3600초 (1시간) | config.toml `jwt_expiry = 3600` 또는 Dashboard > Auth > Settings에서 변경 |
| Refresh Token 만료 | 무제한 (기본) | 커스텀: 7일 권장 |
| 자동 갱신 | `supabase_flutter` SDK 자동 처리 | `onAuthStateChange` 리스너 |
| 강제 로그아웃 | Refresh Token 만료 시 | 앱에서 로그인 화면 이동 |

```dart
// 인증 상태 변경 리스너
supabase.auth.onAuthStateChange.listen((data) {
  final event = data.event;
  if (event == AuthChangeEvent.signedOut ||
      event == AuthChangeEvent.tokenRefreshFailure) {
    // 로그인 화면으로 이동
    router.go('/login');
  }
});
```

---

## 4. 데이터베이스 스키마

### 4.1 테이블 관계도 (ER)
```
users (사원 정보)
  ├── 1:N → assets.user_id
  └── 1:N → asset_inspections.user_id

assets (자산 정보)
  ├── N:1 → users.id (user_id FK)
  ├── N:1 → drawings.id (location_drawing_id FK)
  ├── 1:N → asset_inspections.asset_id
  └── 1:1 → device_tokens.asset_uid (레거시 — FCM 미사용)

asset_inspections (실사 기록)
  ├── N:1 → assets.id (asset_id FK)
  └── N:1 → users.id (user_id FK)

drawings (도면 정보)
  └── 1:N → assets.location_drawing_id

access_settings (접속 제한 설정)
  └── 단일 행 (시스템 전역 설정)

device_tokens (레거시 — FCM 미사용, 테이블·RLS만 유지)
  └── N:1 → assets.asset_uid (UNIQUE, 1기기 1토큰)

notifications (알림 이력 + Realtime 전달)
  └── 독립 (asset_uid 참조, FK 없음)

agent_settings (에이전트 설정)
  └── 독립 (시스템 전역 설정)

inspection_rounds (전사 실사 라운드)
  └── 1:N → asset_inspections.round_id

dropdown_options (드롭다운 옵션, 2026-06-15)
  └── 독립 (scope별 옵션 목록)

vendors / receipts / receipt_items (인수증, 2026-09-22)
  └── receipts N:1 → vendors, receipt_items N:1 → receipts

menu_permissions (메뉴 권한, 2026-09-29)
  └── 대상(all/role/user)별 보이는 메뉴 키 목록
```

### 4.2 users (사원 정보)
> 프론트엔드 명세 8.3 기반 + Supabase Auth 연동 컬럼 추가

```sql
CREATE TABLE public.users (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  auth_uid      uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- Supabase Auth 연동
  employee_id   text UNIQUE NOT NULL,                                -- 사번
  employee_name text NOT NULL,                                       -- 사원 이름
  employment_type text NOT NULL DEFAULT '정규직'                      -- 고용형태 (정규직/계약직/도급직)
    CHECK (employment_type IN ('정규직', '계약직', '도급직')),
  organization_hq   text,                                            -- 소속 본부
  organization_dept text,                                            -- 소속 부서
  organization_team text,                                            -- 소속 팀
  organization_part text,                                            -- 파트 정보
  organization_etc  text,                                            -- 직책/기타 정보
  work_building text,                                                -- 근무 건물
  work_floor    text,                                                -- 근무 층
  auth_provider text DEFAULT 'email'                                 -- 인증 방식 (email/kakao/google)
    CHECK (auth_provider IN ('email', 'kakao', 'google')),
  sns_id        text,                                                -- SNS 고유 ID (OAuth 사용 시)
  role          text NOT NULL DEFAULT 'user'                          -- 사용자 역할
    CHECK (role IN ('admin', 'operator1', 'operator2', 'user')),
  is_master_admin boolean NOT NULL DEFAULT false,                     -- 마스터 관리자 (최대 4명, role=admin 한정)
  must_change_password boolean NOT NULL DEFAULT false,                -- 관리자가 비밀번호 설정 시 다음 로그인에서 강제 변경
  receipt_team  text,                                                -- 인수증 서명 담당 (helpdesk / it_plan)
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_users_auth_uid ON public.users(auth_uid);
CREATE INDEX idx_users_employee_id ON public.users(employee_id);
CREATE INDEX idx_users_is_master_admin ON public.users(is_master_admin) WHERE is_master_admin = true;
```

> **역할 체계**:
> | 역할 | 설명 | 권한 |
> |------|------|------|
> | `admin` | 관리자 | 전체 조회 + 자산·도면 변경, 라운드 시작/종료/재오픈/삭제, 완료·잠금 실사 수정, 실사 초기화·삭제, 사용자 관리(9.13) |
> | `operator1` | 운영자1 | 전체 조회 + 자산·도면 변경, 라운드 생성/시작/종료 (실사 수정·초기화 불가) |
> | `operator2` | 운영자2 | operator1과 동일 |
> | `user` | 일반 사용자 | 본인 배정 자산·참여 실사만 조회. 활성 라운드의 배정 자산 미완료 실사만 입력 |
>
> **마스터 관리자 (`is_master_admin`)**:
> - role=admin 사용자 중 최대 **4명**까지 지정 가능 (BEFORE INSERT/UPDATE 트리거로 강제)
> - role≠admin에 부여 시도 시 예외
> - 초기 master는 통제된 bootstrap 절차로만 지정
> - 마스터가 자산 `user_name`을 변경하면 자산의 `verification_status`가 자동 초기화되고 `notifications` 테이블에 row가 자동 삽입됨 (9.9.2 참조)
> - `public.is_master_admin()` SECURITY DEFINER 헬퍼: 현재 로그인 사용자 체크
>
> **참고**: 비밀번호는 Supabase Auth(`auth.users`)에서 관리하며, `public.users`에는 저장하지 않습니다. `auth_uid`로 Supabase Auth 계정과 연결합니다.

### 4.3 assets (자산 정보)
> 프론트엔드 명세 8.1 기반

```sql
CREATE TABLE public.assets (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text UNIQUE NOT NULL                                 -- 자산 고유 코드 (QR 매칭 키)
    CHECK (asset_uid ~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$'),  -- 9.2 트리거도 동일
  name          text,                                                -- 자산 명칭
  -- assets_status 컬럼은 20260614000002에서 삭제됨 — "상태"는 supply_type으로 일원화
  supply_type   text DEFAULT '지급'                                   -- 자산지급형태 (= UI "상태")
    CHECK (supply_type IN ('지급', '렌탈', '대여', '이동', '창고(대기)', '창고(점검)', '폐기', '도급', '개인')),
  supply_end_date timestamptz,                                       -- 대여/렌탈 만료일
  category      text NOT NULL                                        -- 자산 분류
    CHECK (category IN ('데스크탑', '모니터', '노트북', 'IP전화기', '스캐너', '프린터', '태블릿', '테스트폰', '네트워크장비', '서버', '웨어러블', '특수목적장비')),
  serial_number  text,                                               -- 시리얼 번호
  model_name     text,                                               -- 모델명
  vendor         text,                                               -- 제조사
  network        text,                                               -- 사용망 (권장: 업무망/개발망/시스템망/인터넷망/셀룰러, 자유 입력)
  physical_check_date timestamptz,                                   -- 실물 점검일
  confirmation_date   timestamptz,                                   -- 관리자 확인일
  normal_comment text,                                               -- 일반 메모
  oa_comment     text,                                               -- OA 관련 메모
  mac_address    text,                                               -- MAC 주소
  building1      text,                                               -- 사용자 유형 (내부/외부 등)
  building       text,                                               -- 건물명
  floor          text,                                               -- 층 정보
  owner_name     text,                                               -- 소유자명
  owner_department text,                                             -- 소유자부서
  user_name      text,                                               -- 사용자명
  user_employee_id text,                                             -- 사용자 사번 (verify_user 비교 기준)
  user_department text,                                              -- 사용자부서
  admin_name     text,                                               -- 관리자명
  admin_department text,                                             -- 관리자부서
  admin_affiliation text,                                            -- 담당자 소속 (롯데카드 / 롯데카드 외)
  admin_company  text,                                               -- '롯데카드 외' 선택 시 회사명
  location_drawing_id bigint REFERENCES public.drawings(id)
    ON DELETE SET NULL,                                              -- 도면 FK
  location_row   int,                                                -- 도면 좌표 (행)
  location_col   int,                                                -- 도면 좌표 (열)
  location_drawing_file text,                                        -- 도면 파일명
  user_id        bigint REFERENCES public.users(id)
    ON DELETE SET NULL,                                              -- 자산 담당 사용자 FK
  specifications jsonb DEFAULT '{}'::jsonb,                          -- 유형별 추가 사양 (하이브리드)
  last_active_at timestamptz,                                        -- 최종 접속 시각 (접속현황 인디케이터용)
  last_verified_at timestamptz,                                      -- 마지막 사용자 확인 시각 (에이전트)
  verification_status text,                                          -- 사용자 확인 상태 ('verified', 'mismatch', NULL=미확인)
  assignment_status text,                                            -- 자산 배정 상태 ('pending', 'confirmed', NULL=배정 없음)
  assignment_confirmed_at timestamptz,                               -- 자산 수령 확인 시각
  inspection_round_no int NOT NULL DEFAULT 0,                        -- 활성 라운드 회차 번호를 따라감
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_assets_asset_uid ON public.assets(asset_uid);
CREATE INDEX idx_assets_category ON public.assets(category);
CREATE INDEX idx_assets_supply_type ON public.assets(supply_type);
CREATE INDEX idx_assets_building ON public.assets(building);
CREATE INDEX idx_assets_user_id ON public.assets(user_id);
CREATE INDEX idx_assets_supply_end_date ON public.assets(supply_end_date)
  WHERE supply_type IN ('렌탈', '대여');  -- 만료 임박 조회용 부분 인덱스
CREATE INDEX idx_assets_drawing ON public.assets(location_drawing_id);
CREATE INDEX idx_assets_specifications ON public.assets
  USING gin(specifications);             -- JSONB 검색용 GIN 인덱스
CREATE INDEX idx_assets_last_active ON public.assets(last_active_at);
```

> **설계 방침**: 프론트엔드 명세 8.1과 동일합니다. 공통 항목은 컬럼, 유형별 추가 사양은 `specifications` JSONB에 저장합니다.
> **asset_uid 규칙** (두 형식 병행, `20261011000000`):
> - 현재기준: `영문 대문자 1~2자리 + 숫자 4~5자리` (예: `D00001`, `TP0012`) — 아래 표
> - 변경후: `등록경로(B/R/C/L/S) + 장비코드 2자리 + 숫자 5자리` (예: `BDT00001`, `STP22222`)
> - 전체 코드 표는 `docs/asset_uid_spec.md` 참고

| 코드 | 설명 | 코드 | 설명 |
|------|------|------|------|
| `D` | 데스크탑 | `C` | IP전화기 |
| `N` | 노트북 | `TP` | 테스트폰 |
| `T` | 태블릿 | `EH` | 법인폰 |
| `M` | 모니터 | `ET` | 현장업무 태블릿 |
| `S` | 스캐너 | `P` | 프린터 |

### 4.4 specifications JSONB 구조 (유형별)
> 프론트엔드 명세 8.2 그대로 사용 — category 값에 따라 JSONB 구조가 결정됩니다.

| category | JSONB 필드 |
|----------|-----------|
| 데스크탑 | `ram_capacity`, `ram_slots`, `os_type`, `os_version`, `os_detail_version` |
| 모니터 | `size_inch`, `resolution`, `is_4k` |
| IP전화기 | `phone_number1`, `phone_number2`, `phone_number3` |
| 노트북 | `ram_capacity`, `os_type`, `os_version`, `os_detail_version`, `supports_5g` |
| 스캐너 | `{}` (빈 객체) |
| 프린터 | `{}` (빈 객체) |
| 태블릿 | `ram_capacity`, `os_type`, `os_version`, `os_detail_version`, `supports_5g`, `has_keyboard`, `has_pen` |
| 테스트폰 | `ram_capacity`, `os_type`, `os_version`, `os_detail_version`, `supports_5g` |
| 네트워크장비 | `{}` (빈 객체) |
| 서버 | `{}` (빈 객체) |
| 웨어러블 | `{}` (빈 객체) |
| 특수목적장비 | `{}` (빈 객체) |

### 4.5 asset_inspections (실사 기록)
> 프론트엔드 명세 8.4 기반

```sql
CREATE TABLE public.asset_inspections (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_id      bigint REFERENCES public.assets(id)
    ON DELETE RESTRICT,                                              -- 자산 FK (실사 기록 보호: 5.3 RLS 정책과 일치)
  user_id       bigint REFERENCES public.users(id)
    ON DELETE SET NULL,                                              -- 사용자 FK
  inspector_name text,                                               -- 실사 담당자
  user_team     text,                                                -- 담당자 팀
  asset_code    text,                                                -- 자산 코드 (asset_uid 매칭)
  asset_type    text,                                                -- 자산 종류
  asset_info    jsonb DEFAULT '{}'::jsonb,                           -- 모델명/용도/시리얼 등 상세
  inspection_count int DEFAULT 1,                                    -- 실사 횟수
  inspection_date  timestamptz,                                      -- 실사 완료 일시 (DEFAULT 없음 — 완료 시점에 기록)
  maintenance_company_staff text,                                    -- 유지보수 담당자
  department_confirm text,                                           -- 확인 부서
  inspection_building  text,                                         -- 실사 확인 건물명
  inspection_floor     text,                                         -- 실사 확인 층
  inspection_position  text,                                         -- 실사 확인 자리번호 (예: "A-3")
  status        text,                                                -- 자산 상태 (assets 상태와 동기화)
  memo          text,                                                -- 점검 메모
  inspection_photo text,                                             -- 사진 파일 Storage 경로
  signature_image  text,                                             -- 서명 파일 Storage 경로
  round_id      bigint REFERENCES public.inspection_rounds(id),      -- 전사 실사 라운드 FK
  locked        boolean NOT NULL DEFAULT false,                      -- 등록 후 잠금 (관리자만 해제/수정)
  synced        boolean DEFAULT true,                                -- 서버 동기화 여부
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_inspections_asset_id ON public.asset_inspections(asset_id);
CREATE INDEX idx_inspections_user_id ON public.asset_inspections(user_id);
CREATE INDEX idx_inspections_asset_code ON public.asset_inspections(asset_code);
CREATE INDEX idx_inspections_date ON public.asset_inspections(inspection_date DESC);
CREATE INDEX idx_inspections_synced ON public.asset_inspections(synced)
  WHERE synced = false;  -- 미동기화 항목 조회용
```

> **완료 상태(`completed`) 기준**: 아래 항목이 모두 존재하면 완료로 간주합니다.
> `inspection_building`, `inspection_floor`, `inspection_position`, `inspection_photo`, `signature_image`
> `completed`는 API 응답에서 계산 필드로 노출할 수 있으며(7.6 참고), 완료건 수정 권한은 5.4 RLS 정책으로 제어합니다.
>
> **사진 저장 경로 패턴**: `<auth_uid>/{round}/photos/{assetCode}_{page}_{timestamp}_{round}.jpg`
> **서명 저장 경로 패턴**: `<auth_uid>/{round}/signatures/{inspId}_sig_{timestamp}_{round}.png`
> - 첫 폴더는 업로더의 Auth UUID여야 함 (Storage RLS + `claim_inspection_owner` 트리거가 강제, 6.3 참고)
> - 버킷: `inspection-photos` (사진), `inspection-signatures` (서명)
> - Storage 업로드 성공 → DB 실패 시 고아파일 자동 삭제
> - 라운드 시작 시 모든 자산에 대해 실사 행이 자동 생성됨 (`start_inspection_round`)

### 4.6 inspection_rounds (전사 실사 라운드)

```sql
CREATE TABLE public.inspection_rounds (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  year        int NOT NULL,                                            -- 실사 년도
  round       int NOT NULL,                                            -- 차수 (1, 2, 3...)
  title       text NOT NULL,                                           -- 예: '2026년 1차 실사'
  status      text NOT NULL DEFAULT 'draft'                            -- 상태
    CHECK (status IN ('draft', 'active', 'closed')),
  started_by  bigint REFERENCES public.users(id),                      -- 시작한 사용자
  started_at  timestamptz,                                             -- 시작 일시
  closed_by   bigint REFERENCES public.users(id),                      -- 종료한 사용자
  closed_at   timestamptz,                                             -- 종료 일시
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  UNIQUE(year, round)                                                  -- 같은 년도에 같은 차수 중복 불가
);
```

> **상태 흐름**: `draft`(대기) → `active`(진행중) → `closed`(종료), 종료 후 `reopen_inspection_round`로 재오픈 가능
> **동시 진행 제한**: active 라운드는 1개만 허용 (`start_inspection_round` RPC에서 검증)
> **RLS**: 조회=인증 사용자, 생성/수정=관리자 그룹, 삭제=관리자만 (5.9 참고)
> **RPC**: `start_inspection_round()`, `close_inspection_round()`, `reopen_inspection_round()`, `delete_inspection_round(id, force)` (9.10, 9.11 참고)

### 4.7 drawings (도면 정보)
> 프론트엔드 명세 8.5 기반

```sql
CREATE TABLE public.drawings (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  building      text NOT NULL,                                       -- 건물명
  floor         text NOT NULL,                                       -- 층 정보
  drawing_file  text,                                                -- Storage 파일 경로
  grid_rows     int DEFAULT 10,                                      -- 격자 행 개수
  grid_cols     int DEFAULT 8,                                       -- 격자 열 개수
  description   text,                                                -- 도면 설명
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now(),

  UNIQUE(building, floor)  -- 건물+층 조합 유니크
);

-- 인덱스
CREATE INDEX idx_drawings_building ON public.drawings(building);
CREATE INDEX idx_drawings_building_floor ON public.drawings(building, floor);
```

### 4.7 access_settings (접속 제한 설정)
> 접속현황 인디케이터의 임계값을 관리자가 동적으로 변경할 수 있도록 별도 테이블로 관리합니다.

```sql
CREATE TABLE public.access_settings (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  setting_key   text UNIQUE NOT NULL,                                  -- 설정 키
  setting_value int NOT NULL,                                          -- 설정 값
  description   text,                                                  -- 설정 설명
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 기본 데이터 삽입
INSERT INTO public.access_settings (setting_key, setting_value, description)
VALUES
  ('active_threshold_minutes', 60, '실시간 접속 판단 기준 (분). 이 시간 이내 활동 시 초록색 표시'),
  ('warning_threshold_days', 31, '경과일 표시 최대 일수. 초과 시 빨간색(만료) 표시'),
  ('verification_interval_days', 30, '에이전트 사용자 확인 주기 (일). 이 주기마다 사용자 이름+사번 재확인');
```

> **접속현황 인디케이터 로직** (프론트엔드 연동):
>
> | 조건 | 표시 |
> |------|------|
> | `last_active_at`이 NULL | 회색 동그라미 (미접속) |
> | 현재 시각 − `last_active_at` ≤ `active_threshold_minutes` | 초록색 동그라미 (실시간 접속) |
> | 경과일 1 ~ `warning_threshold_days` | 연두색 동그라미 + 경과일 숫자 |
> | 경과일 > `warning_threshold_days` | 빨간색 동그라미 (접속 만료) |
>
> - `경과일` = `floor((현재 시각 − last_active_at) / 24시간)`
> - 관리자가 `access_settings`의 값을 변경하면 즉시 반영됩니다.

#### access_settings RLS 정책
조회는 인증 사용자, 수정은 admin만 가능합니다 (5.8 참고). 익명 조회는 허용하지 않습니다.

### 4.8 테이블 생성 순서
FK 의존성을 고려한 생성 순서:
1. `users` (의존 없음)
2. `drawings` (의존 없음)
3. `assets` (→ users, drawings 참조)
4. `asset_inspections` (→ assets, users 참조)
5. `access_settings` (의존 없음, 시스템 설정)
6. `device_tokens` (→ assets 참조, 레거시)
7. `notifications` (에이전트 푸시 알림 이력)
8. `agent_settings` (의존 없음, 에이전트 버전 관리)

### 4.9 device_tokens (레거시 — FCM 미사용)
> 2026-06-04부터 알림은 Supabase Realtime(`notifications` INSERT)으로 전달되며 FCM은 사용하지 않습니다. 테이블과 RLS(5.6)는 데이터 보존용으로 남아 있습니다.

```sql
CREATE TABLE public.device_tokens (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text UNIQUE NOT NULL                                   -- 자산 고유 식별자 (1기기 1토큰)
    REFERENCES public.assets(asset_uid) ON DELETE CASCADE,
  fcm_token     text NOT NULL,                                         -- FCM 디바이스 토큰
  platform      text NOT NULL DEFAULT 'android'                        -- 플랫폼
    CHECK (platform IN ('android', 'ios', 'linux', 'windows')),
  updated_at    timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_device_tokens_asset_uid ON public.device_tokens(asset_uid);
CREATE INDEX idx_device_tokens_platform ON public.device_tokens(platform);
```

### 4.10 notifications (알림 이력 + Realtime 전송)
> 관리자/시스템이 에이전트로 발송한 알림 이력을 저장하며, **Supabase Realtime publication에 등록**되어 있어 INSERT 시 에이전트가 즉시 수신합니다 (FCM 미사용).

```sql
CREATE TABLE public.notifications (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text,                                                  -- 대상 자산 (NULL이면 전체 발송)
  type          text NOT NULL DEFAULT 'general'                        -- 알림 유형
    CHECK (type IN ('os_update', 'security_alert', 'general', 'agent_update', 'recheck_request')),
  title         text NOT NULL,                                         -- 알림 제목
  body          text,                                                  -- 알림 내용
  sent_at       timestamptz DEFAULT now(),                             -- 발송 시각
  read_at       timestamptz                                            -- 읽은 시각 (NULL=미읽음)
);

-- 인덱스
CREATE INDEX idx_notifications_asset_uid ON public.notifications(asset_uid);
CREATE INDEX idx_notifications_type ON public.notifications(type);
CREATE INDEX idx_notifications_sent_at ON public.notifications(sent_at DESC);

-- Realtime publication (마이그레이션 #21에서 추가)
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
```

> **알림 발생 경로**
> 1. `admin_force_verify(asset_uid)` RPC 호출 (admin)
> 2. 마스터 관리자가 `assets.user_name` 변경 → BEFORE UPDATE 트리거가 자동으로 INSERT
> 3. `request_inspection_recheck(inspection_id)` RPC — 재실사 요청 (`recheck_request`)
> 4. 관리자 그룹의 직접 INSERT 또는 `main` Edge Function의 알림 발송(관리자 그룹 JWT 필수)
>
> **에이전트 수신**: private 채널 `notifications:{asset_uid}`에서 `postgres_changes` 구독 (`filter=asset_uid=eq.<자기 자산>`). 채널 참여와 행 수신 모두 해당 자산 담당자(`is_current_asset_assignee`)만 가능 (5.7, 10.5 참고). 수신 시 Android 시스템 알림(`admin_alert_channel`, IMPORTANCE_HIGH)으로 표시.

### 4.11 agent_settings (에이전트 설정)
> 에이전트 최신 버전 및 다운로드 URL 등 에이전트 전역 설정을 관리합니다.

```sql
CREATE TABLE public.agent_settings (
  setting_key   text PRIMARY KEY,                                      -- 설정 키
  setting_value text NOT NULL,                                         -- 설정 값
  updated_at    timestamptz DEFAULT now()
);

-- 기본 데이터 삽입
INSERT INTO public.agent_settings (setting_key, setting_value)
VALUES
  ('latest_agent_version', '1.0.0'),
  ('min_agent_version', '1.0.0'),
  ('agent_download_url', 'https://example.com/agent/latest.apk');
```

### 4.12 추가 테이블 (2026-06 이후)
| 테이블 | 마이그레이션 | 용도 | RLS 요약 |
|--------|-------------|------|----------|
| `dropdown_options` | `20260615000000` | 페이지별(`asset_detail`/`asset_list`/`inspection_list`/`inspection_detail`) 드롭다운 옵션 | 조회=인증 사용자, 쓰기=관리자 그룹 |
| `vendors` | `20260922000000` | 인수증 거래처 마스터 (로고, 양식 변형) | 조회=인증 사용자, 쓰기=관리자 그룹 |
| `receipts` / `receipt_items` | `20260922000000`~`20260929000003` | 인수증 본문·항목 (발송/인수업체, 서명 3종, 금액) | 5.10 참고 |
| `menu_permissions` | `20260929000000` | 대상(`all`/`role`/`user`)별 보이는 메뉴 키 목록. 우선순위 user > role > all > 기본(전부 보임) | 조회=인증 사용자, 쓰기=관리자 |
| `asset_software` (계획) | — | 자산별 설치 SW 스냅샷. 쓰기는 `replace_asset_software` RPC만 | `docs/software_inventory_spec.md` §4 |

---

## 5. Row Level Security (RLS)
> **기준 문서**: `SECURITY_HARDENING_RUNBOOK.md` + `20260816000000_security_hardening.sql` ~ `20260817000006_finite_seed_account_bans.sql`
> 아래는 해당 마이그레이션 적용 후 **최종 유효 정책**입니다. 정책 이름·조건의 SoT는 마이그레이션 파일입니다.

### 5.0 적용 상태 (2026-10-11 라이브 DB `oa-db` 실측)
| 마이그레이션 | 상태 | 비고 |
|--------------|------|------|
| `20260816000000` ~ `20260817000000` | 적용됨 | 익명 차단, 최소 권한, 도면 버킷 private |
| `20260817000002`, `000003`, `000004`, `000005`, `000006` | 적용됨 | 배정 자산만 실사 claim, 긴급 차단, 헬퍼 활성 계정 검사 |
| **`20260817000001`** | 적용됨 (2026-10-11) | private Realtime 토픽 정책 + **담당 범위 조회**. `20260817000003`의 긴급 조치(조회 = 관리자 그룹만)를 대체. 새 프론트(private 채널) 배포 **후** 적용한 순서 |
| `20260922*`, `20260929*`, `20261011000000` | 적용됨 | 인수증·메뉴 권한·asset_uid 두 형식 |
| `20261011000001` | 적용됨 (2026-10-11) | `auth.users` 토큰 컬럼 NULL로 인한 로그인 500 수정 (9.13 참고) |
| `20261011000002` | 라이브 기반영 (적용 불필요) | `category` CHECK 14종 — 라이브에는 이미 직접 반영돼 있어 저장소만 동기화 |
| `20261011000003` | 적용됨 (2026-10-11) | 인수증·거래처·버킷 관리자 그룹 전용(라이브 기반영분 동기화) + `receipts`·`receipt_items`·`vendors`·`menu_permissions` RESTRICTIVE 정책(신규) |

> ⚠️ **라이브 DB가 저장소보다 앞선 경우가 있다** (category CHECK, 인수증 RLS가 운영에 직접 반영돼 있었음). 정책·제약을 판단할 때는 마이그레이션 파일만 보지 말고 라이브를 조회해 확인한다.

> **2026-10-11 실측 검증** (롤백 트랜잭션에서 계정별 시뮬레이션): 관리자 = 자산·실사·도면 전체 조회 / 배정받은 일반 사용자 = 본인 배정 자산만 조회, 남의 자산 0건, 자산 수정 0건 반영 / 배정 없는 일반 사용자 = 0건 / 익명 = `permission denied for schema public`. 현재 자산 2건(`D00001`, `TP0001`)은 모두 미배정이므로 일반 사용자 화면은 담당 자산을 배정하기 전까지 비어 있는 것이 정상입니다.

### 5.0.1 원칙
- **익명(`anon`) 접근 없음**: `public`·`storage` 스키마의 테이블·시퀀스·함수에서 `PUBLIC`/`anon` 권한을 모두 회수했습니다. 익명 키만으로는 테이블, Storage 객체, RPC를 읽거나 쓸 수 없습니다.
- **조회는 역할·담당 범위로 제한**: 관리자 그룹(admin/operator1/operator2)은 전체 조회, 일반 사용자는 **자신에게 배정된 자산**(`assets.user_id`)과 **자신이 참여한 실사**만 조회합니다.
- **변경은 관리자 그룹**: 자산·도면·라운드·드롭다운 옵션·알림은 관리자 그룹만 변경합니다.
- **계정 관리는 마스터 관리자 RPC만**: `public.users`에 대한 클라이언트 INSERT/UPDATE/DELETE 권한은 없습니다 (9.12 참고).
- **기본 ACL 차단**: `postgres` 소유 신규 객체의 기본 권한에서 `PUBLIC`/`anon`/`authenticated`/`service_role`을 회수했습니다. 새 테이블·함수는 마이그레이션에서 명시적으로 GRANT해야 합니다.
- **RPC 실행 권한**: 스키마 전체 `EXECUTE`를 회수한 뒤 클라이언트용 RPC만 `authenticated`에 개별 GRANT합니다. 모든 SECURITY DEFINER 함수는 내부에서 호출자 권한을 다시 검사하고 `search_path`를 고정합니다.

### 5.1 공통 RESTRICTIVE 정책
모든 permissive 정책과 AND로 결합되어 항상 함께 적용됩니다.

| 정책 | 대상 | 조건 | 목적 |
|------|------|------|------|
| `auth_banned_account_block` | `users`, `assets`, `asset_inspections`, `drawings`, `device_tokens`, `notifications`, `access_settings`, `agent_settings`, `dropdown_options`, `inspection_rounds`, `storage.objects`, `storage.buckets`, `realtime.messages` | `is_current_auth_account_active()` | 차단(banned)·삭제된 계정의 기존 JWT도 즉시 무력화 |
| `legacy_agent_block` | 위 public 테이블 + `storage.objects`/`buckets` | `NOT is_legacy_agent()` | `employee_id='agent'` 공용 APK 계정 차단 |

> 역할 판별 헬퍼(`is_admin`, `is_admin_group`, `is_master_admin`, `is_current_asset_assignee`, `is_inspection_participant`, `current_user_id`)는 모두 `is_current_auth_account_active()`를 먼저 확인합니다 (`20260817000005`).

### 5.2 users
```sql
CREATE POLICY users_select_own_or_admin_group ON public.users
  FOR SELECT TO authenticated
  USING (auth_uid = auth.uid() OR public.is_admin_group());

REVOKE INSERT, UPDATE, DELETE ON public.users FROM authenticated;
```
> 역할 변경·마스터 지정·계정 생성·비밀번호 초기화는 마스터 관리자 전용 RPC로만 수행합니다 (9.12).

### 5.3 assets
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 관리자 그룹, 또는 `assets.user_id = current_user_id()` (배정된 담당자) |
| INSERT / UPDATE | 관리자 그룹 |
| DELETE | 관리자 그룹 + 실사 기록이 없는 자산만 |

### 5.4 asset_inspections
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 관리자 그룹, 또는 실사 참여자(`is_inspection_participant`: 실사 소유자 또는 해당 자산 담당자) |
| INSERT | 관리자 그룹 (일반 실사 행은 라운드 시작 RPC가 자동 생성) |
| UPDATE | admin: 항상 / 일반 사용자: 아래 조건을 모두 만족할 때 |
| DELETE | admin |

**일반 사용자 UPDATE 조건** (`inspections_update_claimed_active` + `claim_inspection_owner` 트리거):
- `locked = false`이고 미완료 상태 (건물·층·자리·사진·서명 5개가 모두 채워지지 않음)
- 소속 라운드가 `active`
- 원본 자산이 호출자에게 배정되어 있음 (`assets.user_id = current_user_id()`)
- 아직 소유자가 없거나 본인이 소유자 — 처음 수정할 때 본인으로 귀속(claim)되며 이후 다른 계정은 수정 불가
- `asset_id`, `round_id`, `locked`, `inspection_count`는 변경 불가
- 사진·서명 경로의 첫 폴더가 호출자 Auth UUID여야 함

> **관리자 그룹 vs admin**: 실사 수정·삭제·초기화는 `is_admin()`(role=admin) 기준입니다. operator1/2는 조회와 라운드 관리만 가능합니다.

### 5.5 drawings
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 관리자 그룹, 또는 배정 자산이 위치한 도면(`can_current_user_read_drawing`) |
| INSERT / UPDATE / DELETE | 관리자 그룹 |

### 5.6 device_tokens (레거시)
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 관리자 그룹 |
| INSERT / UPDATE / DELETE | 관리자 그룹, 또는 해당 자산 담당자 |

### 5.7 notifications
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 관리자 그룹, 또는 해당 `asset_uid` 담당자 |
| INSERT / UPDATE | 관리자 그룹 |

### 5.8 access_settings / agent_settings
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 인증 사용자 (익명 조회 불가) |
| UPDATE | admin |

### 5.9 inspection_rounds
| 작업 | 허용 대상 |
|------|----------|
| SELECT | 인증 사용자 |
| INSERT / UPDATE | 관리자 그룹 (시작·종료·재오픈은 RPC) |
| DELETE | admin (`delete_inspection_round` RPC 권장) |

### 5.10 인수증·옵션·메뉴 테이블
| 테이블 | SELECT | INSERT / UPDATE | DELETE |
|--------|--------|-----------------|--------|
| `dropdown_options` | 인증 사용자 | 관리자 그룹 | 관리자 그룹 |
| `vendors` | 관리자 그룹 | 관리자 그룹 | 관리자 그룹 |
| `receipts` | 관리자 그룹 | 관리자 그룹 | admin |
| `receipt_items` | 관리자 그룹 | 관리자 그룹 | 관리자 그룹 |
| `menu_permissions` | 인증 사용자 (본인 메뉴 계산용) | admin | admin |

> 인수증 테이블과 `receipt-signatures`/`receipt-assets` 버킷은 관리자 그룹 전용이며, 5개 테이블 모두 5.1 RESTRICTIVE 정책 대상입니다 (`20261011000003`, 2026-10-11). 최초 `20260922000000`의 "인증 사용자 전체 허용"은 대체되었습니다.

---

## 6. Storage (파일 저장)

### 6.1 버킷 구성
| 버킷 | 공개 | 용도 | 허용 MIME | 최대 크기 |
|------|------|------|----------|----------|
| `inspection-photos` | private | 실사 사진 | image/jpeg, image/png | 10MB |
| `inspection-signatures` | private | 친필 서명 | image/png | 10MB |
| `drawing-images` | private (`20260817000000`에서 public 해제) | 도면 이미지 | image/jpeg, image/png, image/webp | 10MB |
| `receipt-signatures` | private | 인수증 서명 | — | — |
| `receipt-assets` | private | 거래처 로고 등 | — | — |

> 모든 파일 URL은 Signed URL로만 조회합니다. public 버킷은 객체 RLS를 우회하므로 사용하지 않습니다.

### 6.2 파일 경로 규칙
```
inspection-photos/<auth_uid>/{round}/photos/{assetCode}_{page}_{timestamp}_{round}.jpg
inspection-signatures/<auth_uid>/{round}/signatures/{inspId}_sig_{timestamp}_{round}.png
drawing-images/{drawing_id}/{filename}.png
```
> 사진·서명은 **첫 폴더가 업로더 Auth UUID**여야 업로드됩니다. 이전 경로(`{round}/photos/...`)의 기존 파일은 그대로 조회됩니다.

### 6.3 Storage RLS 정책 (최종)
| 버킷 | SELECT | INSERT / UPDATE | DELETE |
|------|--------|-----------------|--------|
| `inspection-photos` | 관리자 그룹, 본인 UUID 폴더, 또는 본인이 참여한 실사의 사진 | 본인 UUID 폴더만 | admin, 본인 UUID 폴더, 또는 본인 소유 실사에 연결된 파일 |
| `inspection-signatures` | 위와 동일 (서명 기준) | 본인 UUID 폴더만 | 위와 동일 |
| `drawing-images` | 관리자 그룹, 또는 배정 자산이 있는 도면의 이미지 | 관리자 그룹 | 관리자 그룹 |
| `receipt-signatures`, `receipt-assets` | 관리자 그룹 | 관리자 그룹 | 관리자 그룹 |

### 6.4 파일 업로드/조회 (클라이언트)
```dart
final authUid = supabase.auth.currentUser!.id;

// 실사 사진 업로드 — 첫 폴더는 반드시 본인 Auth UUID
final path = '$authUid/$roundNum/photos/${assetCode}_detail_${timestamp}_$roundNum.jpg';
await supabase.storage.from('inspection-photos').upload(path, file);

// 서명 이미지 업로드
final sigPath = '$authUid/$roundNum/signatures/${inspId}_sig_${timestamp}_$roundNum.png';
await supabase.storage.from('inspection-signatures').upload(sigPath, signatureBytes);

// 파일 URL 조회 (Private 버킷이므로 Signed URL 사용)
final url = await supabase.storage.from('inspection-photos')
  .createSignedUrl(path, 3600);  // 1시간 유효

// 도면 이미지 업로드 (관리자 그룹)
await supabase.storage.from('drawing-images').upload('$drawingId/floor_plan.png', imageFile);
```

---

## 7. API 엔드포인트

### 7.1 PostgREST 자동 API
Supabase는 PostgREST를 통해 테이블별 REST API를 자동 생성합니다.

기본 URL: `https://<project-id>.supabase.co/rest/v1/{table_name}`

### 7.2 프론트엔드 API ↔ Supabase 매핑
> 프론트엔드 명세 7.1 정책과 동일하게 구현합니다.

#### 7.2.1 인증 진입 API (토큰 없이 호출)
> 정책: 로그인·토큰 갱신만 토큰 없이 호출합니다. **조회(GET)를 포함한 모든 데이터 API는 인증이 필요합니다** (5.0 참고).

| 프론트엔드 API | Supabase 구현 (Dart) |
|--------------|---------------------|
| `POST /api/auth/login` | `supabase.auth.signInWithPassword(email, password)` |
| `POST /api/auth/sns/kakao` | `supabase.functions.invoke('auth-kakao', body)` — 사전 연결된 계정만 (8.2) |
| `POST /api/auth/sns/google` | `supabase.auth.signInWithOAuth(OAuthProvider.google)` |
| `POST /api/auth/refresh` | `supabase_flutter` SDK 자동 처리 |

#### 7.2.1a 인증 필요 조회 API
> 결과 범위는 RLS로 제한됩니다 — 관리자 그룹은 전체, 일반 사용자는 배정 자산·참여 실사만 (5.3~5.5).

| 프론트엔드 API | Supabase 구현 (Dart) |
|--------------|---------------------|
| `GET /api/assets` | `supabase.from('assets').select().range(from, to)` |
| `GET /api/assets/:id` | `supabase.from('assets').select().eq('id', id).single()` |
| `GET /api/users` | `supabase.from('users').select()` (일반 사용자는 본인 행만) |
| `GET /api/users/:id` | `supabase.from('users').select().eq('id', id).single()` |
| `GET /api/inspections` | `supabase.from('asset_inspections_with_asset').select().range(from, to)` (security_invoker view) |
| `GET /api/inspections/:id` | `supabase.from('asset_inspections').select('...,assets!inner(user_name,user_department)').eq('id', id).single()` + `completed` 계산 |
| `GET /api/inspections/:id/photo` | `supabase.storage.from('inspection-photos').createSignedUrl(path, 3600)` |
| `GET /api/inspections/:id/signature` | `supabase.storage.from('inspection-signatures').createSignedUrl(path, 3600)` |
| `GET /api/drawings` | `supabase.from('drawings').select()` |
| `GET /api/drawings/:id` | `supabase.from('drawings').select().eq('id', id).single()` |
| `GET /api/drawings/:id/assets` | `supabase.from('assets').select().eq('location_drawing_id', id)` |

#### 7.2.2 인증 필요 API (등록/수정/삭제)
> 정책: 인증 필요 (`Authorization: Bearer {token}`). 허용 역할은 5장 RLS를 따릅니다 — 자산·도면 변경은 관리자 그룹, 실사 삭제·초기화는 admin.

| 프론트엔드 API | Supabase 구현 (Dart) |
|--------------|---------------------|
| `POST /api/auth/logout` | `supabase.auth.signOut()` |
| `POST /api/assets` | `supabase.from('assets').insert(data)` |
| `PUT /api/assets/:id` | `supabase.from('assets').update(data).eq('id', id)` |
| `DELETE /api/assets/:id` | `supabase.from('assets').delete().eq('id', id)` |
| `POST /api/inspections` | `supabase.from('asset_inspections').insert(data)` (관리자 그룹 — 일반 실사 행은 라운드 시작 시 자동 생성) |
| `PUT /api/inspections/:id` | `supabase.from('asset_inspections').update(data).eq('id', id)` (일반 사용자는 배정 자산·활성 라운드·미완료·미잠금 건만, 5.4) |
| `POST /api/inspections/:id/reset` | `supabase.rpc('reset_inspection', params: {'p_inspection_id': id, 'p_reason': reason})` |
| `DELETE /api/inspections/:id` | `supabase.from('asset_inspections').delete().eq('id', id)` (admin) |
| `POST /api/inspections/:id/photo` | `supabase.storage.from('inspection-photos').upload(path, file)` |
| `POST /api/inspections/:id/signature` | `supabase.storage.from('inspection-signatures').upload(path, file)` |
| `POST /api/drawings` | `supabase.from('drawings').insert(data)` + Storage 업로드 |
| `PUT /api/drawings/:id` | `supabase.from('drawings').update(data).eq('id', id)` |
| `DELETE /api/drawings/:id` | `supabase.from('drawings').delete().eq('id', id)` + Storage 삭제 |

### 7.3 페이지네이션
> 프론트엔드 30건 단위 페이지네이션 구현

```dart
// 자산 목록 조회 (page=1, size=30)
final page = 1;
final size = 30;
final from = (page - 1) * size;
final to = from + size - 1;

final response = await supabase
  .from('assets')
  .select('*', const FetchOptions(count: CountOption.exact))  // total count 포함
  .range(from, to)
  .order('id', ascending: false);

final total = response.count;       // 전체 수
final totalPages = (total / size).ceil();  // 전체 페이지 수
final data = response.data;         // 자산 목록
```

### 7.4 검색/필터
> 프론트엔드 7.2 쿼리 파라미터 → PostgREST 필터 변환

```dart
// GET /api/assets?category=데스크탑&supply_type=지급&building=본관&search=D0
var query = supabase
  .from('assets')
  .select('*', const FetchOptions(count: CountOption.exact));

// 유형 필터
if (category != null) query = query.eq('category', category);

// 지급형태 필터
if (supplyType != null) query = query.eq('supply_type', supplyType);

// 건물 필터
if (building != null) query = query.eq('building', building);

// 검색 (자산번호, 자산명, 시리얼번호, 사용자명)
if (search != null) {
  query = query.or('asset_uid.ilike.%$search%,name.ilike.%$search%,serial_number.ilike.%$search%,user_name.ilike.%$search%');
}

// 페이지네이션 + 정렬
final response = await query
  .order('id', ascending: false)
  .range(from, to);
```

### 7.5 자산 등록 요청/응답 예시
```dart
// POST /api/assets (프론트엔드 7.2 자산 등록 요청 대응)
final response = await supabase.from('assets').insert({
  'asset_uid': 'D00001',
  'name': '개발팀 데스크탑',
  'supply_type': '지급',
  'category': '데스크탑',
  'serial_number': 'SN-12345',
  'model_name': 'Dell OptiPlex 7090',
  'vendor': 'Dell',
  'building': '본관',
  'floor': '3F',
  'owner_name': '홍길동',
  'owner_department': '경영지원팀',
  'user_name': '김개발',
  'user_department': '개발팀',
  'admin_name': '박관리',
  'admin_department': 'IT운영팀',
  'user_id': 42,
  'specifications': {
    'ram_capacity': '16GB',
    'ram_slots': 2,
    'os_type': 'Windows',
    'os_version': '11',
    'os_detail_version': '22H2',
  },
}).select().single();
```

### 7.6 실사 상세/초기화/권한 예시
```dart
// GET /api/inspections/:id
final raw = await supabase
  .from('asset_inspections')
  .select('''
    id, asset_id, asset_code,
    inspection_building, inspection_floor, inspection_position,
    inspection_photo, signature_image,
    assets!inner(user_name, user_department)
  ''')
  .eq('id', inspectionId)
  .single();

final completed =
    raw['inspection_building'] != null &&
    raw['inspection_floor'] != null &&
    raw['inspection_position'] != null &&
    raw['inspection_photo'] != null &&
    raw['signature_image'] != null;

// POST /api/inspections/:id/reset (관리자 전용)
await supabase.rpc('reset_inspection', params: {
  'p_inspection_id': inspectionId,
  'p_reason': '재실사 필요',
});
```

> **권한 동작**: 일반사용자가 완료건을 수정하거나 초기화하면 RLS/RPC에서 `403`을 반환합니다.

---

## 8. Edge Functions (서버리스 함수)

### 8.1 개요
Supabase Edge Functions는 Deno 런타임 기반 TypeScript 함수입니다. self-hosted edge-runtime에서 운영합니다.

| 함수 | 공개 여부 | 인증·권한 |
|------|----------|----------|
| `auth-kakao` | 로그인 경계로만 공개 | 카카오 토큰 검증 + 사전 연결된 OA 계정만. Kong 별도 경로에서 IP rate-limit·요청 크기 제한 |
| `dashboard-stats` | 비공개 | 사용자 JWT 검증 + 서버 측 관리자 그룹 확인 |
| `expiring-assets` | 비공개 | 사용자 JWT 검증 + 서버 측 관리자 그룹 확인 |
| `main` | **공개 경로 차단** | 단일 dispatcher. 현재 `send-notification`만 inline 호스팅, JWT + 관리자 그룹 필수 |
| `send-notification` | 비공개 (`main` 경유) | 위와 동일. 단 현재 대상(`device_tokens`)이 0건이라 실질적으로 동작하지 않음 (8.5) |

> **원칙** (보안 실행서 §2): service role 클라이언트는 호출자 JWT를 검증한 **뒤에만** 사용합니다. anon key는 공개값이므로 관리자 증명으로 쓰지 않습니다.

```bash
supabase functions deploy auth-kakao
supabase functions deploy dashboard-stats
supabase functions deploy expiring-assets
supabase functions deploy main
```

### 8.2 auth-kakao (카카오 로그인)
> 카카오 SDK 토큰을 카카오 API로 검증하고, **미리 연결된** `users.sns_id`/`auth_uid` 조합에만 Supabase Auth 세션을 발급합니다.

| 항목 | 규칙 |
|------|------|
| 입력 | `{ kakao_token }`만 받음 — 임의 사번·Auth UID·redirect URL은 받지 않음 |
| 매칭 | `users.sns_id = <카카오 ID>`인 행의 `auth_uid`로 기존 Auth 계정 조회 |
| 미연결 계정 | 403 "관리자에게 카카오 계정 연결을 요청하세요" — 계정을 생성하거나 자동 연결하지 않음 |
| 세션 발급 | 서버에서 `generateLink` + OTP 검증으로 발급 (클라이언트 redirect 미사용) |
| 요청 제한 | `application/json`만 허용(415), 본문 크기 초과 시 413 |

### 8.3 dashboard-stats (대시보드 통계)
> 홈 화면 상단 카드에 필요한 **집계 숫자 데이터**를 반환합니다.
> 목록 데이터(최신 자산, 만료 임박 자산)는 PostgREST 직접 쿼리 또는 8.4를 사용합니다.

```typescript
// supabase/functions/dashboard-stats/index.ts
// GET /functions/v1/dashboard-stats

// 응답:
{
  "total_assets": 152,           // 총 자산 수
  "inspection_rate": 78.5,       // 실사 완료율 (%)
  "unverified_count": 33,        // 미검증 자산 수
  "expiring_count": 5            // 만료 임박 자산 수 (D-7 이내)
}
```

> **역할 구분**: `dashboard-stats`는 통계 숫자만 반환합니다. 홈 화면의 **최신 자산 10건**은 `supabase.from('assets').select().order('created_at', ascending: false).limit(10)`으로 직접 조회하고, **만료 임박 자산 상세 목록**은 8.4 `expiring-assets`에서 조회합니다.

### 8.4 expiring-assets (만료 임박 자산 목록)
> supply_type이 '렌탈' 또는 '대여'이고 supply_end_date가 7일 이내인 자산의 **상세 목록**을 반환합니다.
> 홈 화면의 만료 임박 자산 리스트 렌더링에 사용합니다.

```sql
-- DB Function으로 구현 (Edge Function에서 호출하거나 RPC로 직접 호출 가능)
CREATE OR REPLACE FUNCTION public.get_expiring_assets()
RETURNS TABLE (
  id bigint,
  asset_uid text,
  name text,
  supply_type text,
  supply_end_date timestamptz,
  d_day int
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    a.id, a.asset_uid, a.name, a.supply_type, a.supply_end_date,
    (a.supply_end_date::date - CURRENT_DATE)::int AS d_day
  FROM public.assets a
  WHERE a.supply_type IN ('렌탈', '대여')
    AND a.supply_end_date IS NOT NULL
    AND a.supply_end_date <= CURRENT_DATE + INTERVAL '7 days'
    AND a.supply_end_date >= CURRENT_DATE
  ORDER BY a.supply_end_date ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

```dart
// 클라이언트 호출 (RPC)
final expiring = await supabase.rpc('get_expiring_assets');

// 또는 Edge Function 호출
final res = await supabase.functions.invoke('expiring-assets');
```

### 8.5 send-notification (관리자 알림 발송)
> `main` dispatcher에 inline되어 있습니다. **사용자 JWT + 서버 측 관리자 그룹 역할**을 모두 확인한 뒤 실행합니다.

| 항목 | 내용 |
|------|------|
| 입력 | `{ asset_uid?, type, title, body }` (`asset_uid` 없으면 전체) |
| 동작 | `device_tokens`에 등록된 기기를 대상으로 `notifications`에 이력을 INSERT (대상 행마다 1건) |
| ⚠️ 현재 상태 | FCM을 쓰지 않아 `device_tokens`가 **0건**이므로 이 함수를 호출해도 알림이 저장되지 않고 `{success:true, total:0}`만 반환합니다. 또한 Kong 라우트(`/functions/v1/`)가 제거되어 외부에서 호출할 수도 없습니다. 실제 알림은 아래 RPC·직접 INSERT 경로를 사용하세요. |
| FCM | 2026-06-04 이후 미사용. `FIREBASE_SERVICE_ACCOUNT_KEY`가 없으면 FCM 단계를 건너뜀(`fcm_skipped: true`) |

> 알림은 Edge Function이 아니라 `admin_force_verify`, `request_inspection_recheck` RPC나 관리자 그룹의 `notifications` INSERT로 발생합니다 (`notifications` INSERT가 곧 Realtime 전달 트리거).

---

## 9. Database Functions & Triggers

### 9.1 updated_at 자동 갱신 트리거
```sql
-- 공통 함수: updated_at 컬럼 자동 갱신
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 각 테이블에 트리거 적용
CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.asset_inspections
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.drawings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.device_tokens
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at BEFORE UPDATE ON public.agent_settings
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();
```

### 9.2 asset_uid 형식 검증/정규화 함수
> 최종 정의: `20261011000000_allow_both_uid_formats.sql` (현재기준 + 변경후 병행). 규격은 `docs/asset_uid_spec.md`.

```sql
-- 형식: 현재기준(D00001, TP0001) 또는 변경후(BDT00001, STP22222)
ALTER TABLE public.assets
  ADD CONSTRAINT assets_asset_uid_check
  CHECK (asset_uid ~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$');

CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  -- 입력 편차 방지: 공백 제거 + 대문자 표준화
  NEW.asset_uid := upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = '허용 형식: D00001, TP0001 (영문 1~2 + 숫자 4~5) 또는 BDT00001 (등록경로 1 + 장비코드 2 + 숫자 5)';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER validate_asset_uid
  BEFORE INSERT OR UPDATE ON public.assets
  FOR EACH ROW EXECUTE FUNCTION public.validate_asset_uid();
```

### 9.3 실사 횟수 자동 증가
```sql
-- 같은 자산에 대한 실사 기록 생성 시 inspection_count 자동 계산
CREATE OR REPLACE FUNCTION public.set_inspection_count()
RETURNS trigger AS $$
BEGIN
  NEW.inspection_count = (
    SELECT COALESCE(MAX(inspection_count), 0) + 1
    FROM public.asset_inspections
    WHERE asset_code = NEW.asset_code
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_inspection_count BEFORE INSERT ON public.asset_inspections
  FOR EACH ROW EXECUTE FUNCTION public.set_inspection_count();
```

### 9.4 사용자 생성 시 Auth ↔ users 동기화
```sql
-- Supabase Auth 회원가입 시 public.users 자동 생성
-- 3.2 회원가입의 userMetadata 전체 필드를 반영합니다.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (
    auth_uid,
    employee_id,
    employee_name,
    employment_type,
    organization_hq,
    organization_dept,
    organization_team,
    organization_part,
    organization_etc,
    work_building,
    work_floor,
    auth_provider,
    sns_id
  )
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'employee_id', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'employee_name', ''),
    COALESCE(NEW.raw_user_meta_data->>'employment_type', '정규직'),
    NEW.raw_user_meta_data->>'organization_hq',
    NEW.raw_user_meta_data->>'organization_dept',
    NEW.raw_user_meta_data->>'organization_team',
    NEW.raw_user_meta_data->>'organization_part',
    NEW.raw_user_meta_data->>'organization_etc',
    NEW.raw_user_meta_data->>'work_building',
    NEW.raw_user_meta_data->>'work_floor',
    COALESCE(NEW.raw_user_meta_data->>'auth_provider', 'email'),
    NEW.raw_user_meta_data->>'sns_id'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```
> **참고**: `raw_user_meta_data`에 없는 필드는 `NULL`이 삽입됩니다. 관리자가 회원 생성 시 `userMetadata`에 조직 정보를 포함하면 자동으로 `users` 테이블에 반영됩니다.

### 9.5 실사 권한/초기화 함수
```sql
-- 관리자 여부: users.role = 'admin' + 활성 계정 (JWT custom claim 아님)
-- 최종 정의: 20260817000005_active_gate_security_definer_helpers.sql
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_uid = auth.uid() AND role = 'admin'
    );
$$;
```

`reset_inspection(p_inspection_id bigint, p_reason text)` — admin 전용. 상태·사진·서명을 비우고 `memo = p_reason`, `synced = false`로 되돌립니다. `authenticated`에 EXECUTE 부여, 내부에서 `is_admin()` 재확인.

`request_inspection_recheck(p_inspection_id bigint)` — 관리자 그룹 또는 실사 참여자. `notifications`에 `recheck_request` 1건 INSERT.

### 9.6 에이전트 RPC (`update_heartbeat` / `verify_user` / `confirm_assignment`)
> 최종 정의: `20260816000000_security_hardening.sql` §8

> ⛔ **현재 `authenticated` 실행 권한 없음 (의도된 차단)**
> 보안 실행서 §4에 따라, 기기별 신원·자산 매핑(에이전트 재도입 설계)이 검증되기 전까지 세 RPC 모두 `PUBLIC`/`anon`/`authenticated`/`service_role`에서 EXECUTE를 회수한 상태입니다. 기존 APK와 공용 에이전트 계정의 heartbeat·사용자 확인·수령 확인은 실패하는 것이 정상입니다. **공용 계정을 위해 GRANT를 되살리지 않습니다.**

함수 본문은 재도입에 대비해 다음 가드를 갖춘 채 유지됩니다.

| 함수 | 파라미터 | 내부 권한 검사 | 동작 |
|------|----------|--------------|------|
| `update_heartbeat` | `p_asset_uid text`, `p_system_info jsonb` | 관리자 그룹 또는 해당 자산 담당자 | `last_active_at = now()`, `specifications.device_status` 저장, `device_status.mac_address`가 있으면 `assets.mac_address` 동기화 |
| `verify_user` | `p_asset_uid`, `p_user_name`, `p_employee_id` | 동일 | `assets.user_name` + `assets.user_employee_id`와 비교 → `verification_status` = `verified`/`mismatch`, NULL은 불일치로 처리 |
| `confirm_assignment` | `p_asset_uid`, `p_user_name` | 동일 | `assignment_status = 'pending'`이고 이름이 같으면 `confirmed` 전환 |

**재도입 조건** (보안 실행서 §4): 자산마다 고유 Auth 신원 또는 일회용 등록 토큰 발급 → 서버가 신원과 정확히 하나의 `asset_uid`를 매핑 → 이 매핑을 검증하는 전용 RPC/Edge Function 구현 후에만 실행 권한 부여.

### 9.9 역할 확인 함수

```sql
-- 관리자 그룹 여부 확인 (admin, operator1, operator2) + 활성 계정
CREATE OR REPLACE FUNCTION public.is_admin_group()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp AS $$
  SELECT public.is_current_auth_account_active()
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE auth_uid = auth.uid()
        AND role IN ('admin', 'operator1', 'operator2')
    );
$$;

-- 현재 사용자의 role 반환
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text LANGUAGE sql STABLE AS $$
  SELECT role FROM public.users
  WHERE auth_uid = auth.uid()
  LIMIT 1;
$$;
```

| 함수 | 반환 | 용도 |
|------|------|------|
| `is_current_auth_account_active()` | boolean | 현재 Auth 계정이 삭제·차단되지 않았는지 (모든 헬퍼가 먼저 확인) |
| `current_user_id()` | bigint | 현재 사용자의 `users.id` |
| `is_admin()` | boolean | role='admin' 여부 |
| `is_current_asset_assignee(asset_uid)` | boolean | 해당 자산의 `user_id`가 현재 사용자인지 |
| `is_inspection_participant(inspection_id)` | boolean | 실사 소유자 또는 해당 자산 담당자인지 |
| `is_legacy_agent()` | boolean | `employee_id='agent'` 공용 계정인지 (차단용) |
| `is_admin_group()` | boolean | admin/operator1/operator2 여부 (RLS, RPC에서 사용) |
| `is_master_admin()` | boolean | 마스터 관리자 여부 (role=admin AND is_master_admin=true) — SECURITY DEFINER |
| `get_my_role()` | text | 현재 사용자의 role 값 (프론트엔드 역할 조회용) |

### 9.9.1 관리자 강제 재확인 RPC `admin_force_verify`

마이그레이션 #21에서 추가. 자산의 사용자 확인 상태를 초기화하고 에이전트에 알림을 발송합니다.

```sql
CREATE OR REPLACE FUNCTION public.admin_force_verify(p_asset_uid text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_found boolean;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION '권한 없음: 관리자만 강제 재확인 가능합니다';
  END IF;

  UPDATE public.assets
  SET verification_status = NULL,
      last_verified_at    = NULL,
      specifications      = specifications - 'user_mismatch'
  WHERE asset_uid = p_asset_uid
  RETURNING true INTO v_found;

  IF NOT v_found THEN
    RAISE EXCEPTION '자산을 찾을 수 없음: %', p_asset_uid;
  END IF;

  INSERT INTO public.notifications (asset_uid, type, title, body)
  VALUES (
    p_asset_uid, 'general',
    '사용자 재확인 요청',
    '관리자 요청으로 사용자 확인이 초기화되었습니다. 에이전트 앱에서 다시 확인을 진행해주세요.'
  );

  RETURN jsonb_build_object('asset_uid', p_asset_uid, 'reset', true, 'requested_at', now());
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_force_verify(text) TO authenticated, service_role;
-- search_path = pg_catalog, public, auth, pg_temp (20260816000000에서 고정)
```

| 항목 | 값 |
|------|-----|
| 함수명 | `admin_force_verify` |
| 인자 | `p_asset_uid text` |
| 반환 | jsonb `{asset_uid, reset, requested_at}` |
| 권한 | `is_admin()` (admin role) |
| 부수효과 | `assets.verification_status=NULL`, `last_verified_at=NULL`, `specifications.user_mismatch` 제거, `notifications` INSERT 1건 |
| 호출 경로 | 프론트엔드 [자산 상세] → "관리자 재확인 요청" 버튼 |

### 9.9.2 마스터 관리자 user_name 변경 자동 트리거

마스터 관리자(`is_master_admin()=true`)가 `assets.user_name`을 변경하면 자동으로 `admin_force_verify`와 동일한 효과가 발생합니다.

```sql
CREATE OR REPLACE FUNCTION public.assets_master_user_change_trigger()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  IF NEW.user_name IS DISTINCT FROM OLD.user_name
     AND public.is_master_admin() THEN
    NEW.verification_status := NULL;
    NEW.last_verified_at    := NULL;
    NEW.specifications      := NEW.specifications - 'user_mismatch';

    INSERT INTO public.notifications (asset_uid, type, title, body)
    VALUES (NEW.asset_uid, 'general',
      '사용자 재확인 요청 (자동)',
      format('마스터 관리자가 실사용자를 %s → %s 으로 변경했습니다. 에이전트 앱에서 다시 사용자 확인을 진행해주세요.',
        COALESCE(OLD.user_name, '(미지정)'), COALESCE(NEW.user_name, '(미지정)'))
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_assets_master_user_change
  BEFORE UPDATE OF user_name ON public.assets
  FOR EACH ROW
  EXECUTE FUNCTION public.assets_master_user_change_trigger();
```

> 마스터 관리자 지정 자체는 클라이언트 `users` UPDATE가 아니라 `admin_set_master_admin` RPC로만 가능합니다 (9.12).
>
> **마스터 관리자 제약 트리거** (`enforce_master_admin_constraints`)
> - BEFORE INSERT/UPDATE OF `is_master_admin`, `role` ON public.users
> - role≠'admin' → 예외 `마스터 관리자는 role=admin 인 사용자만 지정 가능합니다`
> - 마스터 4명 이미 존재 시 5번째 지정 → 예외 `마스터 관리자는 최대 4명까지 지정 가능합니다`

### 9.10 실사 라운드 시작 RPC `start_inspection_round`

```sql
CREATE OR REPLACE FUNCTION public.start_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  -- 이미 active인 라운드가 있으면 차단
  IF EXISTS (SELECT 1 FROM public.inspection_rounds WHERE status = 'active') THEN
    RAISE EXCEPTION 'already_active: 이미 진행 중인 실사가 있습니다.';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'active', started_by = v_user_id, started_at = now(), updated_at = now()
  WHERE id = p_round_id AND status = 'draft'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: 라운드를 찾을 수 없거나 이미 시작된 상태입니다.';
  END IF;

  RETURN v_row;
END;
$$;
```

| 항목 | 설명 |
|------|------|
| 함수명 | `start_inspection_round` |
| 파라미터 | `p_round_id` (bigint) |
| 반환 | `inspection_rounds` 행 |
| 동작 | draft→active 전환, active 중복 차단 |
| 권한 | 관리자 그룹만 (`is_admin_group()`) |

### 9.11 실사 라운드 종료 RPC `close_inspection_round`

```sql
CREATE OR REPLACE FUNCTION public.close_inspection_round(p_round_id bigint)
RETURNS public.inspection_rounds
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.inspection_rounds;
  v_user_id bigint;
BEGIN
  IF NOT public.is_admin_group() THEN
    RAISE EXCEPTION 'forbidden: admin group only';
  END IF;

  SELECT id INTO v_user_id FROM public.users WHERE auth_uid = auth.uid();

  UPDATE public.inspection_rounds
  SET status = 'closed', closed_by = v_user_id, closed_at = now(), updated_at = now()
  WHERE id = p_round_id AND status = 'active'
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: 진행 중인 라운드를 찾을 수 없습니다.';
  END IF;

  RETURN v_row;
END;
$$;
```

| 항목 | 설명 |
|------|------|
| 함수명 | `close_inspection_round` |
| 파라미터 | `p_round_id` (bigint) |
| 반환 | `inspection_rounds` 행 |
| 동작 | active→closed 전환 |
| 권한 | 관리자 그룹만 (`is_admin_group()`) |

---

### 9.12 라운드 재오픈·삭제 RPC
| 함수 | 권한 | 동작 |
|------|------|------|
| `reopen_inspection_round(p_round_id)` | admin | closed → active 재오픈 (active 중복 불가) |
| `delete_inspection_round(p_round_id, p_force)` | admin | active 상태는 거부. 연결 실사 처리 옵션 `p_force` |

> `start_inspection_round`는 시작 시 모든 자산에 대해 실사 행을 자동 생성하고, 자산의 `inspection_round_no`를 라운드 번호로 맞춥니다 (`20260613000003`, `20260613000005`).

### 9.13 계정 관리 RPC
> **보안 실행서 기준**: 계정 생성·역할 변경·마스터 지정·비밀번호 초기화는 **마스터 관리자만** 수행하며, 임시 비밀번호는 서버가 무작위로 생성해 한 번만 안전한 별도 채널로 전달합니다. 예측 가능한 사번 기반 비밀번호는 허용하지 않습니다.

| 함수 | 실행서 기준 권한 | 현재 코드 권한 | 비고 |
|------|----------------|--------------|------|
| `admin_create_user_secure(employee_id, name, role, dept, email, password?)` | 마스터 | admin (admin 등급 생성은 마스터) | `password` 생략 시 서버가 `OA-<랜덤 24hex>` 생성. 입력 시 8자 이상 |
| `admin_reset_user_password_secure(employee_id)` | 마스터 | 마스터 | 무작위 임시 비밀번호 반환 |
| `admin_set_user_password(employee_id, new_password, force_change)` | 마스터 | admin (admin 계정 대상은 마스터) | 관리자가 비밀번호 직접 입력, `must_change_password` 설정 |
| `admin_update_user_role(employee_id, role)` | 마스터 | admin (admin 부여·admin 계정 변경은 마스터) | 마지막 마스터 해제 불가 |
| `admin_set_master_admin(employee_id, is_master)` | 마스터 | 마스터 | role=admin만, 최대 4명, 마지막 마스터 해제 불가 |
| `admin_update_user_profile(employee_id, …)` | — | admin (admin 계정 대상은 마스터) | 이름·부서·사번 수정, 로그인 이메일 동기화 |
| `admin_set_receipt_team(employee_id, team)` | — | admin | 인수증 서명 담당 지정 |
| `clear_must_change_password()` | 본인 | 본인 | 비밀번호 변경 후 강제 변경 플래그 해제 |

> **계정 직접 INSERT 주의**: `auth.users` 에 직접 INSERT 할 때는 `confirmation_token`, `recovery_token`, `email_change_token_new`, `email_change` 를 `''` 로 채워야 합니다(기본값 없음, NULL 이면 GoTrue 로그인 500). `admin_create_user_secure` 는 `20261011000001` 이후 이를 처리합니다.

> ⚠️ **보안 실행서 기준 미충족** (`20260922000003`~`20260922000005`에서 완화됨)
> - 계정 생성·역할 변경·비밀번호 설정이 마스터 전용에서 admin으로 완화되었습니다.
> - `admin_set_user_password`는 관리자가 입력한 비밀번호를 설정하며, `auth.users.banned_until`을 `NULL`로 되돌립니다. 이 때문에 `20260817000003`/`20260817000006`에서 차단한 시드 계정의 차단이 풀릴 수 있습니다.
> - **운영 결정 (2026-10-11 확인)**: 시드 계정 `admin01`, `oper01`, `user01`이 차단 해제된 채 사용 중인 것은 운영자가 **의도한 것**입니다(마지막 로그인: `user01`·`oper01` 9/28, `admin01` 10/6). 나머지 시드 계정(`temp01`, `agent`, `oper02`, `user02`~`user05`)은 차단 상태입니다.
> - 실행서 기준으로 맞추려면 위 함수들의 권한 검사를 `is_master_admin()`으로 되돌리고 `banned_until` 초기화를 제거하는 수정 마이그레이션이 필요합니다.
> - 이전 RPC `admin_reset_user_password(text)`, `admin_create_user(...)`는 `20260817000004`에서 삭제되었습니다.

---

## 10. 실시간 (Realtime)

### 10.1 Realtime 설정
Supabase Realtime을 사용하여 자산 상태 변경을 실시간으로 감지합니다.

```sql
-- Realtime 활성화 (Supabase Dashboard > Database > Replication)
-- 또는 SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE public.assets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.asset_inspections;
ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;  -- 마이그레이션 #21
```

> 모든 채널은 **private** 채널입니다. self-hosted Realtime의 `private_only` 설정은 compose 시작 명령에서 default tenant seed 뒤에 다시 적용합니다 (`20260817000001` 주석 참고). Postgres Changes로 전달되는 행은 각 테이블의 SELECT RLS(5장)를 따르므로, 일반 사용자는 배정 자산·참여 실사의 변경만 받습니다.

### 10.2 클라이언트 구독
```dart
// 자산 상태 변경 실시간 감지
final channel = supabase.channel('assets-realtime')
  .onPostgresChanges(
    event: PostgresChangeEvent.update,
    schema: 'public',
    table: 'assets',
    callback: (payload) {
      // 자산 상태가 변경되면 UI 갱신
      final updatedAsset = Asset.fromJson(payload.newRecord);
      ref.read(assetNotifierProvider.notifier).updateLocal(updatedAsset);
    },
  )
  .subscribe();

// 새 실사 기록 실시간 감지
final inspectionChannel = supabase.channel('inspections-realtime')
  .onPostgresChanges(
    event: PostgresChangeEvent.insert,
    schema: 'public',
    table: 'asset_inspections',
    callback: (payload) {
      // 새 실사 기록이 추가되면 목록 갱신
      ref.read(inspectionNotifierProvider.notifier).addLocal(payload.newRecord);
    },
  )
  .subscribe();
```

### 10.3 Broadcast 채널

Broadcast는 DB를 거치지 않는 **ephemeral 메시지** 채널입니다. 메시지는 실시간으로 전달되며 서버에 저장되지 않습니다.

#### 10.3.1 관리자 명령 채널 (`agent-commands:{asset_uid}`)
프론트엔드(관리자)에서 특정 기기 에이전트로 명령을 전송합니다.

| 방향 | 프론트엔드 → 에이전트 |
|------|----------------------|
| 채널 | `agent-commands:{asset_uid}` (자산별 개별 채널) |
| 이벤트 | `command` |

**메시지 포맷:**
```json
{
  "command": "request_heartbeat",
  "requested_by": "admin@oamanager.internal",
  "requested_at": "2026-03-14T09:05:00Z",
  "params": {}
}
```

| command | 설명 |
|---------|------|
| `request_heartbeat` | 에이전트가 즉시 Heartbeat 전송 |
| `refresh_system_info` | 에이전트가 시스템 정보 즉시 수집 후 전송 |

#### 10.3.2 운영 알림 채널 (`agent-alerts:global`)
관리자 그룹 전용 수신 채널입니다. 프론트엔드는 관리자 그룹 로그인 시에만 구독합니다.

| 방향 | (예약) → 관리자 그룹 프론트엔드 |
|------|----------------------|
| 채널 | `agent-alerts:global` |
| 이벤트 | `alert` |
| 수신 권한 | 관리자 그룹만 (`oa_realtime_alerts_read_admin`) |
| 발신 권한 | 정책 없음 — 에이전트는 전역 Broadcast를 발신·구독하지 않음 |

> 배터리·네트워크 등 기기 상태는 전역 Broadcast가 아니라 인증된 Heartbeat RPC(9.6)에 포함해 전달하는 것이 기준입니다.

### 10.4 Presence 채널

Presence는 클라이언트의 **실시간 접속 상태**를 추적하는 기능입니다. 연결 해제 시 자동으로 상태가 제거됩니다.

#### 채널: `agent-presence:global`

| 방향 | 에이전트 → 프론트엔드 |
|------|----------------------|
| 용도 | 에이전트 실시간 접속 여부 추적 |
| 이벤트 | `sync`, `join`, `leave` |

**Presence 상태 스키마** (최소 정보만 — 사용자·기기 정보 추가 금지):
```json
{
  "asset_uid": "D00001"
}
```

| 이벤트 | 발생 시점 | 설명 |
|--------|----------|------|
| `join` | 에이전트 WebSocket 연결 + 채널 참여 | 프론트엔드에서 "실시간 연결됨" 표시 |
| `leave` | 에이전트 WebSocket 끊김 (앱 종료, 네트워크 단절) | 프론트엔드에서 "연결 해제" 전환 |
| `sync` | 프론트엔드 채널 참여 시 | 현재 접속 중인 전체 에이전트 목록 수신 |

> **DB 저장 불필요**: Presence는 Supabase Realtime 서버 메모리에서만 관리되며 PostgreSQL에 저장되지 않습니다.

### 10.5 Realtime 인증 및 보안
> 최종 정의: `20260817000001_scope_realtime_and_assigned_data.sql` §3. 모든 정책은 `realtime.messages`에 적용되며 `auth_banned_account_block`(5.1)과 함께 평가됩니다.

| 채널 | 읽기(참여) | 쓰기 |
|------|-----------|------|
| `assets-realtime`, `inspections-realtime` | 인증 사용자 (행 전달은 테이블 RLS 기준) | — |
| `notifications:{asset_uid}` | 해당 자산 담당자 | — |
| `agent-presence:global` | 관리자 그룹 또는 배정 자산이 있는 사용자 | Presence: 배정 자산이 있는 사용자 |
| `agent-commands:{asset_uid}` | 해당 자산 담당자 | Broadcast: 관리자 그룹 |
| `agent-alerts:global` | 관리자 그룹 | — |

| 항목 | 설명 |
|------|------|
| 인증 방식 | 사용자 개인 JWT (`access_token`) |
| 공용 에이전트 계정 | **사용 금지** — `employee_id='agent'` 계정은 차단(banned) + `legacy_agent_block` 대상 |
| 에이전트 인증 | 자산 담당자 또는 관리자의 개인 OA 계정 (Agent README §4.2) |
| 토픽 형식 | `prefix:{asset_uid}` — 세 번째 `:` 구간이 있으면 거부 |

### 10.6 채널 명명 규칙

| 패턴 | 예시 | 설명 |
|------|------|------|
| `agent-presence:global` | `agent-presence:global` | 전체 에이전트 접속 상태 (단일 채널) |
| `agent-commands:{asset_uid}` | `agent-commands:D00001` | 특정 기기 에이전트 명령 채널 |
| `agent-alerts:global` | `agent-alerts:global` | 관리자 그룹 운영 알림 수신 (단일 채널) |
| `notifications:{asset_uid}` | `notifications:D00001` | 에이전트의 `notifications` INSERT 구독 |

> **Postgres Changes 채널**: 프론트엔드는 `assets-realtime`, `inspections-realtime` 이름만 사용합니다 (Realtime 정책이 이 두 토픽만 허용).

---

## 11. 에러 처리

### 11.1 PostgREST 에러 응답 포맷
```json
{
  "code": "PGRST116",
  "details": null,
  "hint": null,
  "message": "The result contains 0 rows"
}
```

### 11.2 HTTP 상태 코드 매핑
> 프론트엔드 명세 12.1 기반

| HTTP 상태 | PostgREST 원인 | 프론트엔드 처리 |
|-----------|---------------|--------------|
| 200 OK | 정상 응답 | 데이터 표시 |
| 201 Created | INSERT 성공 | 생성 완료 |
| 204 No Content | DELETE 성공 | 삭제 완료 |
| 400 Bad Request | CHECK 제약 위반, 잘못된 쿼리 | 필드별 에러 메시지 |
| 401 Unauthorized | 인증 필요 API에 JWT 없음/만료/무효 | 토큰 갱신 시도 → 실패 시 로그인 |
| 403 Forbidden | RLS 정책 거부 | "접근 권한이 없습니다" |
| 404 Not Found | 레코드 없음 | "데이터를 찾을 수 없습니다" |
| 409 Conflict | UNIQUE 제약 위반 | "이미 존재하는 자산번호입니다" |
| 500 Server Error | 서버 내부 오류 | "서버 오류가 발생했습니다" |

### 11.3 Dart 클라이언트 에러 핸들링
```dart
try {
  final response = await supabase.from('assets').insert(data).select().single();
} on PostgrestException catch (e) {
  // PostgREST 에러
  switch (e.code) {
    case '23505': // unique_violation
      showSnackBar('이미 존재하는 자산번호입니다');
    case '23503': // foreign_key_violation
      showSnackBar('참조하는 데이터가 존재하지 않습니다');
    case '23514': // check_violation
      showSnackBar('입력값이 허용 범위를 벗어났습니다');
    default:
      showSnackBar('오류가 발생했습니다: ${e.message}');
  }
} on AuthException catch (e) {
  // 인증 에러
  if (e.statusCode == '401') {
    router.go('/login');
  }
}
```

---

## 12. 배포 및 환경

### 12.1 환경 분리
| 환경 | Supabase 프로젝트 | 용도 |
|------|-----------------|------|
| Local | `supabase start` (Docker) | 개발/디버깅 |
| Staging | 별도 Supabase 프로젝트 | QA 테스트 |
| Production | 메인 Supabase 프로젝트 | 서비스 운영 |

### 12.2 마이그레이션 관리
```bash
supabase/
├── migrations/                                   # 총 60건
│   ├── 20240201000000_create_users.sql          # #1  users 테이블
│   ├── 20240201000001_create_drawings.sql        # #2  drawings 테이블
│   ├── 20240201000002_create_assets.sql          # #3  assets + specifications
│   ├── 20240201000003_create_inspections.sql     # #4  asset_inspections
│   ├── 20240201000004_create_rls_policies.sql    # #5  초기 RLS (이후 보안 마이그레이션으로 대체)
│   ├── 20240201000005_create_storage.sql         # #6  Storage 버킷
│   ├── 20240201000006_create_functions_triggers.sql # #7 updated_at, asset_uid 검증, 실사 횟수, Auth 동기화
│   ├── 20240201000007_create_rpc_functions.sql   # #8  is_admin, get_expiring_assets
│   ├── 20240201000008_enable_realtime.sql        # #9  Realtime (assets, inspections)
│   ├── 20260211000000_add_asset_party_fields.sql # #10 담당정보 필드
│   ├── 20260211000001_asset_uid_format_alignment.sql # #11 asset_uid 형식 병기 (이후 #32에서 정리)
│   ├── 20260211000002_inspection_permissions_and_reset.sql # #12 완료건 권한 + reset_inspection
│   ├── 20260211000003_add_access_status.sql      # #13 last_active_at + access_settings
│   ├── 20260314000000_add_agent_tables.sql       # #14 device_tokens, notifications, agent_settings
│   ├── 20260314000001_add_agent_rls_policies.sql # #15 에이전트 테이블 RLS
│   ├── 20260314000002_add_agent_rpc_and_columns.sql # #16 update_heartbeat, verify_user, confirm_assignment
│   ├── 20260321000000_fix_inspection_update_rls.sql # #17 완료 전환 WITH CHECK
│   ├── 20260321000001_add_user_role.sql          # #18 role + is_admin_group()
│   ├── 20260321000002_create_inspection_rounds.sql # #19 실사 라운드 + RPC
│   ├── 20260321000003_add_round_to_inspections.sql # #20 round_id
│   ├── 20260604000000_master_admin_and_force_verify.sql # #21 마스터 관리자, admin_force_verify, notifications Realtime
│   ├── 20260605000000_fix_verify_user_use_asset_employee_id.sql # #22 verify_user → assets.user_employee_id 비교
│   ├── 20260613000000_assets_search_indexes.sql  # #23 pg_trgm 검색 인덱스
│   ├── 20260613000001_inspection_locking_and_round_reopen.sql # #24 실사 locked + 라운드 재오픈
│   ├── 20260613000002_assets_inspection_round_no.sql # #25 assets.inspection_round_no
│   ├── 20260613000003_asset_round_follow_active.sql # #26 회차 번호가 활성 라운드를 따라감
│   ├── 20260613000004_delete_inspection_round.sql # #27 delete_inspection_round
│   ├── 20260613000005_round_start_autocreate_inspections.sql # #28 라운드 시작 시 실사 자동 생성
│   ├── 20260614000000_inspection_flat_view.sql   # #29 asset_inspections_with_asset view (security_invoker)
│   ├── 20260614000001_expand_supply_type_options.sql # #30 supply_type 9종
│   ├── 20260614000002_drop_assets_status.sql     # #31 assets_status 삭제
│   ├── 20260614000003_drop_new_uid_format.sql    # #32 asset_uid 옛 형식만 허용 (#57에서 병행 허용으로 변경)
│   ├── 20260614000004_inspection_complete_date_and_recheck.sql # #33 완료일 + 재실사 요청 알림
│   ├── 20260614000005_view_add_round_info.sql    # #34 view에 라운드 정보
│   ├── 20260614000006_admin_user_management.sql  # #35 (레거시 계정 RPC — #44에서 삭제)
│   ├── 20260614000007_add_admin_affiliation.sql  # #36 assets.admin_affiliation
│   ├── 20260614000008_admin_company_and_mac_sync.sql # #37 admin_company + heartbeat MAC 동기화
│   ├── 20260615000000_dropdown_options.sql       # #38 dropdown_options
│   ├── 20260816000000_security_hardening.sql     # #39 ★ 익명 노출 제거·최소 권한 (보안 실행서)
│   ├── 20260817000000_lock_drawing_images_private.sql # #40 도면 버킷 private
│   ├── 20260817000001_scope_realtime_and_assigned_data.sql # #41 private Realtime + 담당 범위 조회
│   ├── 20260817000002_restrict_unassigned_inspection_claims.sql # #42 배정 자산만 실사 claim
│   ├── 20260817000003_emergency_account_and_data_containment.sql # #43 시드 계정 차단 + 차단 계정 RESTRICTIVE
│   ├── 20260817000004_remove_legacy_password_rpcs.sql # #44 레거시 비밀번호 RPC 삭제
│   ├── 20260817000005_active_gate_security_definer_helpers.sql # #45 헬퍼 함수에 활성 계정 검사
│   ├── 20260817000006_finite_seed_account_bans.sql # #46 ban 시각을 유한값으로 (GoTrue 호환)
│   ├── 20260922000000_add_receipts.sql           # #47 인수증 (vendors, receipts, receipt_items)
│   ├── 20260922000001_grant_receipts.sql         # #48 인수증 테이블 GRANT
│   ├── 20260922000002_receipts_add_sender.sql    # #49 발송업체
│   ├── 20260922000003_receipt_signers_and_user_admin.sql # #50 서명 담당, must_change_password, 계정 RPC 개편
│   ├── 20260922000004_admin_update_user_profile.sql # #51 사용자 프로필 수정
│   ├── 20260922000005_user_id_edit_and_receipt_delete.sql # #52 사번 수정 + 인수증 삭제 admin
│   ├── 20260929000000_menu_permissions.sql       # #53 메뉴 권한
│   ├── 20260929000001_receipts_receiver_company.sql # #54 인수업체
│   ├── 20260929000002_receipts_sender_manager.sql # #55 발송담당자
│   ├── 20260929000003_receipt_items_amount.sql   # #56 항목 금액
│   ├── 20261011000000_allow_both_uid_formats.sql # #57 asset_uid 현재기준 + 변경후 병행 허용
│   ├── 20261011000001_fix_auth_user_token_columns.sql # #58 auth.users 토큰 NULL 로 인한 로그인 500 수정
│   ├── 20261011000002_expand_asset_category.sql # #59 category CHECK 14종 (라이브 기반영분 저장소 동기화)
│   └── 20261011000003_receipts_rls_admin_group.sql # #60 인수증 관리자 그룹 전용 + RESTRICTIVE 정책
├── functions/
│   ├── auth-kakao/index.ts                       # 8.2 카카오 로그인 (사전 연결 계정만)
│   ├── dashboard-stats/index.ts                  # 8.3 대시보드 통계 (관리자 그룹)
│   ├── expiring-assets/index.ts                  # 8.4 만료 임박 자산 (관리자 그룹)
│   ├── main/index.ts                             # 8.1 dispatcher (send-notification inline)
│   └── send-notification/index.ts                # 8.5 (main에 inline된 원본)
├── seed.sql                                      # 계정·비밀번호를 만들지 않는 production-safe seed
├── dummy_data.sql
└── config.toml
```

```bash
# 로컬 → 원격 배포
supabase db push           # 마이그레이션 적용
supabase functions deploy   # Edge Functions 배포

# 원격 스키마 → 로컬 반영
supabase db pull            # 원격 스키마를 마이그레이션으로 생성
```

### 12.3 환경별 클라이언트 설정
```dart
// Flutter 환경별 설정
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'http://localhost:54321',  // 로컬 개발
  );
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJ...',  // 로컬 개발 키
  );
}
```

---

## 13. 테스트

### 13.1 SQL 테스트
```sql
-- 자산 등록 테스트
INSERT INTO public.assets (
  asset_uid, name, category, supply_type,
  owner_name, owner_department, user_name, user_department, admin_name, admin_department
)
VALUES (
  'D00001', '테스트 자산', '데스크탑', '지급',
  '홍길동', '경영지원팀', '김개발', '개발팀', '박관리', 'IT운영팀'
);

-- asset_uid 형식 검증 테스트 (실패가 정상)
INSERT INTO public.assets (asset_uid, name, category)
VALUES ('XDT00001', '형식 오류 테스트', '모니터');  -- 등록경로 X는 허용 안 됨
-- 예상: CHECK 또는 validate_asset_uid 트리거 위반 오류

-- updated_at 트리거 테스트
UPDATE public.assets SET name = '수정됨' WHERE asset_uid = 'D00001';
SELECT updated_at FROM public.assets WHERE asset_uid = 'D00001';
-- 예상: updated_at이 현재 시각으로 갱신

-- RLS 테스트 (실사 기록 있는 자산 삭제 거부)
INSERT INTO public.asset_inspections (asset_id, asset_code, inspector_name)
VALUES (1, 'D00001', '테스트');
DELETE FROM public.assets WHERE asset_uid = 'D00001';
-- 예상: RLS 정책에 의해 삭제 거부

-- 만료 임박 자산 조회 테스트
INSERT INTO public.assets (asset_uid, name, category, supply_type, supply_end_date)
VALUES ('N00002', '렌탈 자산', '노트북', '렌탈', now() + INTERVAL '3 days');
SELECT * FROM public.assets
WHERE supply_type IN ('렌탈', '대여')
  AND supply_end_date <= CURRENT_DATE + INTERVAL '7 days';
-- 예상: N00002 포함

-- 실사 완료 기준 테스트 (완료건)
UPDATE public.asset_inspections
SET
  inspection_building = '본관',
  inspection_floor = '3F',
  inspection_position = 'A-3',
  inspection_photo = '<auth_uid>/1/photos/D00001_detail_1700000000_1.jpg',
  signature_image = '<auth_uid>/1/signatures/1_sig_1700000000_1.png'
WHERE id = 1;

-- 실사 초기화 RPC 테스트 (관리자 토큰 컨텍스트에서 실행)
SELECT public.reset_inspection(1, '재실사 필요');
-- 예상: status/memo/photo/signature 초기화, synced=false
```

### 13.2 Edge Function 테스트
```bash
# 로컬 Edge Function 실행
supabase functions serve auth-kakao --env-file .env.local

# 테스트 호출
curl -X POST http://localhost:54321/functions/v1/dashboard-stats \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json"
```

### 13.3 API 통합 테스트 체크리스트
> 프론트엔드 명세 18장과 대응

| # | 테스트 | 검증 항목 |
|---|--------|----------|
| 1 | 일반 로그인 | 사번+비밀번호 → JWT 발급, users 정보 반환 |
| 2 | 구글 로그인 | OAuth → JWT 발급, users 정보 매칭 |
| 3 | 카카오 로그인 | Edge Function → JWT 발급, users 정보 매칭 |
| 4 | 토큰 갱신 | 만료된 Access Token → Refresh → 새 토큰 발급 |
| 5 | 로그아웃 | signOut → 세션 무효화 |
| 6 | 자산 등록 | INSERT → asset_uid 형식 검증 후 저장, specifications JSONB 저장 |
| 7 | 자산 목록 조회 | 필터/검색/페이지네이션 (30건 단위) |
| 8 | 자산 수정 | UPDATE → updated_at 자동 갱신 |
| 9 | 자산 삭제 | DELETE (실사 기록 없을 때), 삭제 거부 (실사 기록 있을 때) |
| 10 | 실사 기록 생성 | 라운드 시작 → 전 자산 실사 행 자동 생성, inspection_count 자동 증가 |
| 11 | 실사 상세 조회 | `GET /api/inspections/:id` 응답에 사용자명/부서 + completed 계산 포함 |
| 12 | 실사 완료건 수정 제한 | 일반사용자 `PUT /api/inspections/:id` 시 완료·잠금건은 거부 |
| 13 | 실사 초기화 | `POST /api/inspections/:id/reset` 관리자 성공, 일반사용자 403 |
| 14 | 실사 사진 업로드 | Storage 업로드 → URL 반환 |
| 15 | 서명 이미지 업로드 | Storage 업로드 → URL 반환 |
| 16 | 도면 등록 | INSERT + Storage 이미지 업로드 |
| 17 | 도면 내 자산 조회 | location_drawing_id 기반 필터 |
| 18 | 대시보드 통계 | Edge Function → 총 자산/실사율/미검증 수 |
| 19 | 만료 임박 자산 | supply_end_date D-7 이내 조회 |
| 20 | RLS 접근 제어 | 익명 키만으로 테이블·Storage·RPC 읽기/쓰기 모두 거부. 일반 사용자는 배정 자산·참여 실사만 조회 |
| 21 | Realtime 구독 | 자산 상태 변경 → WebSocket 이벤트 수신 |
| 22 | 에이전트 RPC 차단 | `update_heartbeat`/`verify_user`/`confirm_assignment`를 `authenticated`로 호출 시 실행 권한 없음 오류 (의도된 차단, 9.6) |
| 23 | 공용 에이전트 계정 차단 | `employee_id='agent'` 계정 로그인·자산 조회·RPC 모두 실패 |
| 24 | 차단 계정 JWT 무력화 | banned 처리된 계정의 기존 access token으로 조회 시 0건/거부 |
| 25 | 실사 claim 제한 | 일반 사용자가 배정되지 않은 자산의 실사 수정 시 `forbidden: inspection asset is not assigned to caller` |
| 26 | Storage 경로 강제 | 일반 사용자가 본인 UUID 폴더가 아닌 경로로 사진·서명 업로드 시 거부 |
| 27 | 에이전트 버전 조회 | agent_settings 테이블에서 latest/min 버전 조회 |
| 28 | 관리자 강제 재확인 | `admin_force_verify(asset_uid)` RPC → assets 상태 리셋 + notifications INSERT |
| 29 | 마스터 관리자 자동 재확인 | 마스터가 `assets.user_name` UPDATE → BEFORE UPDATE 트리거가 자동으로 #28과 동일 효과 |
| 30 | 마스터 관리자 토글 | 프론트 [설정] → `admin_set_master_admin` RPC (마스터만, 최대 4명, role=admin 한정, 마지막 마스터 해제 불가) |
| 31 | Realtime 토픽 권한 | 일반 사용자가 남의 `agent-commands:{uid}`·`notifications:{uid}` 참여 시 거부, `agent-alerts:global`은 관리자 그룹만 |

---

## 변경 이력 (백엔드)

- `2026-10-11` : #59 category CHECK 14종(저장소 동기화), #60 인수증 관리자 그룹 전용 + RESTRICTIVE 정책 4개 테이블. 설치 SW 인벤토리 계획 확정(`docs/software_inventory_spec.md`, 테이블 `asset_software` 예정)
- `2026-10-11` : 마이그레이션 #58 — `admin_create_user_secure` 가 만든 계정이 `auth.users` 토큰 컬럼 NULL 때문에 로그인 500(`converting NULL to string`)이 나던 문제 수정 (기존 3개 계정 복구 + 함수가 빈 문자열로 INSERT)
- `2026-10-11` : 마이그레이션 #57 — asset_uid 두 형식 병행 허용 (현재기준 `D00001` + 변경후 `BDT00001`)
- `2026-10-11` : 명세를 실제 마이그레이션(56건)·보안 실행서 기준으로 정비 — asset_uid 현재 형식(`^[A-Z]{1,2}[0-9]{4,5}$`), RLS/Storage/Realtime 최종 정책, 에이전트 RPC 차단 상태, 계정 관리 RPC와 실행서 미충족 항목(5.10, 9.13) 명시, FCM 기술 제거
- `2026-09-22 ~ 09-29` : 인수증(vendors/receipts/receipt_items), 사용자 관리 RPC 개편(must_change_password, 프로필·사번 수정), 메뉴 권한(menu_permissions)
- `2026-08-16 ~ 08-17` : 보안 강화 — 익명 노출 제거, 최소 권한 RLS, 도면 버킷 private, private Realtime, 공용 에이전트·시드 계정 차단, 차단 계정 RESTRICTIVE 정책, 레거시 비밀번호 RPC 삭제
- `2026-06-05 ~ 06-15` : verify_user 사번 비교 수정, 검색 인덱스, 실사 잠금·라운드 재오픈/삭제·자동 생성, 실사 평탄 view, supply_type 확장, assets_status 삭제, asset_uid 옛 형식만 허용, 재실사 요청 알림, 담당자 소속/회사, heartbeat MAC 동기화, dropdown_options
- `2026-06-04` :
  - **마이그레이션 #21** 추가 (`20260604000000_master_admin_and_force_verify.sql`)
    - `users.is_master_admin` 컬럼 + `enforce_master_admin_constraints` 트리거 (max 4 + role=admin)
    - `is_master_admin()`, `admin_force_verify(asset_uid)` 함수
    - `assets_master_user_change_trigger` (BEFORE UPDATE OF user_name)
    - `ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications`
  - 과거 정적 시드 계정은 폐기되었으며, 신규 환경에는 기본 로그인 자격증명을 만들지 않음
  - Edge Function `main`을 단일 진입 dispatcher로 재구성 (self-hosted edge-runtime의 cross-function import 제약 우회). `send-notification` 로직을 main에 inline. Firebase 의존 코드는 보존하되 트리거에서는 호출하지 않음 (Realtime로 대체)
- `2026-03-21` : 역할 체계 + 실사 라운드(차수)
- `2026-03-14` : 에이전트 테이블 (heartbeat, agent_settings, device_tokens, notifications)
- `2026-02-11` : 자산 담당정보 필드, asset_uid 정규식, 실사 권한/초기화 RPC

---

## 문의
프로젝트 관련 문의사항은 개발팀에 문의해주세요.
