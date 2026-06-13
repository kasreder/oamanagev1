# OA Manager v1

이 저장소는 Flutter 앱(프론트엔드) + Supabase(백엔드)으로 구성된 자산/실사 관리 시스템입니다.

## 폴더 구조

- `OA_frontend/` : Flutter 앱
- `OA_backend/` : Supabase 프로젝트(마이그레이션, Edge Function, SQL)

## 테스트/실행 가이드 (상위 공통)

### 0. 사전 준비
- Flutter 3.41.x+, Dart 3.11.x+
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

### 3) 테스트 계정

`supabase db reset` 실행 시 시드(`OA_backend/supabase/seed.sql`)로 자동 생성됩니다.

#### 관리자 그룹
| 사번(ID) | 이름 | 역할 | 비밀번호 |
|----------|------|------|---------|
| `temp01` | Test User | admin | `temp1234!` |
| `admin01` | 관리자 | admin | `admin1234!` |
| `oper01` | 운영자1 | operator1 | `oper1234!` |
| `oper02` | 운영자2 | operator2 | `oper1234!` |

#### 사용자 그룹
| 사번(ID) | 이름 | 역할 | 비밀번호 |
|----------|------|------|---------|
| `user01` | 사용자1 | user | `user1234!` |
| `user02` | 사용자2 | user | `user1234!` |
| `user03` | 사용자3 | user | `user1234!` |
| `user04` | 사용자4 | user | `user1234!` |
| `user05` | 사용자5 | user | `user1234!` |

> 로그인 이메일은 `{사번}@oamanager.internal` 형식으로 내부 변환됩니다.
> Auth 계정 생성 SQL은 `seed.sql`에 포함되어 있으며, `auth.users` INSERT + `public.users` 동기화 트리거로 자동 반영됩니다.

### 4) 기본 동작 체크리스트
- 로그인(로컬/Google/Kakao) 후 홈 화면 진입
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
- `OA_frontend/README.md` : 프론트엔드 실행/개발 가이드
- `OA_backend/README.md` : 백엔드(Supabase) 실행/운영 가이드

## Supabase 환경 변수 주입
- `OA_frontend/oa_app/lib/main.dart`의 `SUPABASE_URL`, `SUPABASE_ANON_KEY`는 `String.fromEnvironment`로 읽습니다.
- 미지정 시 다음 기본값이 사용됩니다.
  - `SUPABASE_URL`: `http://localhost:54321`
  - `SUPABASE_ANON_KEY`: 샘플 키
- 로컬/CI에서는 `--dart-define`로 동일 키를 주입해 실행하세요.

## 구현 현황 (Implementation Status)

> 최종 업데이트: 2026-06-04

### 백엔드 (Supabase)

#### DB 마이그레이션 (21건 완료)
| # | 파일명 | 내용 | 상태 |
|---|--------|------|------|
| 1 | `20240201000000_create_users.sql` | users 테이블 생성 | ✅ 완료 |
| 2 | `20240201000001_create_drawings.sql` | drawings 테이블 생성 | ✅ 완료 |
| 3 | `20240201000002_create_assets.sql` | assets 테이블 생성 + specifications JSONB | ✅ 완료 |
| 4 | `20240201000003_create_inspections.sql` | asset_inspections 테이블 생성 | ✅ 완료 |
| 5 | `20240201000004_create_rls_policies.sql` | 전체 테이블 RLS 정책 | ✅ 완료 |
| 6 | `20240201000005_create_storage.sql` | Storage 버킷 생성 (사진/서명/도면) | ✅ 완료 |
| 7 | `20240201000006_create_functions_triggers.sql` | DB 함수/트리거 (updated_at, asset_uid 검증, 실사 횟수, Auth 동기화) | ✅ 완료 |
| 8 | `20240201000007_create_rpc_functions.sql` | RPC 함수 (is_admin, get_expiring_assets) | ✅ 완료 |
| 9 | `20240201000008_enable_realtime.sql` | Realtime 활성화 (assets, inspections) | ✅ 완료 |
| 10 | `20260211000000_add_asset_party_fields.sql` | 자산 담당정보 필드 추가 (소유자/사용자/관리자) | ✅ 완료 |
| 11 | `20260211000001_asset_uid_format_alignment.sql` | asset_uid 형식 정규식 검증 및 정규화 트리거 | ✅ 완료 |
| 12 | `20260211000002_inspection_permissions_and_reset.sql` | 실사 완료건 수정 권한 + 초기화 RPC | ✅ 완료 |
| 13 | `20260211000003_add_access_status.sql` | 접근 상태 필드 추가 | ✅ 완료 |
| 14 | `20260314000000_add_agent_tables.sql` | 에이전트 테이블 생성 (agent_heartbeats, agent_system_info) | ✅ 완료 |
| 15 | `20260314000001_add_agent_rls_policies.sql` | 에이전트 테이블 RLS 정책 | ✅ 완료 |
| 16 | `20260314000002_add_agent_rpc_and_columns.sql` | 에이전트 RPC 함수 및 컬럼 추가 | ✅ 완료 |
| 17 | `20260321000000_fix_inspection_update_rls.sql` | 실사 완료 전환 시 WITH CHECK 수정 | ✅ 완료 |
| 18 | `20260321000001_add_user_role.sql` | users role 컬럼 + is_admin_group() 함수 | ✅ 완료 |
| 19 | `20260321000002_create_inspection_rounds.sql` | 전사 실사 라운드(차수) 테이블 + RPC | ✅ 완료 |
| 20 | `20260321000003_add_round_to_inspections.sql` | asset_inspections round_id + RLS 수정 | ✅ 완료 |
| 21 | `20260604000000_master_admin_and_force_verify.sql` | 마스터 관리자(`is_master_admin`, 최대 4명) + `admin_force_verify` RPC + user_name 변경 자동 트리거 + notifications Realtime publication | ✅ 완료 |

#### Edge Functions
| 함수명 | 용도 | 상태 |
|--------|------|------|
| `auth-kakao` | 카카오 OAuth 토큰 검증 → Supabase Auth 세션 생성 | ✅ 완료 |
| `dashboard-stats` | 홈 대시보드 통계 (총 자산/실사율/미검증/만료 임박) | ✅ 완료 |
| `expiring-assets` | 만료 임박 자산 상세 목록 (D-7 이내) | ✅ 완료 |
| `main` (라우터) | 단일 진입 dispatcher (`/functions/v1/<name>`), `send-notification` inline 호스팅 | ✅ 완료 |
| `send-notification` | 알림 발송 (현재 미사용 — Realtime로 대체) | 보존 |

#### 기타 백엔드
| 항목 | 상태 |
|------|------|
| RLS 정책 (users, assets, inspections, drawings, storage, inspection_rounds) | ✅ 완료 |
| Storage 버킷 3개 (inspection-photos, inspection-signatures, drawing-images) | ✅ 완료 |
| Realtime 구독 (assets, asset_inspections) | ✅ 완료 |
| 사용자 역할 체계 (admin, operator1, operator2, user) | ✅ 완료 |
| 전사 실사 라운드(차수) 관리 (생성/시작/종료 RPC) | ✅ 완료 |
| 테스트 시드 데이터 (seed.sql — 9개 계정, 역할별) | ✅ 완료 |
| 마스터 관리자 시스템 (`is_master_admin`, 최대 4명, role=admin 한정) | ✅ 완료 |
| 관리자 강제 재확인 (`admin_force_verify` RPC) | ✅ 완료 |
| Realtime publication에 `notifications` 포함 (FCM 미사용) | ✅ 완료 |

---

### 프론트엔드 (Flutter)

#### 데이터 모델 (6건 완료)
| 파일 | 내용 | 상태 |
|------|------|------|
| `models/asset.dart` | 자산 모델 (12개 카테고리, specifications JSONB) | ✅ 완료 |
| `models/user.dart` | 사용자 모델 (조직 정보, 역할 role, isAdminGroup) | ✅ 완료 |
| `models/asset_inspection.dart` | 실사 기록 모델 (사진/서명/위치/roundId) | ✅ 완료 |
| `models/inspection_round.dart` | 전사 실사 라운드(차수) 모델 | ✅ 완료 |
| `models/drawing.dart` | 도면 모델 (건물/층/격자) | ✅ 완료 |
| `models/auth_state.dart` | 인증 상태 모델 (토큰, 세션) | ✅ 완료 |

#### 서비스 레이어 (5건 완료)
| 파일 | 내용 | 상태 |
|------|------|------|
| `services/auth_service.dart` | 인증 서비스 (사번 로그인, Google/Kakao OAuth, 로그아웃) | ✅ 완료 |
| `services/api_service.dart` | 자산/실사/라운드/통계 REST API 호출 | ✅ 완료 |
| `services/drawing_service.dart` | 도면 CRUD + Storage 이미지 업로드 | ✅ 완료 |
| `services/signature_service.dart` | 서명 이미지 저장/로드 (Storage) | ✅ 완료 |
| `services/realtime_service.dart` | Realtime 구독 (에이전트 Presence/Broadcast) | ✅ 완료 |

#### 상태 관리 - Riverpod Notifiers (6건 완료)
| 파일 | 내용 | 상태 |
|------|------|------|
| `notifiers/auth_notifier.dart` | 인증 상태, 세션 관리, 로그인/로그아웃 | ✅ 완료 |
| `notifiers/asset_notifier.dart` | 자산 CRUD, 필터/검색/페이지네이션 | ✅ 완료 |
| `notifiers/inspection_notifier.dart` | 실사 기록 CRUD, 상태 관리 | ✅ 완료 |
| `notifiers/drawing_notifier.dart` | 도면 CRUD, 목록/상세 관리 | ✅ 완료 |
| `notifiers/signature_notifier.dart` | 서명 캡처 및 저장 관리 | ✅ 완료 |
| `notifiers/agent_presence_notifier.dart` | 에이전트 실시간 Presence 상태 관리 | ✅ 완료 |

#### 화면 (11개 완료)
| 경로 | 파일 | 기능 | 상태 |
|------|------|------|------|
| `/login` | `login_page.dart` | 사번+비밀번호, Google OAuth, Kakao OAuth 로그인 | ✅ 완료 |
| `/` | `home_page.dart` | 대시보드 (통계 카드 3종, 최신 자산 10건, 만료 임박 목록) | ✅ 완료 |
| `/scan` | `scan_page.dart` | QR 코드 스캔 (모바일: 카메라, 웹: 카메라+수동입력 폴백) | ✅ 완료 |
| `/assets` | `asset_list_page.dart` | 자산 목록 (컴팩트 필터바, 인라인 등록 버튼, 컬럼 설정) | ✅ 완료 |
| `/asset/:id` | `asset_detail_page.dart` | 자산 상세/등록/수정 (OCR 실시간 스캔, QR 스캔 자산번호 자동입력) | ✅ 완료 |
| `/inspections` | `inspection_list_page.dart` | 실사 목록 (라운드 배너, 차수 관리, 상태 필터) | ✅ 완료 |
| `/inspection/:id` | `inspection_detail_page.dart` | 실사 상세 (사진촬영, 서명, 라운드 권한 제어) | ✅ 완료 |
| `/signature` | `signature_page.dart` | 친필 서명 캡처 (인증 필요) | ✅ 완료 |
| `/drawings` | `drawing_manager_page.dart` | 도면 관리 (건물별 그룹, 이미지 업로드) | ✅ 완료 |
| `/drawing/:id` | `drawing_viewer_page.dart` | 도면 뷰어 (줌/팬, 격자 오버레이, 자산 마커) | ✅ 완료 |
| `/unverified` | `unverified_page.dart` | 미검증 자산 목록 | ✅ 완료 |

#### 재사용 위젯 (10건 완료)
| 파일 | 내용 | 상태 |
|------|------|------|
| `widgets/common/app_scaffold.dart` | 앱 공통 레이아웃 (네비게이션 5탭, 앱바 ? 자산번호 부여 기준) | ✅ 완료 |
| `widgets/common/asset_uid_guide_dialog.dart` | 자산번호 부여 기준 안내 (현재기준/변경후 토글) | ✅ 완료 |
| `widgets/common/loading_widget.dart` | 로딩 스피너 | ✅ 완료 |
| `widgets/common/error_widget.dart` | 에러 표시 + 재시도 버튼 | ✅ 완료 |
| `widgets/common/empty_state_widget.dart` | 빈 상태 UI | ✅ 완료 |
| `widgets/common/filter_bar.dart` | 필터 컨트롤 (카테고리/상태/검색) | ✅ 완료 |
| `widgets/common/pagination_widget.dart` | 페이지 네비게이션 | ✅ 완료 |
| `widgets/common/status_badge.dart` | 상태별 색상 뱃지 | ✅ 완료 |
| `widgets/signature_pad.dart` | 서명 패드 위젯 | ✅ 완료 |
| `widgets/grouped_asset_list.dart` | 그룹화된 자산 리스트 | ✅ 완료 |
| `widgets/drawing_grid_overlay.dart` | 도면 격자 오버레이 | ✅ 완료 |
| `widgets/asset_marker.dart` | 도면 위 자산 위치 마커 | ✅ 완료 |

#### 유틸리티 (3건 완료)
| 파일 | 내용 | 상태 |
|------|------|------|
| `utils/label_ocr.dart` | OCR 처리 (모바일: ML Kit, 웹: Tesseract.js 로컬 번들) | ✅ 완료 |
| `utils/label_ocr_mobile.dart` / `label_ocr_stub.dart` | 플랫폼별 OCR 구현 (조건부 임포트) | ✅ 완료 |
| `utils/temp_file_cleaner.dart` | 임시 파일 자동 삭제 (OCR 촬영 후 정리) | ✅ 완료 |

#### 앱 인프라
| 항목 | 파일 | 상태 |
|------|------|------|
| 앱 진입점 (Supabase 초기화, ProviderScope) | `main.dart` | ✅ 완료 |
| GoRouter 라우팅 (인증 가드, 리다이렉트) | `app_router.dart` | ✅ 완료 |
| 테마 설정 (다크/라이트 모드, 상태별 색상) | `theme.dart` | ✅ 완료 |
| 상수 정의 (카테고리, 상태, 지급형태 등) | `constants.dart` | ✅ 완료 |

---

### 구현 파일 수 요약

| 영역 | 파일 수 |
|------|---------|
| 백엔드 마이그레이션 (SQL) | 21 |
| Edge Functions (TypeScript) | 5 (main 라우터 포함) |
| 프론트엔드 Dart 소스 | 48+ |
| 웹 OCR 번들 (Tesseract.js) | 5 |
| **총 소스 파일** | **76+** |

---

### 핵심 구현 기능 요약

1. **인증 시스템**: 사번+비밀번호 로그인, Google OAuth, Kakao OAuth (Edge Function), JWT 기반 세션 관리
2. **자산 관리**: 12개 카테고리별 CRUD, QR 코드 기반 식별, asset_uid 정규식 검증, specifications JSONB 관리
3. **실사 관리**: 실사 기록 CRUD, 전사 실사 라운드(차수) 관리, 사진 촬영 (용량 최적화 1280x960/70%), 친필 서명 캡처, 위치 검증, 완료건 수정 제한, 고아파일 자동 삭제, 사진/서명 레이지 로딩
4. **도면 관리**: 건물별 층별 도면 업로드, 격자 기반 좌표 시스템, 자산 마커 시각화, 줌/팬 뷰어
5. **대시보드**: 총 자산 수, 실사 완료율, 미검증 자산, 만료 임박 자산 (D-7) 실시간 통계
6. **QR 스캔**: 모바일/웹 카메라 QR 스캔 → 자산 조회/신규 등록 (최대 5회 연속 스캔, 웹 카메라 실패 시 수동 입력 폴백)
7. **보안**: RLS 정책 (테이블 5개 + Storage 3개), 역할 기반 권한 분리 (admin/operator1/operator2/user), 라운드 활성 시에만 실사 수정 허용
8. **Realtime**: 자산/실사 변경 실시간 WebSocket 구독, 에이전트 Presence/Broadcast
9. **OCR**: 디바이스 라벨 자동 인식 (모바일: Google ML Kit, 웹: Tesseract.js 로컬 번들), 사진촬영/갤러리 선택, 매칭 실패 시 직접 편집, 단어별 탭 복사
10. **에이전트 연동**: Heartbeat 수신, 시스템 정보 실시간 동기화, Presence 상태 모니터링
11. **마스터 관리자 + 자동 재확인 알림**: admin 권한 사용자 중 최대 4명을 마스터로 지정 → 마스터가 자산 `user_name` 변경 시 `verification_status` 자동 초기화 + `notifications` 자동 삽입 → 에이전트가 Realtime 구독으로 즉시 수신 → Android 시스템 알림 표시. 관리자는 자산 상세에서 "관리자 재확인 요청" 버튼으로도 강제 호출 가능.

## 버전 관리

- 버전: `v1.0.0`
- 버전 규칙: [SemVer](https://semver.org/) (`MAJOR.MINOR.PATCH`)
- 릴리스 기준: 기능 추가/호환성 변경은 MINOR, 버그 수정은 PATCH, 구조 변경은 MAJOR
- 변경 이력: 이 파일의 하단에 날짜 기준 기록을 남깁니다.

### 변경 이력

- `2026-06-04` :
  - 도메인 변경: API 호스트를 `api.oa.terraforming.info` → `apioa.terraforming.info`로 변경 (.env / docker-compose Traefik / Agent `AgentConfig.SUPABASE_URL` / Agent README 일괄 반영)
  - 테스트 계정 비밀번호 소문자 통일 (`Temp1234!` → `temp1234!`, `Admin1234!` → `admin1234!`, `Oper1234!` → `oper1234!`, `User1234!` → `user1234!`)
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

