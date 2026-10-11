# OA Manager v1

이 저장소는 Flutter 앱(프론트엔드) + Supabase(백엔드)으로 구성된 자산/실사 관리 시스템입니다.

## 폴더 구조

- `OA_frontend/` : Flutter 앱
- `OA_backend/` : Supabase 프로젝트(마이그레이션, Edge Function, SQL)
- `Agent/` : 기기 에이전트 (KMP — Android / Windows / macOS)

## 테스트/실행 가이드 (상위 공통)

### 0. 사전 준비
- Flutter 3.41.x+ (현재 3.41.2), Dart 3.11.x+
- Node.js 18+
- Supabase CLI
- Docker (Supabase 로컬 실행)
  - **macOS**: Docker CLI + Colima (`brew install colima docker docker-compose` → `colima start`)
  - **Linux**: Docker Engine 네이티브 (별도 VM 불필요)

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

### 3) 계정 프로비저닝

`supabase db reset`은 로그인 계정이나 기본 비밀번호를 만들지 않습니다. 첫 master 관리자는
통제된 운영 절차로 만들고, 이후 계정은 관리자 화면의 보안 계정 생성 기능으로 발급합니다.

임시 비밀번호는 서버가 무작위로 만들며, 한 번만 안전한 별도 채널로 전달해야 합니다.
로그인 이메일은 `{사번}@oamanager.internal` 형식으로 내부 변환됩니다.

### 4) 기본 동작 체크리스트
- 로그인(로컬/Google/Kakao) 후 홈 화면 진입 (`must_change_password` 계정은 비밀번호 변경 화면으로 이동)
- 익명 키만으로 데이터 조회 불가, 일반 사용자는 본인 배정 자산·참여 실사만 조회 (`OA_backend/SECURITY_HARDENING_RUNBOOK.md` §3)
- 자산 목록/상세 이동
- QR 스캔 등록 흐름
- 실사/도면/서명 기능 기본 동작

### 5) 테스트/정적 검사

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
- `CLAUDE.md` : **전체 문서 인덱스** + Claude Code 공통 규칙 (영역별 규칙은 `OA_backend/CLAUDE.md`, `OA_frontend/CLAUDE.md`, `Agent/CLAUDE.md`)
- `OA_frontend/README.md` : 프론트엔드 실행/개발 가이드
- `OA_backend/README.md` : 백엔드(Supabase) 실행/운영 가이드
- `OA_backend/SECURITY_HARDENING_RUNBOOK.md` : 보안 긴급 전환 실행서 — **권한·RLS·에이전트 정책의 기준 문서**
- `Agent/README.md` : 에이전트 명세 / `Agent/BUILDING.md` : 에이전트 빌드 입력값 규칙
- `docs/asset_uid_spec.md` : 자산번호(`asset_uid`) 형식 규격 — 현재기준(`D00001`)과 변경후(`BDT00001`) **두 형식 병행 허용**
- `docs/software_inventory_spec.md` : 자산별 설치 SW 인벤토리 명세 (계획 확정 — 전 OS, 1단계 스크립트 가져오기 → 2단계 에이전트)

## Supabase 환경 변수 주입
- `OA_frontend/oa_app/lib/main.dart`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`는 `String.fromEnvironment`로 읽습니다.
- 미지정 시 다음 기본값이 사용됩니다.
  - `SUPABASE_URL`: `http://localhost:54321`
  - `SUPABASE_ANON_KEY`: 샘플 키
- 로컬/CI에서는 `--dart-define`로 동일 키를 주입해 실행하세요.

## 구현 현황 (Implementation Status)

> 최종 업데이트: 2026-10-11 (실제 코드 기준)

### 백엔드 (Supabase)

#### DB 마이그레이션 (60건)
전체 목록은 `OA_backend/README.md` 12.2 참고. 시기별 요약:

| 시기 | 건수 | 내용 |
|------|------|------|
| 2024-02-01 | 9 | 기본 테이블(users/drawings/assets/asset_inspections), 초기 RLS, Storage, 함수·트리거, RPC, Realtime |
| 2026-02-11 | 4 | 담당정보 필드, asset_uid 형식, 실사 권한·초기화 RPC, 접속현황 |
| 2026-03-14 ~ 03-21 | 7 | 에이전트 테이블·RPC, 역할(role), 실사 라운드 |
| 2026-06-04 ~ 06-15 | 18 | 마스터 관리자·강제 재확인, verify_user 수정, 검색 인덱스, 실사 잠금·라운드 재오픈/삭제/자동 생성, 실사 평탄 view, supply_type 확장, **assets_status 삭제**, **asset_uid 옛 형식만 허용**, 재실사 요청, 담당자 소속/회사, MAC 동기화, dropdown_options |
| 2026-08-16 ~ 08-17 | 8 | **보안 강화** — 익명 노출 제거, 최소 권한 RLS, 도면 버킷 private, private Realtime, 공용 에이전트·시드 계정 차단, 차단 계정 RESTRICTIVE 정책, 레거시 비밀번호 RPC 삭제 |
| 2026-09-22 ~ 09-29 | 10 | 인수증(vendors/receipts/receipt_items), 사용자 관리 RPC 개편, 메뉴 권한(menu_permissions) |
| 2026-10-11 | 4 | asset_uid 두 형식 병행 허용, 계정 생성 토큰 NULL 로그인 500 수정, category CHECK 14종(동기화), 인수증 관리자 그룹 전용 |

#### Edge Functions
| 함수명 | 용도 | 권한 |
|--------|------|------|
| `auth-kakao` | 카카오 토큰 검증 → 사전 연결된 OA 계정에만 세션 발급 | 로그인 경계 (Kong rate-limit) |
| `dashboard-stats` | 홈 대시보드 통계 | JWT + 관리자 그룹 |
| `expiring-assets` | 만료 임박 자산 (D-7) | JWT + 관리자 그룹 |
| `main` (라우터) | 단일 dispatcher, `send-notification` inline | 공개 경로 차단, JWT + 관리자 그룹 |
| `send-notification` | 알림 발송 — `device_tokens`(0건) 기준이라 현재 실질 동작 없음, Kong 라우트 제거됨 | `main` 경유 |

#### 보안·권한 (보안 실행서 기준)
| 항목 | 상태 |
|------|------|
| 익명(anon) 테이블·Storage·RPC 접근 | 차단 |
| 조회 범위 | 관리자 그룹 전체 / 일반 사용자는 배정 자산·참여 실사·본인 정보 |
| 자산·도면·라운드 변경 | 관리자 그룹 |
| 완료·잠금 실사 수정, 실사 초기화·삭제 | admin |
| Storage | 전 버킷 private, 사진·서명은 `<auth_uid>/...` 경로만 업로드 |
| Realtime | private 채널, 토픽별 권한 정책 |
| 공용 에이전트 계정 / 시드 계정 | 차단(banned) + RESTRICTIVE 정책 |
| 에이전트 RPC (heartbeat·사용자 확인·수령 확인) | ⛔ 실행 권한 회수 — 기기별 신원 재도입 전까지 의도된 차단 |
| 역할 체계 | admin / operator1 / operator2 / user + 마스터 관리자(최대 4명) |

> ⚠️ **실행서 기준 미충족 항목** (상세: `OA_backend/README.md` 5.10, 9.13)
> - 인수증 테이블·버킷이 "인증 사용자 전체 읽기/쓰기"
> - 계정 생성·역할 변경·비밀번호 설정 RPC가 마스터 전용에서 admin으로 완화됨, `admin_set_user_password`가 계정 차단(`banned_until`)을 해제함

---

### 프론트엔드 (Flutter, Dart 파일 67개)

| 영역 | 파일 |
|------|------|
| 모델 (9) | asset, asset_inspection, inspection_round, user, auth_state, drawing, search_condition, receipt, vendor |
| 서비스 (5) | api_service, auth_service, realtime_service(private 채널), signature_service, drawing_service |
| 상태 관리 (9) | auth, asset, inspection, drawing, signature, agent_presence, agent_alert, dropdown_options, menu_visibility |
| 화면 (15) | login, change_password, home, scan, asset_list, asset_detail, inspection_list, inspection_detail, signature, drawing_manager, drawing_viewer, receipt_list, receipt_detail, vendor_manager, admin_settings |
| 유틸 | label_ocr(ML Kit / Tesseract.js 로컬 번들), csv_downloader, receipt_printer, category_icons, os_security, scan_feedback, temp_file_cleaner |

#### 라우트
`/login`, `/`, `/scan`, `/assets`, `/asset/new`, `/asset/:id`, `/inspections`, `/inspection/:id`, `/signature`, `/drawings`, `/drawing/:id`, `/receipts`, `/receipt/new`, `/receipt/:id`, `/admin/vendors`, `/change-password`, `/admin/settings`
> `/unverified`(미검증 자산) 화면은 폐지되었습니다.

---

### 에이전트 (Kotlin Multiplatform)
| 플랫폼 | 상태 |
|--------|------|
| Android | 구현 — WorkManager / ForegroundService, EncryptedSharedPreferences |
| Windows | 구현 — 트레이 + Task Scheduler, DPAPI |
| macOS | 구현 — 트레이 + launchd, Keychain |
| 인증 | 자산 담당자·관리자 개인 OA 계정 (공용 계정 폐기) |
| 알림 | Realtime `notifications` 구독 (FCM 제거) |
| 데이터 갱신 | ⛔ 서버 RPC 차단 중 (재도입 설계: `Agent/README.md` §15) |

---

### 핵심 구현 기능 요약

1. **인증**: 사번+비밀번호, Google OAuth, Kakao(사전 연결 계정만), 비밀번호 강제 변경, 무작위 임시 비밀번호
2. **자산 관리**: 카테고리별 CRUD, QR 식별, asset_uid 형식 검증(현재기준 `D00001` + 변경후 `BDT00001` 병행), 지급형태 9종(= 상태), specifications JSONB
3. **실사 관리**: 전사 실사 라운드(시작 시 전 자산 실사 자동 생성, 재오픈·삭제), 사진·서명, 잠금, 재실사 요청, 고아파일 자동 삭제
4. **도면 관리**: 건물·층별 도면, 격자 좌표, 자산 마커, 줌/팬
5. **대시보드**: 총 자산, 실사 완료율, 미검증 자산, 만료 임박 (D-7)
6. **QR 스캔**: 모바일·웹 카메라, 최대 5회 연속, 수동 입력 폴백
7. **보안**: 보안 실행서 기준 최소 권한 RLS, private Storage·Realtime, 차단 계정 즉시 무력화
8. **인수증**: 거래처·발송/인수업체, 서명 3종, 금액, PDF 인쇄
9. **관리자 설정**: 사용자 관리, 마스터 관리자(최대 4명), 메뉴 권한, 드롭다운 옵션, 입고증 양식
10. **OCR**: 라벨 인식 (모바일 ML Kit, 웹 Tesseract.js)
11. **에이전트 연동**: Presence, 관리자 명령(Broadcast), 서버 알림(Realtime) — 데이터 갱신 RPC는 재도입 전까지 차단

## 운영 절차 (라이브 서버 `oa-*` 컨테이너)

| 작업 | 방법 |
|------|------|
| DB 마이그레이션 적용 | 이 서버에는 `supabase_migrations.schema_migrations`가 없어 `supabase db push`를 쓰지 않습니다. 직접 적용: `docker exec -i oa-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 < OA_backend/supabase/migrations/<파일>.sql` (파일이 `BEGIN/COMMIT`으로 감싸져 있어 실패 시 전부 롤백). 먼저 `COMMIT` → `ROLLBACK`으로 바꾼 리허설을 권장 |
| 웹 재배포 | 서비스명은 `oa-frontend`: `docker compose build oa-frontend && docker compose up -d oa-frontend`. 다른 컨테이너에 의존하지 않아 DB·Kong은 재생성되지 않음 (`docker compose up -d --dry-run --no-build oa-frontend`로 사전 확인 가능) |
| `auth.users` 직접 INSERT | `confirmation_token`, `recovery_token`, `email_change_token_new`, `email_change`를 `''`로 채울 것. NULL이면 해당 계정 로그인이 500 (`20261011000001`) |
| 화면 검증 | 호스트의 `google-chrome` + `playwright-core`로 임시 관리자 계정을 만들어 로그인·화면 순회·웹소켓 채널 참여를 확인하고, 끝나면 계정을 삭제 (2026-10-11 수행) |

### 2026-10-11 검증 결과 (관리자 계정으로 로그인)
- 홈 · 자산목록 · 실사목록 · 도면 · 인수증 · 거래처 · 설정 화면 모두 정상, 사이드 메뉴(☰)·설정 탭 구성은 `OA_frontend/README.md`와 일치
- Realtime 웹소켓 연결 성공, private 채널 4개(`assets-realtime`, `inspections-realtime`, `agent-presence:global`, `agent-alerts:global`) 모두 `ok`로 참여
- 익명 REST 접근은 401, 웹 루트의 점(`.`) 파일 요청은 404

### 알려진 이슈 / 결정 사항 (2026-10-11 기준)
| 구분 | 내용 | 상태 |
|------|------|------|
| 보안 | 릴리스 키스토어(`oaagent-release.jks`)와 키 비밀번호가 원격 git 이력에 있음 → 새 키로 교체 | 에이전트 재배포(재도입) 시 함께 처리 |
| 보안 | `.env` 이력 노출 | 해결 — 원격 이력에서 제거됨, 이력의 운영 키(DB·JWT·anon·service·대시보드)는 모두 이미 교체된 값임을 해시로 확인 (2026-10-11) |
| 보안 | 인수증 RLS 과다 허용 | 해결 — 라이브는 이미 관리자 그룹 전용, 저장소 동기화 + RESTRICTIVE 정책 추가 (`20261011000003`) |
| 보안 | 계정 관리 RPC가 마스터 전용에서 admin으로 완화 (`OA_backend/README.md` 9.13) | 미해결 (시드 계정 활성은 의도된 운영) |
| 운영 | 시드 계정 `admin01`/`oper01`/`user01` 차단 해제 상태 사용 중 | 의도된 것 (2026-10-11 확인) |
| 기능 | 자산 `category` 앱 14종 vs DB CHECK 12종 | 해결 — 라이브는 이미 14종, 저장소 동기화 (`20261011000002`) |
| 기능 | 자산별 설치 SW 조회 (전 OS) | 계획 확정 (`docs/software_inventory_spec.md`) — 1단계는 에이전트 없이 스크립트 가져오기 |
| 기능 | `send-notification` Edge Function은 `device_tokens`(0건) 기준이라 실질 동작 없음, Kong 라우트 제거됨 | 알림은 RPC·직접 INSERT 사용 |
| 기능 | 에이전트 RPC(heartbeat·사용자 확인·수령 확인) 실행 권한 회수 — 기기별 신원 재도입 전까지 접속현황은 계속 미접속 (`Agent/README.md` §15) | 의도된 차단 |
| 표시 | 자산·실사 목록 총 건수 오류 | 해결 — `CountOption.planned`(통계 추정) → `estimated` (2026-10-11 배포·화면 확인) |
| 표시 | 자산목록 접속현황 점이 Presence 미반영 | 해결 — 셀 단위 Consumer로 Presence 구독 (2026-10-11 배포, 에이전트 미접속이라 파란 점은 미관찰) |

## 버전 관리

- 버전: `v1.0.0`
- 버전 규칙: [SemVer](https://semver.org/) (`MAJOR.MINOR.PATCH`)
- 릴리스 기준: 기능 추가/호환성 변경은 MINOR, 버그 수정은 PATCH, 구조 변경은 MAJOR
- 변경 이력: 이 파일의 하단에 날짜 기준 기록을 남깁니다.

### 변경 이력

- `2026-10-11` : 인수증 권한 정렬·category 동기화 마이그레이션(#59, #60), 목록 총 건수·접속현황 표시 수정 배포, 설치 SW 인벤토리 전 OS 계획 확정
- `2026-10-11` : 운영 절차·검증 결과·알려진 이슈 섹션 추가, `20260817000001` 적용(담당 범위 조회·private Realtime)
- `2026-10-11` : 앱에서 만든 계정(LD10239, LD09112, 비상 마스터)이 로그인 500으로 실패하던 문제 수정 (마이그레이션 #58)
- `2026-10-11` : 자산번호 두 형식 병행 허용 (마이그레이션 #57, 프론트 정규식·안내 다이얼로그)
- `2026-10-11` : 명세 문서 전체를 실제 코드·보안 실행서 기준으로 정비 (asset_uid 현재 형식, 마이그레이션 56건, Flutter 3.41.2, FCM 기술 제거, 보안 정책·미충족 항목 명시)
- `2026-09-22 ~ 09-29` : 인수증·거래처, 사용자 관리 개편, 메뉴 권한
- `2026-08-16 ~ 08-17` : 보안 긴급 전환 (`OA_backend/SECURITY_HARDENING_RUNBOOK.md`)
- `2026-06-05 ~ 06-15` : 실사 잠금·라운드 자동 생성, assets_status 삭제, asset_uid 옛 형식만 허용, dropdown_options 등
- `2026-06-04` :
  - 도메인 변경: API 호스트를 `api.oa.terraforming.info` → `apioa.terraforming.info`로 변경 (.env / docker-compose Traefik / Agent `AgentConfig.SUPABASE_URL` / Agent README 일괄 반영)
  - 과거 정적 테스트 계정은 폐기되었으며, 신규 환경에는 기본 로그인 자격증명을 만들지 않음
  - 마이그레이션 #21 추가: 마스터 관리자(`users.is_master_admin`, 최대 4명, role=admin 한정), `admin_force_verify(asset_uid)` RPC, `assets` UPDATE 트리거(마스터가 user_name 변경 시 자동 reset+notification), `notifications` 테이블 Realtime publication 추가
  - 푸시 전략: Firebase 의존 제거. 알림 전달은 Supabase Realtime(notifications INSERT)로 일원화
  - 에이전트: `RealtimeManager.joinNotificationsChannel()` + 안드로이드 시스템 알림 채널 `admin_alert_channel` 추가, APK 재빌드 (3.2 MB)
  - 프론트: 에이전트 설정 페이지에 마스터 관리자 카드(현재/한도 표시, 사용자별 토글) + 자산 상세에 "관리자 재확인 요청" 버튼
  - Edge Function: `main`을 dispatcher로 재구성, `send-notification` 로직 inline (cross-function import 제약 우회)
  - nginx 캐시 정책 수정: `flutter_service_worker.js` / `main.dart.js` / `flutter_bootstrap.js` / `flutter.js` / `index.html` → no-cache (재배포 즉시 반영). canvaskit/tesseract/font/image는 그대로 1년 immutable
- `2026-03-21` : 역할 체계 추가 (admin/operator1/operator2/user), 전사 실사 라운드(차수) 관리 기능, 사진 저장 경로 라운드 기반 변경, 고아파일 자동 삭제, 에러 메시지 SelectableText, 앱바 자산번호 부여 기준 전체 적용, QR 웹 카메라 지원, 실시간 OCR 스캔, 테스트 시드 9개 계정 (역할별)
- `2026-03-20` : 앱 이름 변경 (oa_app → OAManager), OCR 웹 지원 (Tesseract.js 로컬 번들), 실사 사진 촬영 기능 추가, 사진/서명 레이지 로딩, 서명 export 에러 수정, 임시 파일 자동 삭제, Docker Desktop → Colima(macOS)/Docker Engine(Linux), 에이전트 테이블 마이그레이션 4건 추가
- `2026-02-17` : 구현 현황 섹션 추가 (백엔드 12건 마이그레이션, Edge Function 3건, 프론트엔드 40개 Dart 파일 현황 기록)
- `2026-02-17` : README 통합 정비(테스트/실행 가이드 중심으로 정리), 코드 기준 버전/환경 변수/인증 예시 정합화
