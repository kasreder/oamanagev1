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
| 인증/인가 | JWT 기반 인증, SNS 로그인 (카카오/구글), RLS 보안 |
| 자산 CRUD | 자산 등록/조회/수정/삭제, 유형별 specifications JSONB 관리 |
| 실사 관리 | 실사 기록 CRUD, 사진/서명 파일 저장 |
| 도면 관리 | 도면 이미지 업로드/조회, 격자 좌표 기반 자산 위치 관리 |
| 대시보드 통계 | 자산 현황 집계, 만료 임박 자산 조회, 실사 진행률 |
| 오프라인 동기화 | synced 필드 기반 동기화 상태 관리, 충돌 해결 (Server Wins) |

### 1.3 기술 스택
| 구분 | 기술 |
|------|------|
| BaaS | **Supabase** (PostgreSQL 15+) |
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

### 2.5 이번 변경 적용 (asset_uid 규칙 정렬)
```bash
# 1) 마이그레이션 파일 위치
# OA_backend/supabase/migrations/20260211_asset_uid_format_alignment.sql

# 2) 로컬 반영
supabase db reset

# 3) 원격 반영
supabase db push
```

```sql
-- 배포 후 legacy UID 점검
SELECT id, asset_uid
FROM public.assets
WHERE asset_uid !~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$';

-- legacy 데이터 정리 완료 후 제약 검증
ALTER TABLE public.assets VALIDATE CONSTRAINT chk_assets_asset_uid_format;
```

---

## 3. 인증 (Authentication)

### 3.1 인증 방식
Supabase Auth 내장 JWT 기반 인증을 사용합니다.

| 항목 | 설명 |
|------|------|
| 인증 방식 | JWT (JSON Web Token) — Supabase Auth 자동 관리 |
| 일반 로그인 | 사번(employee_id) + 비밀번호 → `signInWithPassword()` |
| SNS 로그인 | 카카오 OAuth, 구글 OAuth → `signInWithOAuth()` |
| Access Token 만료 | 1800초 (30분, 프론트엔드 명세 11.3 기준) |
| Refresh Token 만료 | 7일 |
| 토큰 자동 갱신 | `supabase_flutter` SDK 자동 처리 |

### 3.2 일반 로그인 (사번 + 비밀번호)

Supabase Auth는 기본적으로 이메일 로그인을 사용합니다. 사번 기반 로그인을 구현하기 위해 **사번을 이메일 형태로 변환**합니다.

```
사번: EMP-2024-042 → 이메일: EMP-2024-042@oamanager.internal
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
    "employee_id": "EMP-2024-042",
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
| Access Token 만료 | 1800초 (30분) | Dashboard > Auth > Settings에서 변경 (프론트엔드 11.3 기준) |
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
  └── 1:N → asset_inspections.asset_id

asset_inspections (실사 기록)
  ├── N:1 → assets.id (asset_id FK)
  └── N:1 → users.id (user_id FK)

drawings (도면 정보)
  └── 1:N → assets.location_drawing_id
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
  created_at    timestamptz DEFAULT now(),
  updated_at    timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_users_auth_uid ON public.users(auth_uid);
CREATE INDEX idx_users_employee_id ON public.users(employee_id);
```

> **참고**: 비밀번호는 Supabase Auth(`auth.users`)에서 관리하며, `public.users`에는 저장하지 않습니다. `auth_uid`로 Supabase Auth 계정과 연결합니다.

### 4.3 assets (자산 정보)
> 프론트엔드 명세 8.1 기반

```sql
CREATE TABLE public.assets (
  id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  asset_uid     text UNIQUE NOT NULL                                 -- 자산 고유 코드 (QR 매칭 키)
    CHECK (asset_uid ~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$'),
  name          text,                                                -- 자산 명칭 또는 사용자
  assets_status text DEFAULT '가용'                                   -- 자산현재진행상태
    CHECK (assets_status IN ('사용', '가용', '이동', '점검필요', '고장')),
  supply_type   text DEFAULT '지급'                                   -- 자산지급형태
    CHECK (supply_type IN ('지급', '렌탈', '대여', '창고(대기)', '창고(점검)')),
  supply_end_date timestamptz,                                       -- 대여/렌탈 만료일
  category      text NOT NULL                                        -- 자산 분류
    CHECK (category IN ('데스크탑', '모니터', '노트북', 'IP전화기', '스캐너', '프린터', '태블릿', '테스트폰')),
  serial_number  text,                                               -- 시리얼 번호
  model_name     text,                                               -- 모델명
  vendor         text,                                               -- 제조사
  network        text,                                               -- 네트워크 구분
  physical_check_date timestamptz,                                   -- 실물 점검일
  confirmation_date   timestamptz,                                   -- 관리자 확인일
  normal_comment text,                                               -- 일반 메모
  oa_comment     text,                                               -- OA 관련 메모
  mac_address    text,                                               -- MAC 주소
  building1      text,                                               -- 사용자 유형 (내부/외부 등)
  building       text,                                               -- 건물명
  floor          text,                                               -- 층 정보
  member_name    text,                                               -- 관리자 이름
  location_drawing_id bigint REFERENCES public.drawings(id)
    ON DELETE SET NULL,                                              -- 도면 FK
  location_row   int,                                                -- 도면 좌표 (행)
  location_col   int,                                                -- 도면 좌표 (열)
  location_drawing_file text,                                        -- 도면 파일명
  user_id        bigint REFERENCES public.users(id)
    ON DELETE SET NULL,                                              -- 자산 담당 사용자 FK
  specifications jsonb DEFAULT '{}'::jsonb,                          -- 유형별 추가 사양 (하이브리드)
  created_at     timestamptz DEFAULT now(),
  updated_at     timestamptz DEFAULT now()
);

-- 인덱스
CREATE INDEX idx_assets_asset_uid ON public.assets(asset_uid);
CREATE INDEX idx_assets_category ON public.assets(category);
CREATE INDEX idx_assets_status ON public.assets(assets_status);
CREATE INDEX idx_assets_supply_type ON public.assets(supply_type);
CREATE INDEX idx_assets_building ON public.assets(building);
CREATE INDEX idx_assets_user_id ON public.assets(user_id);
CREATE INDEX idx_assets_supply_end_date ON public.assets(supply_end_date)
  WHERE supply_type IN ('렌탈', '대여');  -- 만료 임박 조회용 부분 인덱스
CREATE INDEX idx_assets_drawing ON public.assets(location_drawing_id);
CREATE INDEX idx_assets_specifications ON public.assets
  USING gin(specifications);             -- JSONB 검색용 GIN 인덱스
```

> **설계 방침**: 프론트엔드 명세 8.1과 동일합니다. 공통 항목은 컬럼, 유형별 추가 사양은 `specifications` JSONB에 저장합니다.
> **asset_uid 규칙**: `등록경로(1자리) + 등록장비(2자리) + 숫자 5자리` 형식을 사용합니다.

| 등록경로 | 코드 |
|------|------|
| Buy | `B` |
| Rental | `R` |
| Contact | `C` |
| Lease | `L` |
| Spot | `S` |

| 등록장비 | 코드 |
|------|------|
| DeskTop (iMac 포함) | `DT` |
| NoteBook | `NB` |
| MoNitor | `MN` |
| PRinter | `PR` |
| TaBlet | `TB` |
| SCanner | `SC` |
| IP Phone | `IP` |
| NetWork | `NW` |
| SerVer | `SV` |
| Wearable | `WR` |
| SpecialDevice | `SD` |

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
  inspection_date  timestamptz DEFAULT now(),                        -- 실사 일시
  maintenance_company_staff text,                                    -- 유지보수 담당자
  department_confirm text,                                           -- 확인 부서
  inspection_building  text,                                         -- 실사 확인 건물명
  inspection_floor     text,                                         -- 실사 확인 층
  inspection_position  text,                                         -- 실사 확인 자리번호 (예: "A-3")
  status        text,                                                -- 자산 상태 (assets 상태와 동기화)
  memo          text,                                                -- 점검 메모
  inspection_photo text,                                             -- 사진 파일 Storage 경로
  signature_image  text,                                             -- 서명 파일 Storage 경로
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

### 4.6 drawings (도면 정보)
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

### 4.7 테이블 생성 순서
FK 의존성을 고려한 생성 순서:
1. `users` (의존 없음)
2. `drawings` (의존 없음)
3. `assets` (→ users, drawings 참조)
4. `asset_inspections` (→ assets, users 참조)

---

## 5. Row Level Security (RLS)
> 정책 기준(프론트엔드와 동일):
> - `GET` 조회 API: 비인증(`anon`) + 인증(`authenticated`) 허용
> - `POST`/`PUT`/`DELETE`: 인증(`authenticated`)만 허용

### 5.1 RLS 활성화
```sql
-- 모든 테이블 RLS 활성화
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.asset_inspections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drawings ENABLE ROW LEVEL SECURITY;
```

### 5.2 users 정책
```sql
-- 비인증 포함: 전체 목록/상세 조회 가능 (GET 정책)
CREATE POLICY "users_select" ON public.users
  FOR SELECT TO anon, authenticated
  USING (true);

-- 본인 정보만 수정 가능
CREATE POLICY "users_update_own" ON public.users
  FOR UPDATE TO authenticated
  USING (auth_uid = auth.uid())
  WITH CHECK (auth_uid = auth.uid());
```

### 5.3 assets 정책
```sql
-- 비인증 포함: 전체 자산 조회 가능 (GET 정책)
CREATE POLICY "assets_select" ON public.assets
  FOR SELECT TO anon, authenticated
  USING (true);

-- 인증된 사용자: 자산 등록
CREATE POLICY "assets_insert" ON public.assets
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 인증된 사용자: 자산 수정
CREATE POLICY "assets_update" ON public.assets
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- 인증된 사용자: 자산 삭제 (관련 실사 기록 없는 경우만)
CREATE POLICY "assets_delete" ON public.assets
  FOR DELETE TO authenticated
  USING (
    NOT EXISTS (
      SELECT 1 FROM public.asset_inspections
      WHERE asset_id = assets.id
    )
  );
```
> **주의**: 실사 기록이 존재하는 자산은 삭제할 수 없습니다. 프론트엔드에서 삭제 시도 시 경고를 표시합니다 (프론트엔드 명세 4.1.4 참고).

### 5.4 asset_inspections 정책
```sql
-- 비인증 포함: 전체 실사 기록 조회 가능 (GET 정책)
CREATE POLICY "inspections_select" ON public.asset_inspections
  FOR SELECT TO anon, authenticated
  USING (true);

-- 인증된 사용자: 실사 기록 생성
CREATE POLICY "inspections_insert" ON public.asset_inspections
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- 인증된 사용자: 실사 기록 수정
CREATE POLICY "inspections_update" ON public.asset_inspections
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

-- 인증된 사용자: 실사 기록 삭제
CREATE POLICY "inspections_delete" ON public.asset_inspections
  FOR DELETE TO authenticated
  USING (true);
```

### 5.5 drawings 정책
```sql
-- 비인증 포함: 전체 도면 조회 가능 (GET 정책)
CREATE POLICY "drawings_select" ON public.drawings
  FOR SELECT TO anon, authenticated
  USING (true);

-- 인증된 사용자: 도면 등록/수정/삭제
CREATE POLICY "drawings_insert" ON public.drawings
  FOR INSERT TO authenticated
  WITH CHECK (true);

CREATE POLICY "drawings_update" ON public.drawings
  FOR UPDATE TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "drawings_delete" ON public.drawings
  FOR DELETE TO authenticated
  USING (true);
```

---

## 6. Storage (파일 저장)

### 6.1 버킷 구성
```sql
-- 버킷 생성 (Supabase Dashboard 또는 SQL)
INSERT INTO storage.buckets (id, name, public)
VALUES
  ('inspection-photos', 'inspection-photos', false),
  ('inspection-signatures', 'inspection-signatures', false),
  ('drawing-images', 'drawing-images', false);
```

| 버킷 | 용도 | 허용 MIME | 최대 크기 |
|------|------|----------|----------|
| `inspection-photos` | 실사 사진 | image/jpeg, image/png | 10MB |
| `inspection-signatures` | 친필 서명 | image/png | 2MB |
| `drawing-images` | 도면 이미지 | image/jpeg, image/png, application/pdf | 20MB |

### 6.2 파일 경로 규칙
```
inspection-photos/{inspection_id}/{filename}.jpg
inspection-signatures/{inspection_id}/signature.png
drawing-images/{drawing_id}/{filename}.png
```

### 6.3 Storage RLS 정책
```sql
-- inspection-photos: 조회는 비인증 포함 허용, 업로드/수정/삭제는 인증 필요
CREATE POLICY "inspection_photos_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-photos');

CREATE POLICY "inspection_photos_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-photos');

-- inspection-signatures: 동일
CREATE POLICY "inspection_signatures_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'inspection-signatures');

CREATE POLICY "inspection_signatures_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'inspection-signatures');

-- drawing-images: 동일
CREATE POLICY "drawing_images_select" ON storage.objects
  FOR SELECT TO anon, authenticated
  USING (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (bucket_id = 'drawing-images');

CREATE POLICY "drawing_images_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'drawing-images');
```

### 6.4 파일 업로드/조회 (클라이언트)
```dart
// 실사 사진 업로드
final path = 'inspection-photos/$inspectionId/photo.jpg';
await supabase.storage.from('inspection-photos').upload(path, file);

// 서명 이미지 업로드
final sigPath = 'inspection-signatures/$inspectionId/signature.png';
await supabase.storage.from('inspection-signatures').upload(sigPath, signatureBytes);

// 파일 URL 조회 (Private 버킷이므로 Signed URL 사용)
final url = await supabase.storage.from('inspection-photos')
  .createSignedUrl(path, 3600);  // 1시간 유효

// 도면 이미지 업로드
final drawingPath = 'drawing-images/$drawingId/floor_plan.png';
await supabase.storage.from('drawing-images').upload(drawingPath, imageFile);
```

---

## 7. API 엔드포인트

### 7.1 PostgREST 자동 API
Supabase는 PostgREST를 통해 테이블별 REST API를 자동 생성합니다.

기본 URL: `https://<project-id>.supabase.co/rest/v1/{table_name}`

### 7.2 프론트엔드 API ↔ Supabase 매핑
> 프론트엔드 명세 7.1 정책과 동일하게 구현합니다.

#### 7.2.1 인증 불필요 API (일반 조회 + 인증 진입)
> 정책: 일반 조회(`GET`)는 인증 없이 호출 가능

| 프론트엔드 API | Supabase 구현 (Dart) |
|--------------|---------------------|
| `POST /api/auth/login` | `supabase.auth.signInWithPassword(email, password)` |
| `POST /api/auth/sns/kakao` | `supabase.functions.invoke('auth-kakao', body)` |
| `POST /api/auth/sns/google` | `supabase.auth.signInWithOAuth(OAuthProvider.google)` |
| `POST /api/auth/refresh` | `supabase_flutter` SDK 자동 처리 |
| `GET /api/assets` | `supabase.from('assets').select().range(from, to)` |
| `GET /api/assets/:id` | `supabase.from('assets').select().eq('id', id).single()` |
| `GET /api/users` | `supabase.from('users').select()` |
| `GET /api/users/:id` | `supabase.from('users').select().eq('id', id).single()` |
| `GET /api/inspections` | `supabase.from('asset_inspections').select().range(from, to)` |
| `GET /api/inspections/:id/photo` | `supabase.storage.from('inspection-photos').createSignedUrl(path, 3600)` |
| `GET /api/inspections/:id/signature` | `supabase.storage.from('inspection-signatures').createSignedUrl(path, 3600)` |
| `GET /api/drawings` | `supabase.from('drawings').select()` |
| `GET /api/drawings/:id` | `supabase.from('drawings').select().eq('id', id).single()` |
| `GET /api/drawings/:id/assets` | `supabase.from('assets').select().eq('location_drawing_id', id)` |

#### 7.2.2 인증 필요 API (등록/수정/삭제)
> 정책: `POST`/`PUT`/`DELETE`는 인증 필요 (`Authorization: Bearer {token}`)

| 프론트엔드 API | Supabase 구현 (Dart) |
|--------------|---------------------|
| `POST /api/auth/logout` | `supabase.auth.signOut()` |
| `POST /api/assets` | `supabase.from('assets').insert(data)` |
| `PUT /api/assets/:id` | `supabase.from('assets').update(data).eq('id', id)` |
| `DELETE /api/assets/:id` | `supabase.from('assets').delete().eq('id', id)` |
| `POST /api/inspections` | `supabase.from('asset_inspections').insert(data)` |
| `PUT /api/inspections/:id` | `supabase.from('asset_inspections').update(data).eq('id', id)` |
| `DELETE /api/inspections/:id` | `supabase.from('asset_inspections').delete().eq('id', id)` |
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
  .order('asset_uid');

final total = response.count;       // 전체 수
final totalPages = (total / size).ceil();  // 전체 페이지 수
final data = response.data;         // 자산 목록
```

### 7.4 검색/필터
> 프론트엔드 7.2 쿼리 파라미터 → PostgREST 필터 변환

```dart
// GET /api/assets?category=데스크탑&supply_type=지급&building=본관&search=BDT
var query = supabase
  .from('assets')
  .select('*', const FetchOptions(count: CountOption.exact));

// 유형 필터
if (category != null) query = query.eq('category', category);

// 지급형태 필터
if (supplyType != null) query = query.eq('supply_type', supplyType);

// 상태 필터
if (assetsStatus != null) query = query.eq('assets_status', assetsStatus);

// 건물 필터
if (building != null) query = query.eq('building', building);

// 검색 (자산번호, 자산명, 시리얼번호)
if (search != null) {
  query = query.or('asset_uid.ilike.%$search%,name.ilike.%$search%,serial_number.ilike.%$search%');
}

// 페이지네이션 + 정렬
final response = await query
  .order('asset_uid')
  .range(from, to);
```

### 7.5 자산 등록 요청/응답 예시
```dart
// POST /api/assets (프론트엔드 7.2 자산 등록 요청 대응)
final response = await supabase.from('assets').insert({
  'asset_uid': 'BDT00001',
  'name': '개발팀 데스크탑',
  'assets_status': '사용',
  'supply_type': '지급',
  'category': '데스크탑',
  'serial_number': 'SN-12345',
  'model_name': 'Dell OptiPlex 7090',
  'vendor': 'Dell',
  'building': '본관',
  'floor': '3F',
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

---

## 8. Edge Functions (서버리스 함수)

### 8.1 개요
Supabase Edge Functions는 Deno 런타임 기반 TypeScript 함수입니다.
PostgREST만으로 처리할 수 없는 비즈니스 로직에 사용합니다.

```bash
# Edge Function 생성
supabase functions new auth-kakao
supabase functions new dashboard-stats
supabase functions new expiring-assets

# 배포
supabase functions deploy auth-kakao
supabase functions deploy dashboard-stats
supabase functions deploy expiring-assets
```

### 8.2 auth-kakao (카카오 로그인)
> 카카오 SDK 토큰을 검증하고 Supabase Auth 세션을 생성합니다.

```typescript
// supabase/functions/auth-kakao/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  const { kakao_token } = await req.json()

  // 1. 카카오 API로 토큰 검증
  const kakaoRes = await fetch('https://kapi.kakao.com/v2/user/me', {
    headers: { Authorization: `Bearer ${kakao_token}` },
  })
  const kakaoUser = await kakaoRes.json()

  // 2. Supabase Admin 클라이언트로 사원 정보 매칭
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  // 3. users 테이블에서 카카오 ID로 사원 찾기
  const { data: user } = await supabase
    .from('users')
    .select('*')
    .eq('sns_id', String(kakaoUser.id))
    .eq('auth_provider', 'kakao')
    .single()

  if (!user) {
    return new Response(JSON.stringify({ error: '등록되지 않은 사용자입니다' }), {
      status: 404,
    })
  }

  // 4. Supabase Auth 세션 생성 (service_role로 토큰 발급)
  // ... 구현 ...

  return new Response(JSON.stringify({ access_token, refresh_token, user }))
})
```

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
```

### 9.2 asset_uid 형식 검증/정규화 함수
```sql
-- 자산 UID 검증: 등록경로(1자리)+등록장비(2자리)+숫자5자리
-- 형식: ^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$
-- (기존 자동 생성 로직 사용 중인 경우 정리)
DROP TRIGGER IF EXISTS auto_asset_uid ON public.assets;
DROP FUNCTION IF EXISTS public.generate_asset_uid();
DROP SEQUENCE IF EXISTS asset_uid_seq;
DROP TRIGGER IF EXISTS validate_asset_uid ON public.assets;

CREATE OR REPLACE FUNCTION public.validate_asset_uid()
RETURNS trigger AS $$
BEGIN
  IF NEW.asset_uid IS NULL OR btrim(NEW.asset_uid) = '' THEN
    RAISE EXCEPTION 'asset_uid is required';
  END IF;

  -- 입력 편차 방지: 공백 제거 + 대문자 표준화
  NEW.asset_uid = upper(btrim(NEW.asset_uid));

  IF NEW.asset_uid !~ '^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD)[0-9]{5}$' THEN
    RAISE EXCEPTION 'invalid asset_uid format: %', NEW.asset_uid
      USING HINT = 'Expected format: [B|R|C|L|S][DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD][0-9]{5}';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

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

---

## 10. 실시간 (Realtime)

### 10.1 Realtime 설정
Supabase Realtime을 사용하여 자산 상태 변경을 실시간으로 감지합니다.

```sql
-- Realtime 활성화 (Supabase Dashboard > Database > Replication)
-- 또는 SQL:
ALTER PUBLICATION supabase_realtime ADD TABLE public.assets;
ALTER PUBLICATION supabase_realtime ADD TABLE public.asset_inspections;
```

### 10.2 클라이언트 구독
```dart
// 자산 상태 변경 실시간 감지
final channel = supabase.channel('assets-changes')
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
final inspectionChannel = supabase.channel('inspections-changes')
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
# 마이그레이션 파일 구조
supabase/
├── migrations/
│   ├── 20240201000000_create_users.sql          # 4.2 users 테이블
│   ├── 20240201000001_create_drawings.sql        # 4.6 drawings 테이블
│   ├── 20240201000002_create_assets.sql          # 4.3 assets 테이블 + 4.4 specifications
│   ├── 20240201000003_create_inspections.sql     # 4.5 asset_inspections 테이블
│   ├── 20240201000004_create_rls_policies.sql    # 5.1~5.5 테이블 RLS 정책
│   ├── 20240201000005_create_storage_buckets.sql # 6.1 버킷 생성
│   ├── 20240201000006_create_storage_rls.sql     # 6.3 Storage RLS 정책
│   ├── 20240201000007_create_functions_triggers.sql # 9.1~9.4 DB 함수/트리거
│   ├── 20240201000008_create_rpc_functions.sql   # 8.4 get_expiring_assets 등 RPC 함수
│   └── 20240201000009_enable_realtime.sql        # 10.1 Realtime 활성화
├── functions/
│   ├── auth-kakao/
│   │   └── index.ts                              # 8.2 카카오 로그인
│   ├── dashboard-stats/
│   │   └── index.ts                              # 8.3 대시보드 통계
│   └── expiring-assets/
│       └── index.ts                              # 8.4 만료 임박 자산 (RPC 래퍼)
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
INSERT INTO public.assets (asset_uid, name, category, assets_status, supply_type)
VALUES ('BDT00001', '테스트 자산', '데스크탑', '사용', '지급');

-- asset_uid 형식 검증 테스트 (실패가 정상)
INSERT INTO public.assets (asset_uid, name, category)
VALUES ('OA-2024-001', '형식 오류 테스트', '모니터');
-- 예상: CHECK 또는 validate_asset_uid 트리거 위반 오류

-- updated_at 트리거 테스트
UPDATE public.assets SET name = '수정됨' WHERE asset_uid = 'BDT00001';
SELECT updated_at FROM public.assets WHERE asset_uid = 'BDT00001';
-- 예상: updated_at이 현재 시각으로 갱신

-- RLS 테스트 (실사 기록 있는 자산 삭제 거부)
INSERT INTO public.asset_inspections (asset_id, asset_code, inspector_name)
VALUES (1, 'BDT00001', '테스트');
DELETE FROM public.assets WHERE asset_uid = 'BDT00001';
-- 예상: RLS 정책에 의해 삭제 거부

-- 만료 임박 자산 조회 테스트
INSERT INTO public.assets (asset_uid, name, category, supply_type, supply_end_date)
VALUES ('RNB00002', '렌탈 자산', '노트북', '렌탈', now() + INTERVAL '3 days');
SELECT * FROM public.assets
WHERE supply_type IN ('렌탈', '대여')
  AND supply_end_date <= CURRENT_DATE + INTERVAL '7 days';
-- 예상: RNB00002 포함
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
| 10 | 실사 기록 생성 | INSERT → inspection_count 자동 증가 |
| 11 | 실사 사진 업로드 | Storage 업로드 → URL 반환 |
| 12 | 서명 이미지 업로드 | Storage 업로드 → URL 반환 |
| 13 | 도면 등록 | INSERT + Storage 이미지 업로드 |
| 14 | 도면 내 자산 조회 | location_drawing_id 기반 필터 |
| 15 | 대시보드 통계 | Edge Function → 총 자산/실사율/미검증 수 |
| 16 | 만료 임박 자산 | supply_end_date D-7 이내 조회 |
| 17 | RLS 접근 제어 | `GET` 조회 API는 토큰 없이 허용, `POST/PUT/DELETE`는 토큰 없이 401/403 거부 |
| 18 | Realtime 구독 | 자산 상태 변경 → WebSocket 이벤트 수신 |

---

## 문의
프로젝트 관련 문의사항은 개발팀에 문의해주세요.
