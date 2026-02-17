# OA Manager v1 - 프론트엔드 명세서

## ⚠️ 중요 사항
> **본 문서는 OA 자산관리 시스템의 프론트엔드 개발 명세서입니다.**
> **DB 스키마 및 API 연동 규격은 반드시 백엔드팀과 협의 후 진행해야 합니다.**
> **QR 스캔 기능은 HTTPS 환경에서만 정상 작동합니다.**

### 예제 코드 정책 (Example Code Policy)

본 명세서에 포함된 모든 코드 블록에 대해 아래 정책을 적용합니다.

| 구분 | 구속력 | 설명 |
|------|--------|------|
| 예제 코드 (코드 블록 내 구현부) | **변경 가능** | 설계 이해를 돕기 위한 참고용. 동일한 기능을 수행하는 다른 구조의 코드도 허용 |
| 함수 시그니처 / API 규격 | **고정** | 메서드명, 파라미터, 반환 타입, API 경로/메서드는 반드시 준수 |
| 상태 흐름 / 사용자 시나리오 | **고정** | 화면 전환 순서, 사용자 인터랙션 흐름, 데이터 흐름은 반드시 준수 |
| 내부 구현 로직 | **구현자 재량** | 동일한 입출력을 보장하는 범위 내에서 자유롭게 구현 가능 |

> **원칙**: 예제 코드는 구현 예시 중 하나일 뿐이며, 동일한 기능을 수행하는 다른 구조의 코드도 허용됩니다.
> AI 기반 코드 생성 시에도 본 명세의 **기능 요구사항**을 우선합니다.

---

## 1. 프로젝트 개요

### 1.1 목적
OA 자산의 효율적인 관리 및 실사를 위한 웹/모바일 통합 애플리케이션 개발

### 1.2 주요 기능
본 시스템은 다음 **네 가지 핵심 기능**을 제공합니다:

#### 1) 자산관리
- **자산 등록**: 신규 OA 자산 정보 입력 및 QR 코드 생성
- **자산 변경**: 기존 자산 정보 수정 (위치, 담당자, 상태 등)
- **자산 삭제**: 폐기/이관된 자산 삭제 처리
- **자산 유형별 관리**: 데스크탑, 모니터, 노트북, IP전화기, 스캐너, 프린터, 태블릿, 테스트폰, 네트워크장비, 서버, 웨어러블, 특수목적장비

#### 2) 자산실사
- **위치 정보 관리**: 건물, 층수, 자리번호 기반 자산 위치 추적
- **QR 촬영 확인**: 모바일 카메라를 통한 QR 스캔으로 자산 실사
- **실사 사인**: 실사 담당자 친필 서명 기능으로 책임 소재 명확화
- **실사 기록 저장**: 실사 일시, 담당자, 자산 상태, 서명 이미지 등 이력 관리

#### 3) 도면 관리
- **도면 등록/수정/삭제**: 건물별 층별 도면 이미지 관리
- **격자 기반 위치 지정**: 도면 위 격자로 자산 위치 시각화
- **자산 마커**: 도면 위 자산 위치 표시 및 상태별 색상 구분

#### 4) 실시간 현황 파악
- **자산 정보 대시보드**: 전체 자산 현황 실시간 조회
- **실사 진행률**: 미검증 자산 및 실사 완료율 통계
- **검색 및 필터링**: 자산 코드, 담당자, 위치 기반 검색

---

## 2. 기술 스택

### 2.1 개발 환경
- **Framework**: Flutter 3.22.x 이상
- **Language**: Dart 3.7+
- **IDE**: VSCode / Android Studio

### 2.2 주요 패키지
| 패키지명 | 버전 | 용도 |
|---------|------|------|
| `supabase_flutter` | ^2.5.0 | Supabase SDK (Auth, PostgREST, Storage, Realtime 통합) |
| `flutter_riverpod` | ^2.5.0 | 상태 관리 (Provider 대신 사용) |
| `riverpod_annotation` | ^2.3.0 | Riverpod 코드 생성 |
| `go_router` | ^14.0.0 | 라우팅 및 네비게이션 |
| `mobile_scanner` | ^5.0.0 | QR 코드 스캔 |
| `permission_handler` | ^11.0.0 | 카메라 권한 관리 |
| `signature` | ^5.5.0 | 친필 서명 기능 |
| `dio` | ^5.4.0 | HTTP 클라이언트 (Supabase SDK 미지원 외부 API 호출 시 보조 사용) |
| `grouped_list` | ^5.1.2 | 자산 리스트 그룹화 표시 |
| `flutter_slidable` | ^3.0.0 | 리스트 항목 슬라이드 액션 |
| `image_picker` | ^1.0.0 | 이미지 선택 및 카메라 촬영 |
| `path_provider` | ^2.1.0 | 로컬 파일 저장 경로 |
| `shared_preferences` | ^2.2.0 | 로컬 설정 저장 |
| `intl` | ^0.19.0 | 날짜/시간 포맷팅 |
| `qr_flutter` | ^4.1.0 | QR 코드 생성 |
| `photo_view` | ^0.14.0 | 도면 이미지 확대/축소/팬 |
| `cached_network_image` | ^3.3.0 | 도면 이미지 캐싱 |
| `flutter_painter` | ^2.0.0 | 도면 위 격자 및 마커 그리기 |
| `sqflite` | ^2.3.0 | 로컬 DB (오프라인 캐싱) |
| `flutter_secure_storage` | ^9.0.0 | 토큰 암호화 저장 |
| `connectivity_plus` | ^6.0.0 | 네트워크 상태 감지 |
| `kakao_flutter_sdk_user` | ^1.9.0 | 카카오 SNS 로그인 |
| `google_sign_in` | ^6.2.0 | 구글 SNS 로그인 |

### 2.3 개발 도구 (dev_dependencies)
| 패키지명 | 버전 | 용도 |
|---------|------|------|
| `build_runner` | ^2.4.0 | Riverpod 코드 생성 |
| `riverpod_generator` | ^2.3.0 | Riverpod 어노테이션 프로세서 |
| `flutter_lints` | ^3.0.0 | Dart 코드 린트 |
| `firebase_crashlytics` | ^3.5.0 | 에러 추적 및 비정상 종료 보고 |

---

## 3. 시스템 아키텍처

### 3.1 디렉토리 구조
```
lib/
├── main.dart                      # 앱 진입점 (ProviderScope 설정)
├── app_router.dart                # GoRouter 라우팅 설정
├── models/                        # 데이터 모델
│   ├── asset.dart                 # 자산 모델
│   ├── user.dart                  # 사용자 모델
│   ├── asset_inspection.dart      # 실사 기록 모델
│   ├── auth_state.dart            # 인증 상태 모델 (토큰, 로그인 사용자 정보)
│   └── drawing.dart               # 도면 모델 (건물/층/격자 정보)
├── notifiers/                     # Riverpod 상태 관리
│   ├── asset_notifier.dart        # 자산 상태 관리
│   ├── inspection_notifier.dart   # 실사 상태 관리
│   ├── signature_notifier.dart    # 서명 상태 관리
│   ├── drawing_notifier.dart      # 도면 상태 관리
│   └── auth_notifier.dart         # 인증/토큰 상태 관리
├── screens/                       # 화면 UI
│   ├── home_page.dart             # 홈 대시보드
│   ├── login_page.dart            # 로그인 화면
│   ├── scan_page.dart             # QR 스캔 화면
│   ├── asset_list_page.dart       # 자산 목록 (건물별/부서별 그룹화)
│   ├── asset_detail_page.dart     # 자산 상세 및 편집
│   ├── inspection_list_page.dart  # 실사 기록 목록
│   ├── inspection_detail_page.dart # 실사 상세 화면
│   ├── signature_page.dart        # 친필 서명 화면
│   ├── drawing_manager_page.dart  # 도면 관리 화면 (추가/삭제)
│   ├── drawing_viewer_page.dart   # 도면 뷰어 (격자+자산위치)
│   └── unverified_page.dart       # 미검증 자산 목록
├── widgets/                       # 재사용 컴포넌트
│   ├── common/                    # 공통 위젯
│   ├── signature_pad.dart         # 서명 패드 위젯
│   ├── grouped_asset_list.dart    # 그룹화된 자산 리스트
│   ├── drawing_grid_overlay.dart  # 도면 격자 오버레이
│   └── asset_marker.dart          # 도면 위 자산 마커
└── services/                      # API 통신 레이어
    ├── api_service.dart           # Dio 기반 API 서비스 (인터셉터 포함)
    ├── auth_service.dart          # 로그인/토큰 갱신/로그아웃 API
    ├── signature_service.dart     # 서명 이미지 저장/로드
    └── drawing_service.dart       # 도면 이미지 업로드/다운로드
```

### 3.2 상태 관리 패턴
- **Riverpod 패턴** 사용
- 각 도메인별로 독립적인 Notifier 관리
- 불변 상태(Immutable State)로 UI 자동 갱신
- Code Generation을 통한 타입 안전성 보장

---

## 4. 주요 기능 명세

### 4.1 자산 관리

#### 4.1.1 자산 조회 (리스트)
> **핵심 화면** — 자산번호(`asset_uid`) 기준으로 전체 자산을 리스트 형식으로 표시

- **리스트 구조**:
  - 자산번호(asset_uid) 기준 정렬, 한 줄에 한 자산
  - **공통 표시 항목**: 자산번호 | 자산명 | 유형(category) | 상태 | 지급형태 | 건물/층
  - **유형별 추가 표시 항목** (유형 필터 선택 시 해당 컬럼 동적 추가):

| 유형 | 추가 표시 항목 |
|------|---------------|
| 데스크탑 | RAM, OS |
| 모니터 | 인치, 해상도, 4K |
| IP전화기 | 전화번호1, 전화번호2, 전화번호3 |
| 노트북 | RAM, OS, 5G |
| 스캐너 | — |
| 프린터 | — |
| 태블릿 | RAM, OS, 5G, 키보드, 펜 |
| 테스트폰 | RAM, OS, 5G |
| 네트워크장비 | — |
| 서버 | — |
| 웨어러블 | — |
| 특수목적장비 | — |

  - 전체 유형 조회 시: 공통 항목만 표시
  - 특정 유형 필터 시: 공통 항목 + 해당 유형 추가 항목 표시
  - **전체 컬럼 헤더 매핑 (DB 필드명 → 한글 표시명)**:

| # | DB 필드명 | 한글 헤더 | 기본 너비(px) |
|---|-----------|----------|-------------|
| 1 | `id` | ID | 80 |
| 2 | `asset_uid` | 자산번호 | 170 |
| 3 | `name` | 자산명 | 230 |
| 4 | `assets_status` | 상태 | 130 |
| 5 | `supply_type` | 지급형태 | 130 |
| 6 | `supply_end_date` | 지급만료일 | 170 |
| 7 | `category` | 유형 | 130 |
| 8 | `serial_number` | 시리얼번호 | 180 |
| 9 | `model_name` | 모델명 | 170 |
| 10 | `vendor` | 제조사 | 140 |
| 11 | `network` | 네트워크 | 130 |
| 12 | `physical_check_date` | 실사일 | 170 |
| 13 | `confirmation_date` | 확인일 | 170 |
| 14 | `normal_comment` | 일반비고 | 220 |
| 15 | `oa_comment` | OA비고 | 220 |
| 16 | `mac_address` | MAC주소 | 150 |
| 17 | `building1` | 건물(대) | 140 |
| 18 | `building` | 건물 | 130 |
| 19 | `floor` | 층 | 110 |
| 20 | `owner_name` | 소유자 | 140 |
| 21 | `owner_department` | 소유부서 | 150 |
| 22 | `user_name` | 사용자 | 140 |
| 23 | `last_active_at` | 접속현황 | 60 |
| 24 | `user_department` | 사용부서 | 150 |
| 25 | `admin_name` | 관리자 | 140 |
| 26 | `admin_department` | 관리부서 | 150 |
| 27 | `location_drawing_id` | 도면ID | 150 |
| 28 | `location_row` | 위치(행) | 90 |
| 29 | `location_col` | 위치(열) | 90 |
| 30 | `location_drawing_file` | 도면파일 | 250 |
| 31 | `user_id` | 등록자ID | 80 |
| 32 | `created_at` | 등록일 | 170 |
| 33 | `updated_at` | 수정일 | 170 |

  > **열 표시 설정**: 사용자가 체크박스로 컬럼 표시/숨김 전환 및 드래그로 순서 변경 가능 (기본: 전체 표시)
  > **접속현황 컬럼(#23)**: `assets.last_active_at` 컬럼의 최종 접속 시각 기준으로 6.4 접속현황 인디케이터를 표시합니다. 셀에는 텍스트 대신 색상 동그라미 위젯이 렌더링됩니다.

  - **30개 항목 단위 페이지네이션** (하단 페이지 번호 또는 무한 스크롤)
  - 현재 페이지 / 전체 페이지 표시
- **행 클릭 → 자산 상세 페이지 이동** (`/asset/:id`)
  - 상세 페이지에서 공통 정보 + 유형별 specifications 확인
  - 인라인 편집 모드 전환 가능
- **필터/정렬**:
  - 상단 필터바: 유형별, 상태별, 지급형태별, 건물별 필터
  - 정렬 옵션: 자산번호순(기본), 등록일순, 상태순
- **검색**: 자산번호, 자산명, 시리얼번호로 즉시 검색
- **슬라이드 액션**: 좌측 스와이프 → 편집/삭제 버튼

#### 4.1.2 자산 등록
- 자산 정보 입력 폼 → 서버 전송 → QR 코드 생성 및 다운로드
- 지급형태(`supply_type`) 선택: 지급 / 렌탈 / 대여 / 창고(대기) / 창고(점검)
- 유형(category) 선택 시 해당 specifications 입력 폼 동적 표시
- 담당 정보 입력: `소유자명/소유자부서`, `사용자명/사용자부서`, `관리자명/관리자부서`
- **자산번호(`asset_uid`) 부여 기준**
  - 기준 형식: `등록경로(대문자 1자리) + 등록장비(대문자 2자리) + 숫자 5자리`
  - 검증 정규식: `^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|SM)[0-9]{5}$`
  - 예시: `BDT00001`, `RNB00027`, `CSV10342`

| 등록경로 | 코드 | 의미 |
|------|------|------|
| Buy | `B` | 구매 |
| Rental | `R` | 렌탈 |
| Contact | `C` | 계약 |
| Lease | `L` | 리스 |
| Spot | `S` | 스팟 |

| 등록장비 | 코드 | 의미 |
|------|------|------|
| DeskTop (iMac 포함) | `DT` | 데스크탑 |
| NoteBook | `NB` | 노트북 |
| MoNitor | `MN` | 모니터 |
| PRinter | `PR` | 프린터 |
| TaBlet | `TB` | 태블릿 |
| SCanner | `SC` | 스캐너 |
| IP Phone | `IP` | IP 전화기 |
| NetWork | `NW` | 네트워크 장비 |
| SerVer | `SV` | 서버 |
| Wearable | `WR` | 웨어러블 |
| SpecialDevice | `SD` | 특수목적장비 |
| SMartphone | `SM` | 테스트폰 |

#### 4.1.3 자산 수정
- 상세 페이지에서 편집 버튼 클릭 → 인라인 편집 모드
- 공통 정보 + 유형별 사양 수정 가능
- 담당 정보(소유자/사용자/관리자 및 각 부서) 수정 가능

#### 4.1.4 자산 삭제
- 삭제 확인 다이얼로그 → 서버 DELETE 요청
- 관련 실사 기록 존재 시 경고 표시

### 4.2 자산 실사

#### 4.2.1 QR 스캔 실사
1. 스캔 페이지 진입 → 카메라 권한 확인
2. QR 코드 스캔 → `asset_uid` 추출
3. 서버에서 자산 정보 조회
4. 실사 데이터 생성:
   - 위치 정보 입력 (건물, 층수, 자리번호)
   - 자산 상태 선택
   - **실사 사진 촬영**: 자산 현물 사진 촬영/첨부 (선택)
   - **친필 서명**: Signature Pad로 담당자 서명 입력
   - 서명 이미지 자동 저장 (PNG 포맷)
5. 서버 동기화 (온라인) 또는 로컬 저장 (오프라인)

#### 4.2.2 실사 기록 목록 (리스트)
> 실사 이력을 리스트 형식으로 조회하는 화면

- **리스트 구조**:
  - 한 줄에 한 실사 기록, 최신 실사일 기준 정렬
  - 각 행 표시 항목:

| 항목 | 설명 |
|------|------|
| 자산번호 | `asset_code` (asset_uid와 매칭) |
| 부서 | `user_team` (실사 담당자 소속) |
| 위치 | 건물/층/자리번호 (건물 A동 3F A-3) |
| 실사사진 | 사진 첨부 여부 아이콘 (O / X) |
| 실사사인 | 친필 서명 여부 아이콘 (O / X) |

  - **30개 항목 단위 페이지네이션**
- **행 클릭 → 실사 상세 페이지 이동**:
  - 실사 일시, 담당자, 자산 상태
  - 실사 사진 (촬영한 경우 이미지 표시)
  - 친필 서명 이미지
  - 점검 메모
  - 유지보수 담당자, 확인 부서
  - 동기화 상태
- **필터**:
  - 동기화 여부 (미동기화만 보기)
  - 서명 여부 (미서명만 보기)
  - 사진 여부 (사진 없음만 보기)

#### 4.2.3 실사 상세/권한/초기화
- **실사 상세 화면**: 사용자명, 사용자부서, 자산번호, 자산위치, 실사사진, 친필서명 표시
- **연결 동선**: 실사 목록에서 실사 자산 선택 → 실사 상세(`/inspection/:id`) 이동
- **자산 이동**: 실사 상세에서 자산번호 클릭 → 자산 상세(`/asset/:id`) 이동
- **완료 조건**: 필수 정보 입력 + 실사사진 첨부 + 친필서명 저장
- **수정 권한**:
  - 일반사용자: 완료된 실사(`completed=true`) 수정 불가
  - 관리자: 완료 여부와 무관하게 수정/초기화 가능
- **실사초기화**: 관리자만 실행 가능, 상태/사진/서명/메모를 초기화 후 재실사 상태로 전환

### 4.3 친필 서명 기능
- **서명 입력**: 터치/마우스로 자유롭게 서명
- **서명 미리보기**: 입력한 서명 실시간 확인
- **재작성**: 서명 지우기 및 다시 작성
- **저장**: PNG 이미지로 변환 후 로컬/서버 저장
- **서명 검증**: 실사 기록에 서명 이미지 포함 여부 확인

### 4.4 도면 관리 기능
#### 4.4.1 도면 등록 및 관리
- **도면 추가**:
  - 건물명 및 층수 선택
  - 이미지 파일 업로드 (PNG, JPG, PDF)
  - 격자 설정: 가로/세로 격자 수 입력 (예: 10x8)
  - 도면 저장 → 서버 업로드
- **도면 삭제**:
  - 도면 목록에서 선택
  - 삭제 확인 다이얼로그
  - 해당 도면 사용 중인 자산 경고 표시
- **도면 수정**:
  - 도면 이미지 교체
  - 격자 수 재설정
  - 건물/층 정보 수정

#### 4.4.2 도면 뷰어
- **도면 표시**:
  - 건물/층 선택 → 해당 도면 로드
  - 이미지 위에 격자 오버레이 표시
  - **확대/축소 제어** (PhotoView)
    - 최소 배율: **0.5배** (50%)
    - 최대 배율: **3.0배** (300%)
    - 배율 단위: **0.5배씩** 증감 (0.5x, 1.0x, 1.5x, 2.0x, 2.5x, 3.0x)
    - **제어 방식**: 버튼 전용 (+ / - 버튼)
    - **핀치 투 줌 비활성화** (사용 안 함)
    - 현재 배율 표시 (예: "1.0x", "2.5x")
    - **팬(Pan)**: 드래그로 이동 가능
- **자산 위치 표시**:
  - 격자 좌표(row, col)에 자산 마커 표시
  - 마커 클릭 → 자산 정보 팝업
  - 마커 색상: 자산 상태별 구분 (정상/점검필요/고장 등)
  - 줌 레벨에 따라 마커 크기 자동 조정
- **자산 위치 지정**:
  - 도면 뷰어에서 격자 셀 클릭
  - 해당 위치(row, col)를 자산에 할당
  - 실시간으로 마커 추가/이동

#### 4.4.3 격자 시스템
- **격자 좌표**: (row, col) 형식으로 위치 관리
- **격자 라벨**: 행(A, B, C...), 열(1, 2, 3...) 표시
- **자리번호**: 격자 좌표를 "A-3", "B-5" 형식으로 변환

### 4.5 실시간 현황
- **대시보드**: 총 자산 수, 실사 완료율, 미검증 자산 수
- **필터링**: 건물별, 부서별, 상태별, 지급형태별, 서명 유무별 필터
- **검색**: 자산 코드, 담당자 이름으로 검색
- **통계**: 건물별/부서별 실사 진행률 차트

---

## 5. 화면 구성

### 5.1 화면 목록
| 화면명 | 라우트 | 설명 |
|--------|--------|------|
| 로그인 | `/login` | 사번/비밀번호 입력, SNS 로그인 → 토큰 발급 |
| 홈 | `/` | 대시보드 (요약카드, 최신 등록 자산, 만료 임박 자산, 필터/검색/통계) |
| 스캔 | `/scan` | QR 코드 스캔 화면 (최대 5건 연속 스캔) |
| 자산 목록 | `/assets` | 전체 자산 목록 (자산번호 기준 리스트) |
| 자산 상세 | `/asset/:id` | 자산 정보 상세 및 편집 (사진/서명 포함) |
| 자산 등록 | `/asset/new` | 신규 자산 등록 (스캔에서 미등록 자산 발견 시 진입, 자산 상세와 동일 위젯 생성 모드) |
| 실사 목록 | `/inspections` | 실사 기록 목록 (리스트 형식) |
| 실사 상세 | `/inspection/:id` | 실사 기록 상세 (사용자/부서, 위치, 사진/서명, 권한 기반 수정) |
| 친필 서명 | `/signature` | 친필 서명 입력 (실사 상세에서 "사인하기" 버튼으로 진입) |
| **도면 관리** | `/drawings` | 건물/층별 도면 등록/관리 (새 지역 등록) |
| **도면 뷰어** | `/drawing/:id` | 도면 이미지 + 격자 + 자산 마커 뷰어 |
| 미검증 자산 | `/unverified` | 실사 미완료 자산 목록 (자산 목록에서 진입) |

> **공통 사항**: 로그인 화면을 제외한 **모든 페이지**에 네비게이션(BottomNavigationBar 또는 NavigationRail)과 Drawer가 기본 포함됩니다.

#### 5.1.1 로그인 (`/login`)
> 네비게이션/Drawer **없음** — 인증 전 단독 화면

| 영역 | 내용 |
|------|------|
| 상단 | 앱 로고 + 앱 이름 |
| 중앙 | 사번(ID) 입력란 + 비밀번호(PW) 입력란 |
| 중앙 하단 | **로그인** 버튼 (Primary, full-width) |
| 하단 | SNS 로그인 구분선 ("또는 SNS로 로그인") |
| 하단 버튼 | **카카오 로그인** 버튼 (노란색 `#FEE500`) + **구글 로그인** 버튼 (흰색 테두리) |

- 사번/비밀번호 로그인: `POST /api/auth/login`
- SNS 로그인: OAuth 2.0 기반 (카카오 SDK, Google Sign-In)
- 로그인 성공 → Access/Refresh Token 발급 → 홈(`/`) 이동

#### 5.1.2 홈 (`/`)
> 대시보드 — 주요 현황을 한눈에 파악

| 영역 | 내용 |
|------|------|
| 상단 카드 | 총 자산 수, 실사 완료율, 미검증 자산 수 요약 |
| **최신 등록 자산** | 최신순 등록 자산 리스트 **10건** 표시 (자산번호, 자산명, 유형, 등록일) |
| **만료 임박 자산** | 대여/렌탈 기간 만료 **7일 이내** 자산 리스트 (자산번호, 자산명, 지급형태, 만료일, D-day 표시) |
| **현황 필터** | 건물별, 부서별, 상태별, 지급형태별, 서명 유무별 필터 |
| **현황 검색** | 자산 코드, 담당자 이름 검색 |
| **통계 차트** | 건물별/부서별 실사 진행률 차트 |

- 최신 등록 자산: 행 클릭 → 자산 상세(`/asset/:id`) 이동
- 만료 임박 자산: `supply_type`이 "렌탈" 또는 "대여"이고 `supply_end_date` 기준 D-7 이내인 자산
- "더보기" 링크 → 자산 목록(`/assets`) 이동

#### 5.1.3 자산 목록 (`/assets`)
> 전체 자산을 리스트 형식으로 조회

| 영역 | 내용 |
|------|------|
| 상단 | 검색창 (자산번호/자산명/시리얼번호) + **검색** 버튼 |
| 상단 우측 | **미검증 자산** 버튼 → 미검증 자산 목록(`/unverified`) 이동 |
| 필터바 | 유형별, 상태별, 지급형태별, 건물별 드롭다운 필터 |
| 리스트 | 자산 리스트 (6.6 리스트 목록 스타일 적용) |
| 하단 | 페이지네이션 (페이지 번호 버튼, 이전/다음) |

- **30건 단위** 페이지네이션
- 리스트 행 표시: 자산번호 | 자산명 | 유형 | 상태 | 지급형태 | 건물/층
- **친필서명**: O / X 아이콘으로 유무만 표시
- **실사사진**: O / X 아이콘으로 유무만 표시
- 행 클릭 → 자산 상세(`/asset/:id`) 이동 (자산의 모든 정보 확인)
- **미검증 자산** 버튼 → 실사가 완료되지 않은 자산만 필터링하여 별도 화면(`/unverified`)으로 이동
- 슬라이드 액션: 좌측 스와이프 → 편집/삭제 버튼

#### 5.1.4 실사 목록 (`/inspections`)
> 실사 기록을 리스트 형식으로 조회

| 영역 | 내용 |
|------|------|
| 상단 | 검색창 (자산번호/담당자) + **검색** 버튼 |
| 상단 우측 | **실사초기화** 버튼 (선택한 실사 건 초기화) |
| 필터바 | 동기화 여부, 서명 여부, 사진 여부 필터 |
| 리스트 | 실사 기록 리스트 (6.6 리스트 목록 스타일 적용) |
| 하단 | 페이지네이션 (페이지 번호 버튼, 이전/다음) |

- **30건 단위** 페이지네이션
- 리스트 행 표시: 자산번호 | 부서 | 위치(건물/층/자리) | 실사일
- **친필서명**: O / X 아이콘으로 유무만 표시
- **실사사진**: O / X 아이콘으로 유무만 표시
- 행 클릭 → 실사 상세(`/inspection/:id`) 이동
- **실사초기화**: 선택한 실사 건의 상태/사진/서명/메모를 초기화하여 재실사 상태로 전환 (확인 다이얼로그 표시)

#### 5.1.5 자산 상세 / 자산 등록 (`/asset/:id`, `/asset/new`)
> 자산번호 기준으로 해당 자산의 모든 정보를 상세 표시하거나, 신규 자산을 등록

**조회 모드** (`/asset/:id` — 기존 자산 조회):

| 영역 | 내용 |
|------|------|
| 상단 | 자산번호(asset_uid) + 상태 뱃지 + 편집/삭제 버튼 |
| 공통 정보 | 자산명, 유형, 시리얼번호, 모델명, 제조사, 건물/층, 지급형태, 소유자명/부서, 사용자명/부서, 관리자명/부서 |
| 유형별 사양 | category에 따른 specifications 상세 (8.2 참고) |
| 상단 액션 | **자산수정** 버튼, **실사등록** 버튼 |
| **실사 사진** | 실사 촬영 사진 이미지 표시 (있을 경우) |
| **친필 서명** | 서명 이미지 표시 (있을 경우) |
| 실사 이력 | 해당 자산의 실사 기록 리스트 (최신순, 일시/담당자/상태/위치) |

- 실사 목록, 자산 목록 양쪽에서 진입 가능
- **자산수정** 버튼 → 인라인 편집 모드 전환 (조회 필드가 입력 필드로 전환)
- **실사등록** 버튼 → `POST /api/inspections`로 실사 생성 후, 생성된 `id`로 실사 상세(`/inspection/:id`) 화면 이동
- 실사 이력 행 클릭 → 실사 상세(`/inspection/:id`) 이동

**생성 모드** (`/asset/new` — 신규 자산 등록):

| 영역 | 내용 |
|------|------|
| 상단 | "자산 등록" 타이틀 |
| 입력 폼 | 조회 모드와 동일한 필드가 **모두 편집 상태**로 표시 |
| 하단 | **등록** 버튼 |

- **진입 경로**: 스캔(5.1.6)에서 미등록 자산 → **[자산 등록]** 버튼 → `/asset/new?uid={스캔된 코드}`
- 스캔에서 진입 시 `asset_uid` 필드에 스캔된 코드가 **자동 입력** (수정 불가)
- 필수 입력: 자산명, 유형(category), 자산번호(asset_uid)
- **등록** 버튼 → `POST /api/assets` → 등록 완료 후 자산 상세(`/asset/:id`)로 이동
- 동일한 `AssetDetailPage` 위젯을 재사용하되, 라우트 파라미터로 생성/조회 모드 분기

#### 5.1.6 스캔 (`/scan`)
> QR 코드 스캔으로 자산 확인 및 실사 등록

| 영역 | 내용 |
|------|------|
| 전체 화면 | 카메라 프리뷰 (QR 스캔 영역) |
| 하단 오버레이 | 스캔 결과 카드 (최대 **5건**까지 연속 스캔 가능) |

- **QR 스캔 → 보유 자산인 경우** (asset_uid가 DB에 존재):
  - 자산 정보 요약 카드 표시 (자산번호, 자산명, 유형)
  - **[자산 자세히보기]** 버튼 → 자산 상세(`/asset/:id`) 이동
  - **[실사 등록]** 버튼 → `POST /api/inspections` (asset_id 전달)로 실사 레코드 생성 → 생성된 `id`로 실사 상세(`/inspection/:id`) 화면 이동 (5.1.8과 동일 흐름, 별도 입력 폼 없음)
- **QR 스캔 → 보유 자산이 아닌 경우** (asset_uid가 DB에 없음):
  - "등록되지 않은 자산입니다" 안내
  - **[자산 등록]** 버튼 → `/asset/new?uid={스캔코드}` 이동 (자산 상세 화면의 **생성 모드**, 5.1.5 참고)
  - 자산 등록 완료 후 → 자산 상세(`/asset/:id`) 이동
- 최대 **5건** 연속 스캔: 스캔 결과가 하단에 리스트로 쌓임, 각각 독립 액션 가능
- 5건 초과 시 "스캔 초기화" 안내 → 리스트 클리어 후 재스캔

#### 5.1.7 도면 관리 (`/drawings`)
> 건물/층별 도면 등록 및 관리 — 새 지역(건물/층) 등록이 주 목적

| 영역 | 내용 |
|------|------|
| 상단 | **건물** 드롭다운 + **층** 드롭다운 선택 |
| 도면 목록 | 등록된 건물/층별 도면 리스트 (건물명, 층, 격자 설정, 등록일) |
| 하단 FAB | **+ 새 도면 등록** 버튼 |

**도면 목록 동작**:
- 행 클릭 → 도면 뷰어(`/drawing/:id`) 이동
- 슬라이드 액션: 좌측 스와이프 → 수정/삭제 버튼
- 건물/층 드롭다운으로 필터링

**새 도면 등록 (다이얼로그 또는 바텀시트)**:

| 입력 항목 | 설명 |
|-----------|------|
| 건물명 | 텍스트 입력 (예: "본관", "별관") |
| 층 | 텍스트 입력 (예: "3F", "지하1층") |
| 도면 이미지 | 이미지 업로드 (PNG, JPG, PDF) — `image_picker` |
| 격자 행 수 | 숫자 입력 (기본값: 10) |
| 격자 열 수 | 숫자 입력 (기본값: 8) |
| 설명 | 도면 설명 (선택) |

- 저장 → `POST /api/drawings` + Storage 이미지 업로드
- 동일 건물+층 조합 중복 시 에러 표시 ("이미 등록된 도면입니다")
- 도면 이미지가 **매칭되지 않은 건물/층** 선택 시: **"준비중"** 문구 표시

**도면 수정**:
- 도면 이미지 교체, 격자 수 재설정, 건물/층 정보 수정
- `PUT /api/drawings/:id`

**도면 삭제**:
- 해당 도면에 위치 지정된 자산이 있으면 경고 표시
- 삭제 확인 다이얼로그 → `DELETE /api/drawings/:id` + Storage 이미지 삭제

#### 5.1.7a 도면 뷰어 (`/drawing/:id`)
> 등록된 도면을 격자 + 자산 마커와 함께 조회하는 전용 뷰어

| 영역 | 내용 |
|------|------|
| 상단 | 건물명 + 층 정보 + 배율 표시 (예: "본관 3F — 1.0x") |
| 메인 | 도면 이미지 + 격자 오버레이 + 자산 마커 |
| 하단 | 확대(+) / 축소(-) 버튼 |

- **확대/축소**: 버튼 전용, 0.5배 단위 (0.5x ~ 3.0x), 핀치 투 줌 비활성화 (4.4.2 참고)
- **팬(Pan)**: 드래그로 이동
- **자산 마커**: 격자 좌표(row, col)에 상태별 색상 마커 표시 (6.3 색상 참고)
- 마커 클릭 → 자산 정보 팝업 (자산번호, 자산명, 유형, 상태)
- 팝업 내 **[자산 상세]** 버튼 → 자산 상세(`/asset/:id`) 이동
- **자산 위치 지정**: 격자 셀 클릭 → 자산 선택 다이얼로그 → 해당 위치(row, col) 할당

#### 5.1.8 실사 상세 (`/inspection/:id`)
> 실사 데이터의 **조회 및 입력을 겸하는 단일 화면** — 별도 입력 폼 없이 이 화면에서 위치/사진/서명 등록을 모두 수행

| 영역 | 내용 |
|------|------|
| 상단 | 실사번호 + 실사일시 + 상태 |
| 기본 정보 | 사용자명, 사용자부서, 자산번호, 자산위치(건물/층/자리) |
| 증빙 정보 | 실사사진, 친필서명 |
| 하단 액션 | **사인하기** 버튼 + 저장/수정(권한 기반) |

- 진입 경로: 실사 목록(`/inspections`)에서 실사 자산 행 선택, 또는 자산 상세(5.1.5)의 실사등록 버튼
- 자산번호 클릭 → 자산 상세(`/asset/:id`) 이동
- **[사인하기]** 버튼 → 친필 서명 화면(`/signature`) 이동 → 서명 완료 후 본 화면으로 복귀 (서명 이미지 자동 반영)
- 모든 정보 입력 + 실사사진 첨부 + 친필서명 완료 후 저장되면, **일반사용자는 수정 불가**
- 완료 건의 수정/초기화는 관리자 권한에서만 가능

#### 5.1.9 친필 서명 (`/signature`)
> 실사 상세 화면에서 **[사인하기]** 버튼을 통해 진입하는 서명 전용 화면

| 영역 | 내용 |
|------|------|
| 상단 | "친필 서명" 타이틀 + 실사번호 표시 |
| 중앙 | **서명 패드** (400 × 400px, 흰색 배경, 검정 펜) |
| 하단 좌측 | **지우기** 버튼 (서명 초기화) |
| 하단 우측 | **확인** 버튼 (서명 저장 후 실사 상세로 복귀) |

- **진입 경로**: 실사 상세(`/inspection/:id`) → [사인하기] 버튼
- **서명 패드**: `signature` 패키지 사용, 터치/마우스로 자유롭게 서명
- **패드 크기**: 400 × 400 픽셀 고정 (반응형에서도 최대 400px, 화면이 작으면 화면 너비에 맞춤)
- **펜 설정**: 검정색(`#000000`), 두께 2.0px
- **실시간 미리보기**: 입력한 서명이 패드 위에 실시간 표시
- **지우기**: 서명 전체 초기화 → 빈 패드로 리셋
- **확인**: 서명 이미지를 PNG 포맷으로 변환 → `POST /api/inspections/:id/signature`로 Storage 업로드 → 실사 상세 화면으로 복귀 (서명 이미지 자동 반영)
- **뒤로 가기**: 서명 없이 복귀 시 "서명을 저장하지 않고 나가시겠습니까?" 확인 다이얼로그

#### 5.1.10 미검증 자산 (`/unverified`)
> 실사가 완료되지 않은 자산만 필터링하여 표시하는 목록 화면

| 영역 | 내용 |
|------|------|
| 상단 | "미검증 자산" 타이틀 + 미검증 자산 수 뱃지 |
| 검색 | 검색창 (자산번호/자산명/시리얼번호) + **검색** 버튼 |
| 필터바 | 유형별, 건물별 드롭다운 필터 |
| 리스트 | 미검증 자산 리스트 (6.6 리스트 목록 스타일 적용) |
| 하단 | 페이지네이션 (페이지 번호 버튼, 이전/다음) |

- **진입 경로**: 자산 목록(`/assets`)의 **[미검증 자산]** 버튼 또는 Drawer 메뉴
- **미검증 기준**: 해당 자산의 실사 기록 중 완료 상태(위치+사진+서명 모두 존재)인 건이 없는 자산
- **30건 단위** 페이지네이션
- 리스트 행 표시: 자산번호 | 자산명 | 유형 | 상태 | 건물/층 | 최종 실사일
- **친필서명**: O / X 아이콘으로 유무만 표시
- **실사사진**: O / X 아이콘으로 유무만 표시
- 행 클릭 → 자산 상세(`/asset/:id`) 이동
- 자산 상세에서 **[실사 등록]** 버튼으로 바로 실사 진행 가능

### 5.2 네비게이션

#### 공통 메뉴 항목
| 순서 | 아이콘 | 라벨 | 라우트 | 설명 |
|------|--------|------|--------|------|
| 1 | Home | 홈 | `/` | 대시보드 (자산 현황, 실사 진행률) |
| 2 | QrCodeScanner | 스캔 | `/scan` | QR 코드 스캔 실사 |
| 3 | ListAlt | 자산 목록 | `/assets` | 자산번호 기준 리스트 조회 |
| 4 | FactCheck | 실사 목록 | `/inspections` | 실사 기록 목록 |
| 5 | Map | 도면 | `/drawings` | 건물/층별 도면 관리 |

#### 공통 Drawer (사이드 메뉴)
모든 화면에서 접근 가능한 **Drawer** 메뉴:
| 항목 | 아이콘 | 설명 |
|------|--------|------|
| 사용자 정보 | Person | 상단 헤더: 사번, 이름, 고용형태, 소속 부서 표시 |
| 홈 | Home | 대시보드 이동 |
| 자산 목록 | ListAlt | 자산 목록 이동 |
| 실사 목록 | FactCheck | 실사 기록 목록 이동 |
| 도면 관리 | Map | 도면 관리 이동 |
| 미검증 자산 | Warning | 미검증 자산 목록 이동 |
| 다크 모드 | DarkMode | 다크 모드 ON/OFF 토글 스위치 (기본값: ON) — 별도 화면 없이 Drawer 내에서 즉시 전환 |
| 로그아웃 | Logout | 로그아웃 → 로그인 화면 이동 |

- 모바일: 햄버거 메뉴(AppBar leading) 또는 좌측 스와이프로 열기
- 웹/태블릿: NavigationRail 상단 메뉴 아이콘으로 열기

#### 반응형 조건
- **화면 너비 < 600px**: 모바일 레이아웃
  - **BottomNavigationBar** 사용
  - 하단에 위 5개 메뉴 아이콘 + 라벨 표시
  - 선택된 메뉴: Primary 색상 강조
  - **Drawer**: AppBar 햄버거 아이콘으로 접근
- **화면 너비 ≥ 600px**: 웹/태블릿 레이아웃
  - **NavigationRail** 사용 (좌측 사이드바)
  - 아이콘 + 라벨 세로 배치
  - 확장 버튼으로 라벨 표시/숨김 토글
  - **Drawer**: NavigationRail 상단 메뉴 아이콘으로 접근

#### 디자인
- **Material 3 디자인 시스템** 적용
- 다크 모드 지원 (기본값: ON, Drawer 내 토글로 전환)

---

## 6. UI/UX 디자인 가이드

### 6.1 디자인 시스템
- **Material 3 (Material You)** 기반
- **Dynamic Color**: 기기 테마 색상 연동 (Android 12+)

### 6.2 색상 팔레트
| 용도 | Light Mode | Dark Mode | 설명 |
|------|-----------|-----------|------|
| Primary | `#1565C0` | `#90CAF9` | 주요 버튼, 앱바, 선택 상태 |
| Secondary | `#2E7D32` | `#A5D6A7` | 보조 액션, 실사 완료 표시 |
| Error | `#C62828` | `#EF9A9A` | 에러, 삭제, 고장 상태 |
| Surface | `#FFFFFF` | `#1C1B1F` | 카드, 바텀시트 배경 |
| On Surface | `#1C1B1F` | `#E6E1E5` | 텍스트, 아이콘 |

### 6.3 자산 실시간 현황 색상
> 자산의 **현재 접속/운영 상태**를 나타내는 색상입니다. 도면 마커, 리스트 뱃지 등에 사용됩니다.
> ※ 8.1의 `assets_status`(자산현재진행상태), `supply_type`(자산지급형태)과는 별개의 개념입니다.

| 상태 | Light Mode | Dark Mode | 용도 |
|------|-----------|-----------|------|
| 정상 (사용) | `#4CAF50` (Green) | `#81C784` (Green 300) | 리스트 뱃지, 도면 마커 |
| 가용 | `#2196F3` (Blue) | `#64B5F6` (Blue 300) | 리스트 뱃지, 도면 마커 |
| 점검필요 | `#FF9800` (Orange) | `#FFB74D` (Orange 300) | 리스트 뱃지, 도면 마커 |
| 고장 | `#F44336` (Red) | `#E57373` (Red 300) | 리스트 뱃지, 도면 마커 |
| 이동 | `#9C27B0` (Purple) | `#BA68C8` (Purple 300) | 리스트 뱃지, 도면 마커 |

> **Dark Mode 원칙**: 어두운 배경에서 가독성을 위해 Light Mode 대비 채도를 낮추고 밝기를 높인 **Material 300 톤**을 사용합니다.

### 6.4 접속현황 인디케이터 색상
> 사용자의 **최종 접속 시점**을 기준으로 접속 상태를 시각적으로 표시합니다.
> `assets.last_active_at` 값과 `access_settings` 테이블의 임계값을 비교하여 결정합니다.

| 상태 | 조건 | Light Mode | Dark Mode | 표시 |
|------|------|-----------|-----------|------|
| 실시간 접속 | `last_active_at`이 `active_threshold_minutes` 이내 (기본 60분) | `#4CAF50` (Green) | `#81C784` (Green 300) | 초록색 동그라미 (숫자 없음) |
| 경과 1~31일 | 경과일 1 ~ `warning_threshold_days` (기본 31일) | `#8BC34A` (Light Green) | `#AED581` (Light Green 300) | 연두색 동그라미 + 경과일 숫자 |
| 접속 만료 | 경과일 > `warning_threshold_days` | `#F44336` (Red) | `#E57373` (Red 300) | 빨간색 동그라미 (숫자 없음) |
| 미접속 | `last_active_at`이 NULL (한번도 접속 안 함) | `#9E9E9E` (Grey) | `#757575` (Grey 600) | 회색 동그라미 (숫자 없음) |

> **경과일 계산**: `floor((현재 시각 − last_active_at) / 24시간)`
> **임계값 조회**: 앱 초기화 시 `access_settings` 테이블에서 `active_threshold_minutes`, `warning_threshold_days`를 조회하여 캐싱합니다.

#### 인디케이터 위젯 사양
- **크기**: 16×16dp (리스트 내), 24×24dp (상세 화면)
- **형태**: 원형 (`CircleAvatar` 또는 `Container` with `BoxShape.circle`)
- **경과일 숫자**: 원 내부 중앙 정렬, 폰트 크기 8sp (16dp) / 11sp (24dp), 흰색 텍스트
- **사용 위치**: 자산 목록의 사용자 컬럼 옆, 사용자 목록, 홈 대시보드

```
 예시 (라이트 모드)
 ●        ← 초록색: 실시간 접속중 (1시간 이내)
 ❶        ← 연두색 + "1": 1일 경과
 ❷        ← 연두색 + "2": 2일 경과
  ...
 ㉛       ← 연두색 + "31": 31일 경과
 ●        ← 빨간색: 31일 초과 (접속 만료)
 ●        ← 회색: 한번도 접속 안 함
```

### 6.5 타이포그래피
| 스타일 | 크기 | 용도 |
|--------|------|------|
| Title Large | 22sp | 화면 타이틀 |
| Title Medium | 16sp | 카드 헤더, 섹션 제목 |
| Body Large | 16sp | 본문 텍스트 |
| Body Medium | 14sp | 폼 입력, 일반 UI 텍스트 |
| Label Small | 11sp | 뱃지, 캡션, 도면 격자 라벨 |
| **List Item** | **10sp** | **리스트 목록 행 텍스트 (자산 목록, 실사 목록 등)** |

### 6.6 리스트 목록 스타일
> 자산 목록, 실사 목록 등 데이터 리스트 테이블에 적용되는 공통 스타일입니다.

- **행 텍스트 크기**: 10sp (6.5 List Item)
- **세로 구분선**: 투명 (표시 안 함)
- **가로 구분선**: 행 사이 가로줄만 표시

| 항목 | Light Mode | Dark Mode | 설명 |
|------|-----------|-----------|------|
| 가로 구분선 | `#E0E0E0` (Grey 300) | `#424242` (Grey 800) | 행 사이 1px 구분선 |
| 행 배경 (기본) | `#FFFFFF` (White) | `#1C1B1F` (Surface) | 기본 행 배경 |
| 행 배경 (호버/선택) | `#F5F5F5` (Grey 100) | `#2C2B2F` | 마우스 호버 또는 터치 피드백 |
| 헤더 행 배경 | `#FAFAFA` (Grey 50) | `#252428` | 컬럼 헤더 행 |
| 헤더 텍스트 | `#616161` (Grey 700) | `#9E9E9E` (Grey 500) | 컬럼 헤더 텍스트 색상 |

### 6.7 공통 UI 상태
모든 데이터 화면은 다음 **4가지 상태**를 반드시 구현:
| 상태 | UI |
|------|------|
| **로딩** | 중앙 CircularProgressIndicator 또는 Shimmer |
| **데이터 있음** | 정상 콘텐츠 표시 |
| **빈 상태** | 안내 일러스트 + 메시지 (예: "등록된 자산이 없습니다") |
| **에러** | 에러 메시지 + 재시도 버튼 |

---

## 7. API 연동 명세

### 7.1 엔드포인트
#### 7.1.1 인증 불필요 API
> 정책: **일반 조회(GET)는 인증 없이 가능**  
> (로그인/토큰 갱신 API도 인증 없이 호출 가능)

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/auth/login` | 로그인 (사번+비밀번호 → Access/Refresh Token 발급) |
| POST | `/api/auth/sns/kakao` | 카카오 SNS 로그인 (카카오 토큰 → Access/Refresh Token 발급) |
| POST | `/api/auth/sns/google` | 구글 SNS 로그인 (구글 토큰 → Access/Refresh Token 발급) |
| POST | `/api/auth/refresh` | 토큰 갱신 (Refresh Token → 새 Access Token 발급) |
| GET | `/api/assets` | 자산 목록 조회 |
| GET | `/api/assets/:id` | 자산 상세 조회 |
| GET | `/api/users` | 사용자(사원) 목록 조회 |
| GET | `/api/users/:id` | 사용자 상세 조회 |
| GET | `/api/inspections` | 실사 목록 조회 |
| GET | `/api/inspections/:id` | 실사 상세 조회 |
| GET | `/api/inspections/:id/photo` | 실사 사진 이미지 조회 |
| GET | `/api/inspections/:id/signature` | 실사 서명 이미지 조회 |
| GET | `/api/drawings` | 도면 목록 조회 |
| GET | `/api/drawings/:id` | 도면 상세 조회 |
| GET | `/api/drawings/:id/assets` | 도면 내 자산 목록 조회 |

#### 7.1.2 인증 필요 API
> 정책: **등록(POST) / 수정(PUT) / 삭제(DELETE)는 인증 필요**  
> 요청 헤더: `Authorization: Bearer {token}`

| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/auth/logout` | 로그아웃 (Refresh Token 무효화) |
| POST | `/api/assets` | 자산 등록 |
| PUT | `/api/assets/:id` | 자산 수정 |
| DELETE | `/api/assets/:id` | 자산 삭제 |
| POST | `/api/inspections` | 실사 기록 생성 |
| PUT | `/api/inspections/:id` | 실사 기록 수정 (완료 건은 관리자만 가능) |
| POST | `/api/inspections/:id/reset` | 실사 초기화 (관리자 전용) |
| DELETE | `/api/inspections/:id` | 실사 기록 삭제 |
| POST | `/api/inspections/:id/photo` | 실사 사진 이미지 업로드 |
| POST | `/api/inspections/:id/signature` | 실사 서명 이미지 업로드 |
| POST | `/api/drawings` | 도면 등록 (이미지 업로드 포함) |
| PUT | `/api/drawings/:id` | 도면 수정 |
| DELETE | `/api/drawings/:id` | 도면 삭제 |

### 7.2 요청/응답 예시

#### 로그인 요청
```json
// POST /api/auth/login
// 사번 + 비밀번호로 인증 → Access/Refresh Token 발급
{
  "employee_id": "EMP-2024-042",       // 사번 (8.3 users.employee_id와 매칭)
  "password": "********"               // 비밀번호 (평문 전송, HTTPS 필수)
}
```

#### SNS 로그인 요청 (카카오/구글)
```json
// POST /api/auth/sns/kakao 또는 POST /api/auth/sns/google
// 클라이언트에서 카카오/구글 SDK로 인증 후 발급받은 토큰을 서버에 전달
{
  "sns_token": "ya29.a0AfH6SMB...",          // SNS SDK에서 발급받은 Access Token
  "provider": "kakao"                         // "kakao" 또는 "google"
}
// ※ 응답 형식은 일반 로그인 응답과 동일 (아래 로그인 응답 참고)
```

#### 로그인 응답 (일반/SNS 공통)
```json
// 200 OK
// 토큰 + 로그인 사용자 기본 정보 반환 (Drawer 헤더 표시용)
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",   // 인증 필요 API 요청 시 Authorization 헤더에 포함
  "refresh_token": "eyJhbGciOiJIUzI1NiIs...",  // Access Token 만료 시 갱신용
  "token_type": "Bearer",                       // 토큰 타입
  "expires_in": 1800,                            // Access Token 만료 시간 (초, 30분)
  "user": {                                      // 로그인 사용자 정보 (8.3 users 스키마 기반)
    "id": 42,                                    // 사용자 PK
    "employee_id": "EMP-2024-042",               // 사번
    "employee_name": "홍길동",                     // 사원 이름
    "employment_type": "정규직",                   // 고용형태 (정규직/계약직/도급직)
    "organization_hq": "IT본부",                   // 소속 본부
    "organization_dept": "개발부",                  // 소속 부서
    "organization_team": "플랫폼팀",                // 소속 팀
    "work_building": "본관",                       // 근무 건물
    "work_floor": "3F"                            // 근무 층
  }
}
```

#### 토큰 갱신 요청/응답
```json
// POST /api/auth/refresh
// Access Token 만료 시 Refresh Token으로 새 Access Token 발급
// ※ Dio Interceptor에서 401 응답 시 자동 호출 (11.3 참고)

// 요청
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."    // 로그인 시 발급받은 Refresh Token
}

// 응답 (200 OK)
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",   // 새로 발급된 Access Token
  "token_type": "Bearer",
  "expires_in": 1800                             // 만료 시간 (초, 30분)
}
```

#### 로그아웃 요청
```json
// POST /api/auth/logout
// Refresh Token 무효화 → 서버 측 토큰 폐기
// ※ 클라이언트에서도 flutter_secure_storage의 토큰 삭제 필요
{
  "refresh_token": "eyJhbGciOiJIUzI1NiIs..."    // 무효화할 Refresh Token
}

// 응답: 204 No Content (본문 없음)
```

#### 자산 등록 요청
```json
// POST /api/assets
// 공통 항목 + category에 따른 specifications JSON 포함
{
  "asset_uid": "BDT00001",              // 자산 고유 코드 (등록경로+등록장비+숫자5자리)
  "name": "개발팀 데스크탑",               // 자산 명칭
  "assets_status": "사용",               // 자산현재진행상태 (사용/가용/이동/점검필요/고장)
  "supply_type": "지급",                 // 자산지급형태 (지급/렌탈/대여/창고(대기)/창고(점검))
  "category": "데스크탑",                 // 자산 분류 → specifications 구조 결정
  "serial_number": "SN-12345",          // 시리얼 번호
  "model_name": "Dell OptiPlex 7090",   // 모델명
  "vendor": "Dell",                     // 제조사
  "building": "본관",                    // 건물명
  "floor": "3F",                        // 층 정보
  "owner_name": "홍길동",                // 소유자명
  "owner_department": "경영지원팀",       // 소유자부서
  "user_name": "김개발",                 // 사용자명
  "user_department": "개발팀",            // 사용자부서
  "admin_name": "박관리",                // 관리자명
  "admin_department": "IT운영팀",         // 관리자부서
  "user_id": 42,                        // 담당 사용자 FK
  "specifications": {                   // category별 추가 사양 (8.2 참고)
    "ram_capacity": "16GB",
    "ram_slots": 2,
    "os_type": "Windows",
    "os_version": "11",
    "os_detail_version": "22H2"
  }
}
```

#### 자산 목록 조회 요청
```json
// GET /api/assets?page=1&size=30&category=데스크탑&supply_type=지급&building=본관
// 쿼리 파라미터:
//   page     - 페이지 번호 (기본 1)
//   size     - 페이지당 항목 수 (기본 30)
//   category - 유형 필터 (선택)
//   supply_type - 지급형태 필터 (선택)
//   assets_status - 상태 필터 (선택)
//   building - 건물 필터 (선택)
//   search   - 자산번호/자산명/시리얼번호 검색 (선택)
```

#### 자산 목록 조회 응답
```json
// 200 OK
{
  "total": 152,                          // 전체 자산 수
  "page": 1,                             // 현재 페이지
  "size": 30,                            // 페이지당 항목 수
  "total_pages": 6,                      // 전체 페이지 수
  "data": [
    {
      "id": 1,
      "asset_uid": "BDT00001",
      "name": "개발팀 데스크탑",
      "assets_status": "사용",
      "supply_type": "지급",
      "category": "데스크탑",
      "building": "본관",
      "floor": "3F",
      "owner_name": "홍길동",
      "owner_department": "경영지원팀",
      "user_name": "김개발",
      "user_department": "개발팀",
      "admin_name": "박관리",
      "admin_department": "IT운영팀",
      "specifications": { "ram_capacity": "16GB", "os_type": "Windows" }
    }
  ]
}
```

#### 실사 기록 생성 요청
```json
// POST /api/inspections
// QR 스캔 후 실사 데이터 저장
{
  "asset_uid": "BDT00001",              // 스캔한 자산 코드
  "inspector_name": "홍길동",             // 실사 담당자
  "user_team": "IT팀",                   // 담당자 소속
  "inspection_date": "2024-02-07T16:00:00Z",  // 실사 일시
  "inspection_building": "본관",          // 실사 확인 건물
  "inspection_floor": "3F",              // 실사 확인 층
  "inspection_position": "A-3",          // 실사 확인 자리번호
  "status": "정상",                       // 자산 상태
  "memo": "건물 A동 3층 확인 완료"          // 점검 메모
}
// ※ 사진/서명은 별도 엔드포인트로 업로드 (POST /api/inspections/:id/photo, /signature)
```

#### 실사 상세 조회 응답
```json
// GET /api/inspections/:id
// 200 OK
{
  "id": 501,
  "asset_id": 1,
  "asset_code": "BDT00001",
  "user_name": "김개발",
  "user_department": "개발팀",
  "inspection_building": "본관",
  "inspection_floor": "3F",
  "inspection_position": "A-3",
  "inspection_photo": "https://cdn.example.com/inspections/501/photo.jpg",
  "signature_image": "https://cdn.example.com/inspections/501/signature.png",
  "completed": true
}
```

#### 실사 초기화 요청/응답 (관리자 전용)
```json
// POST /api/inspections/:id/reset
// 요청
{
  "reason": "재실사 필요"
}

// 응답 (200 OK)
{
  "id": 501,
  "completed": false,
  "inspection_photo": null,
  "signature_image": null,
  "memo": "재실사 필요"                    // 요청 시 전달한 reason이 memo에 저장됨
}
```

#### 실사 권한 정책
- 완료 기준: 필수 정보 입력 + 실사사진 + 친필서명 저장
- 일반사용자: `completed=true`인 실사에 대해 `PUT /api/inspections/:id`, `POST /api/inspections/:id/reset` 불가
- 관리자: 실사 수정/초기화 가능
- 권한 위반 시: `403 Forbidden`

---

## 8. 데이터 모델 (DB 스키마)

### 8.1 assets (자산 정보)
| 컬럼 | 타입 | 설명                  |
| --- | --- |---------------------|
| `id` | INTEGER | 자산 기본 키             |
| `asset_uid` | TEXT | 자산 고유 코드(실사 시 매칭 키, 형식: 등록경로1자리+등록장비2자리+숫자5자리) |
| `name` | TEXT | 자산 명칭               |
| `assets_status` | TEXT | 자산현재진행상태 (사용/가용/이동/점검필요/고장 등) |
| `supply_type` | TEXT | 자산지급형태 (지급/렌탈/대여/창고(대기)/창고(점검)) |
| `supply_end_date` | DATETIME | 대여/렌탈 만료일 (supply_type이 렌탈/대여일 때 사용) |
| `category` | TEXT | 자산 분류(데스크탑/모니터/노트북/IP전화기/스캐너/프린터/태블릿/테스트폰/네트워크장비/서버/웨어러블/특수목적장비) |
| `serial_number` | TEXT | 시리얼 번호              |
| `model_name` | TEXT | 모델명                 |
| `vendor` | TEXT | 제조사                 |
| `network` | TEXT | 네트워크 구분             |
| `physical_check_date` | DATETIME | 실물 점검일              |
| `confirmation_date` | DATETIME | 관리자 확인일             |
| `normal_comment` | TEXT | 일반 메모               |
| `oa_comment` | TEXT | OA 관련 메모            |
| `mac_address` | TEXT | MAC 주소              |
| `building1` | TEXT | 사용자 유형(내부/외부 등)     |
| `building` | TEXT | 건물명                 |
| `floor` | TEXT | 층 정보                |
| `owner_name` | TEXT | 소유자명                |
| `owner_department` | TEXT | 소유자부서              |
| `user_name` | TEXT | 사용자명                |
| `user_department` | TEXT | 사용자부서              |
| `admin_name` | TEXT | 관리자명                |
| `admin_department` | TEXT | 관리자부서              |
| `location_drawing_id` | INTEGER | 도면 ID               |
| `location_row` | INTEGER | 도면 좌표(행)            |
| `location_col` | INTEGER | 도면 좌표(열)            |
| `location_drawing_file` | TEXT | 도면 파일명              |
| `created_at` | DATETIME | 생성일                 |
| `updated_at` | DATETIME | 수정일                 |
| `user_id` | INTEGER | 자산 담당 사용자 FK        |
| `specifications` | JSON | 자산 유형별 추가 사양 (하이브리드 방식) |

> **설계 방침**: 공통 항목은 assets 테이블 컬럼으로 관리하고, 자산 유형(category)별로 다른 추가 사양은 `specifications` JSON 컬럼에 저장합니다. 이 하이브리드 방식은 공통 필드의 검색/정렬 성능을 유지하면서, 자산 유형별 확장에 유연하게 대응할 수 있습니다.

### 8.2 자산 유형별 specifications JSON 구조

#### 데스크탑 (`category: "데스크탑"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `ram_capacity` | TEXT | 램 용량 (예: "16GB", "32GB") |
| `ram_slots` | INTEGER | 램 슬롯 수 (예: 2, 4) |
| `os_type` | TEXT | OS 종류 (예: "Windows", "Linux", "macOS") |
| `os_version` | TEXT | OS 버전 (예: "11", "10") |
| `os_detail_version` | TEXT | OS 상세 버전 (예: "22H2", "23H1") |

```json
{
  "ram_capacity": "16GB",
  "ram_slots": 2,
  "os_type": "Windows",
  "os_version": "11",
  "os_detail_version": "22H2"
}
```

#### 모니터 (`category: "모니터"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `size_inch` | REAL | 화면 크기 (인치, 예: 27.0) |
| `resolution` | TEXT | 해상도 (예: "2560x1440", "1920x1080") |
| `is_4k` | BOOLEAN | 4K 지원 여부 (true/false) |

```json
{
  "size_inch": 27.0,
  "resolution": "2560x1440",
  "is_4k": true
}
```

#### IP전화기 (`category: "IP전화기"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `phone_number1` | TEXT | 전화번호1 (예: "02-1234-5678") |
| `phone_number2` | TEXT | 전화번호2 (예: "02-8765-4321") |
| `phone_number3` | TEXT | 전화번호3 (예: "02-5555-1234") |

```json
{
  "phone_number1": "02-1234-5678",
  "phone_number2": "02-8765-4321",
  "phone_number3": "02-5555-1234"
}
```

#### 노트북 (`category: "노트북"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `ram_capacity` | TEXT | 램 용량 (예: "16GB", "32GB") |
| `os_type` | TEXT | OS 종류 (예: "Windows", "macOS") |
| `os_version` | TEXT | OS 버전 (예: "11", "Sonoma") |
| `os_detail_version` | TEXT | OS 상세 버전 (예: "23H2") |
| `supports_5g` | BOOLEAN | 5G 지원 여부 (true/false) |

```json
{
  "ram_capacity": "16GB",
  "os_type": "Windows",
  "os_version": "11",
  "os_detail_version": "23H2",
  "supports_5g": false
}
```

#### 스캐너 (`category: "스캐너"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

#### 프린터 (`category: "프린터"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

#### 태블릿 (`category: "태블릿"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `ram_capacity` | TEXT | 램 용량 (예: "8GB", "12GB") |
| `os_type` | TEXT | OS 종류 (예: "Android", "iOS") |
| `os_version` | TEXT | OS 버전 (예: "14", "17.2") |
| `os_detail_version` | TEXT | OS 상세 버전 (예: "One UI 6.0") |
| `supports_5g` | BOOLEAN | 5G 지원 여부 (true/false) |
| `has_keyboard` | BOOLEAN | 키보드 지급 여부 (true/false) |
| `has_pen` | BOOLEAN | 펜 지급 여부 (true/false) |

```json
{
  "ram_capacity": "8GB",
  "os_type": "Android",
  "os_version": "14",
  "os_detail_version": "One UI 6.0",
  "supports_5g": true,
  "has_keyboard": true,
  "has_pen": false
}
```

#### 테스트폰 (`category: "테스트폰"`)
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `ram_capacity` | TEXT | 램 용량 (예: "8GB", "12GB") |
| `os_type` | TEXT | OS 종류 (예: "Android", "iOS") |
| `os_version` | TEXT | OS 버전 (예: "14", "17.2") |
| `os_detail_version` | TEXT | OS 상세 버전 (예: "One UI 6.0") |
| `supports_5g` | BOOLEAN | 5G 지원 여부 (true/false) |

```json
{
  "ram_capacity": "8GB",
  "os_type": "Android",
  "os_version": "14",
  "os_detail_version": "One UI 6.0",
  "supports_5g": true
}
```

#### 네트워크장비 (`category: "네트워크장비"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

#### 서버 (`category: "서버"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

#### 웨어러블 (`category: "웨어러블"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

#### 특수목적장비 (`category: "특수목적장비"`)
추가 관리 항목 없음 → `specifications`는 `{}` 또는 `null`

> **참고**: `specifications` JSON의 구조는 `category` 값에 따라 결정됩니다. 프론트엔드에서는 category별로 동적 폼을 렌더링하여 해당 필드만 입력받습니다. 향후 새로운 자산 유형이 추가되더라도 테이블 스키마 변경 없이 JSON 구조만 정의하면 됩니다.

### 8.3 users (사원 정보)
| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER | 사용자 기본 키 |
| `employee_id` | TEXT | 사번 |
| `employee_name` | TEXT | 사원 이름 |
| `employment_type` | TEXT | 고용형태 (정규직 / 계약직 / 도급직) |
| `organization_hq` | TEXT | 소속 본부 |
| `organization_dept` | TEXT | 소속 부서 |
| `organization_team` | TEXT | 소속 팀 |
| `organization_part` | TEXT | 파트 정보 |
| `organization_etc` | TEXT | 직책/기타 정보 |
| `work_building` | TEXT | 근무 건물 |
| `work_floor` | TEXT | 근무 층 |

> **참고**: 비밀번호(password_hash)는 백엔드에서만 관리하며, 프론트엔드에는 노출되지 않습니다. 인증은 `/api/auth/login` API를 통해서만 처리됩니다 (7.2 로그인 요청 참고).

### 8.4 asset_inspections (실사 기록)
| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | BIGINT | 실사 기본 키 (자동 증가) |
| `asset_id` | BIGINT | 자산 FK (ON DELETE RESTRICT) |
| `user_id` | BIGINT | 사용자 FK |
| `inspector_name` | TEXT | 실사 담당자 |
| `user_team` | TEXT | 담당자 팀 |
| `asset_code` | TEXT | 자산 코드(자산 UID와 매칭) |
| `asset_type` | TEXT | 자산 종류 |
| `asset_info` | JSONB | 모델명/용도/시리얼 등 상세 정보 |
| `inspection_count` | INTEGER | 실사 횟수 (트리거 자동 계산) |
| `inspection_date` | TIMESTAMPTZ | 실사 일시 |
| `maintenance_company_staff` | TEXT | 유지보수 담당자 |
| `department_confirm` | TEXT | 확인 부서 |
| `inspection_building` | TEXT | 실사 시 확인한 건물명 |
| `inspection_floor` | TEXT | 실사 시 확인한 층 정보 |
| `inspection_position` | TEXT | 실사 시 확인한 자리번호 (예: "A-3") |
| `status` | TEXT | 앱에서 병합된 상태(assets 상태와 동기화) |
| `memo` | TEXT | 점검 메모(점검자/소속/모델 등) |
| `inspection_photo` | TEXT | 실사 사진 이미지 Storage 경로 (JPG/PNG) |
| `signature_image` | TEXT | 친필 서명 이미지 Storage 경로 (PNG) |
| `synced` | BOOLEAN | 서버 동기화 여부 (기본값: true) |
| `created_at` | TIMESTAMPTZ | 생성일 |
| `updated_at` | TIMESTAMPTZ | 수정일 (트리거 자동 갱신) |

> **완료 판정 기준**: `inspection_building`, `inspection_floor`, `inspection_position`, `inspection_photo`, `signature_image` 5개 필드가 모두 NOT NULL이면 완료(completed)로 간주합니다. `completed`는 별도 컬럼이 아닌 API 응답에서 계산 필드로 제공됩니다 (백엔드 명세 4.5, 7.6 참고).

### 8.5 drawings (도면 정보)
| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER | 도면 기본 키 |
| `building` | TEXT | 건물명 (예: "본관", "별관") |
| `floor` | TEXT | 층 정보 (예: "3F", "지하1층") |
| `drawing_file` | TEXT | 도면 이미지 파일 경로 또는 URL |
| `grid_rows` | INTEGER | 격자 행 개수 (예: 10) |
| `grid_cols` | INTEGER | 격자 열 개수 (예: 8) |
| `description` | TEXT | 도면 설명 (선택 사항) |
| `created_at` | DATETIME | 생성일 |
| `updated_at` | DATETIME | 수정일 |

> **참고**: `assets` 테이블의 `location_drawing_id`는 `drawings.id`를 참조하며, `location_row`와 `location_col`은 도면 격자 좌표를 나타냅니다.

---

## 9. 상태 관리

### 9.1 Riverpod 기반 상태 관리
본 프로젝트는 **Flutter Riverpod**을 사용하여 상태를 관리합니다.

### 9.2 AssetNotifier
```dart
// 자산 목록 Notifier
@riverpod
class AssetNotifier extends _$AssetNotifier {
  @override
  Future<List<Asset>> build() async {
    return await fetchAssets();
  }

  Future<void> fetchAssets() async { ... }
  Future<void> updateAsset(Asset asset) async { ... }
  Future<void> deleteAsset(int id) async { ... }

  // 리스트 그룹화 (건물별, 부서별 등)
  Map<String, List<Asset>> getGroupedByBuilding() { ... }
}
```

### 9.3 InspectionNotifier
```dart
// 실사 기록 Notifier
@riverpod
class InspectionNotifier extends _$InspectionNotifier {
  @override
  Future<List<AssetInspection>> build() async {
    return await fetchInspections();
  }

  Future<void> createInspection(AssetInspection inspection) async { ... }
  List<AssetInspection> getUnsyncedInspections() { ... }
}
```

### 9.4 SignatureNotifier
```dart
// 서명 상태 Notifier
@riverpod
class SignatureNotifier extends _$SignatureNotifier {
  @override
  Uint8List? build() => null;

  void setSignature(Uint8List signature) { ... }
  void clearSignature() { ... }
}
```

### 9.5 AuthNotifier
```dart
// 인증 상태 Notifier
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  Future<AuthState> build() async {
    return await checkAuthStatus();
  }

  Future<void> login(String employeeId, String password) async { ... }
  Future<void> loginWithKakao() async { ... }
  Future<void> loginWithGoogle() async { ... }
  Future<void> logout() async { ... }
  Future<void> refreshToken() async { ... }
  bool get isLoggedIn { ... }

  // 로그인 사용자 정보 (Drawer 헤더 표시용: 사번, 이름, 고용형태, 소속 부서)
  User? get currentUser { ... }
}
```

### 9.6 DrawingNotifier
```dart
// 도면 관리 Notifier
@riverpod
class DrawingNotifier extends _$DrawingNotifier {
  @override
  Future<List<Drawing>> build() async {
    return await fetchDrawings();
  }

  Future<void> fetchDrawings() async { ... }
  Future<void> uploadDrawing(Drawing drawing, File imageFile) async { ... }
  Future<void> updateDrawing(Drawing drawing) async { ... }
  Future<void> deleteDrawing(int id) async { ... }

  // 건물/층별 도면 조회
  Drawing? getDrawingByBuildingAndFloor(String building, String floor) { ... }

  // 도면 내 자산 목록 조회
  Future<List<Asset>> getAssetsOnDrawing(int drawingId) async { ... }

  // 격자 좌표를 자리번호로 변환 (예: row=2, col=3 → "C-4")
  String getGridLabel(int row, int col) { ... }
}
```

---

## 10. 라우팅

### 10.1 GoRouter 설정
```dart
final router = GoRouter(
  redirect: (context, state) => /* 미인증 시 /login 리다이렉트 */,
  routes: [
    GoRoute(path: '/login', builder: (context, state) => LoginPage()),
    GoRoute(path: '/', builder: (context, state) => HomePage()),
    GoRoute(path: '/scan', builder: (context, state) => ScanPage()),
    GoRoute(path: '/assets', builder: (context, state) => AssetListPage()),
    GoRoute(path: '/asset/new', builder: (context, state) => AssetDetailPage(mode: CreateMode)),
    GoRoute(path: '/asset/:id', builder: (context, state) => AssetDetailPage()),
    GoRoute(path: '/inspections', builder: (context, state) => InspectionListPage()),
    GoRoute(path: '/inspection/:id', builder: (context, state) => InspectionDetailPage()),
    GoRoute(path: '/signature', builder: (context, state) => SignaturePage()),
    GoRoute(path: '/drawings', builder: (context, state) => DrawingManagerPage()),
    GoRoute(path: '/drawing/:id', builder: (context, state) => DrawingViewerPage()),
    GoRoute(path: '/unverified', builder: (context, state) => UnverifiedPage()),
  ],
);
```

---

## 11. 인증/보안

### 11.1 인증 방식
- **JWT (JSON Web Token)** 기반 인증
- 로그인 → Access Token + Refresh Token 발급
- Access Token: **인증 필요 API 요청 시** `Authorization: Bearer {token}` 헤더 포함
- Refresh Token: Access Token 만료 시 자동 갱신

### 11.2 로그인 플로우

#### 일반 로그인
1. 사번 + 비밀번호 입력
2. `POST /api/auth/login` → 토큰 발급
3. 토큰을 `flutter_secure_storage`에 암호화 저장
4. 이후 **인증 필요 API 요청에만** 토큰 자동 포함 (Dio Interceptor)

#### SNS 로그인 (카카오 / 구글)
1. SNS 로그인 버튼 클릭
2. 카카오 SDK 또는 Google Sign-In SDK로 인증 → SNS Access Token 획득
3. `POST /api/auth/sns/kakao` 또는 `POST /api/auth/sns/google` → SNS 토큰 전달
4. 서버에서 SNS 토큰 검증 → 사원 정보 매칭 → Access/Refresh Token 발급
5. 이후 흐름은 일반 로그인과 동일 (토큰 저장 → Dio Interceptor)

### 11.3 토큰 관리
| 항목 | 설명 |
|------|------|
| Access Token 만료 | 30분 (백엔드 협의) |
| Refresh Token 만료 | 7일 |
| 자동 갱신 | Dio Interceptor에서 401 응답 시 Refresh Token으로 재발급 |
| 강제 로그아웃 | Refresh Token 만료 시 로그인 화면 이동 |

### 11.4 보안 정책
- API 통신: **HTTPS 필수**
- 토큰 저장: `flutter_secure_storage` 권장 (암호화 저장)
- 민감 정보 (비밀번호 등) 로컬 저장 금지
- 앱 백그라운드 전환 시 화면 마스킹 (선택 사항)

---

## 12. 에러/예외 처리

### 12.1 API 에러 처리
| HTTP 상태 | 처리 |
|-----------|------|
| 400 Bad Request | 입력값 검증 에러 → 필드별 에러 메시지 표시 |
| 401 Unauthorized | Access Token 만료 → 자동 갱신 시도, 실패 시 로그인 이동 |
| 403 Forbidden | 권한 없음 → "접근 권한이 없습니다" 스낵바 |
| 404 Not Found | 리소스 없음 → "데이터를 찾을 수 없습니다" |
| 408 Timeout | 요청 시간 초과 → 재시도 버튼 표시 |
| 500 Server Error | 서버 오류 → "서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요" |

### 12.2 네트워크 에러
- **연결 없음**: 오프라인 모드 안내 배너 표시 + 로컬 데이터 사용
- **타임아웃**: 기본 30초, 재시도 버튼 제공
- **연결 복구**: 자동 감지 → 미동기화 데이터 자동 전송

### 12.3 사용자 입력 검증
- **필수 입력**: 미입력 시 빨간 테두리 + 에러 메시지
- **형식 검증**: 자산 UID(`^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|SM)[0-9]{5}$`), MAC 주소, 전화번호 등 포맷 체크
- **중복 검증**: 자산 UID 중복 시 경고

---

## 13. 오프라인/동기화 전략

### 13.1 오프라인 지원 범위
| 기능 | 오프라인 지원 | 설명 |
|------|-------------|------|
| 자산 목록 조회 | O | 마지막 동기화 캐시 데이터 표시 |
| QR 스캔 실사 | O | 로컬 저장 후 온라인 복귀 시 전송 |
| 친필 서명 | O | 서명 이미지 로컬 저장 |
| 자산 등록/수정 | O | 로컬 큐에 저장 후 동기화 |
| 도면 조회 | O | 캐시된 이미지 사용 |
| 도면 등록/삭제 | X | 온라인 필수 |

### 13.2 동기화 정책
- **동기화 시점**: 앱 시작 시 + 네트워크 복구 시 + 수동 새로고침
- **충돌 해결**: 서버 데이터 우선 (Server Wins), 로컬 변경분은 충돌 시 사용자에게 확인 요청
- **재시도 정책**: 실패 시 최대 3회 재시도 (지수 백오프: 1초 → 2초 → 4초)
- **동기화 상태 표시**: 각 레코드의 `synced` 필드로 미동기화 항목 필터링

### 13.3 로컬 저장소
- **Sqflite**: 자산/실사/사용자 데이터 로컬 캐싱
- **flutter_secure_storage**: Access Token, Refresh Token 암호화 저장
- **SharedPreferences**: 설정값, 마지막 동기화 시간
- **파일 시스템**: 서명 이미지 PNG, 도면 이미지 캐시

---

## 14. 로깅/모니터링

### 14.1 앱 로깅
| 레벨 | 용도 | 예시 |
|------|------|------|
| ERROR | 예외 발생, API 실패 | API 500 에러, 파싱 실패 |
| WARN | 비정상 동작 | 토큰 갱신 실패, 오프라인 전환 |
| INFO | 주요 사용자 행동 | 로그인, QR 스캔, 실사 저장 |
| DEBUG | 개발 디버깅 | API 요청/응답, 상태 변경 |

### 14.2 에러 추적
- **Firebase Crashlytics** (또는 Sentry) 연동
- 비정상 종료 자동 보고
- API 에러 자동 리포팅 (상태 코드, 요청 URL)

### 14.3 사용자 분석 (선택 사항)
- Firebase Analytics 또는 자체 로그 서버
- 주요 추적 이벤트: 로그인, QR 스캔, 실사 완료, 도면 조회

---

## 15. 개발 환경 설정

### 15.1 의존성 설치
```bash
flutter pub get
```

### 15.2 Riverpod 코드 생성 (필수)
Riverpod의 `@riverpod` 어노테이션을 사용하려면 코드 생성이 필요합니다.

```bash
# 일회성 코드 생성
dart run build_runner build

# 파일 변경 감지 및 자동 생성 (개발 시 권장)
dart run build_runner watch --delete-conflicting-outputs
```

### 15.3 환경 변수 설정
`.env` 파일 생성 (루트 디렉토리) 또는 `main.dart`에 직접 설정
```
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_ANON_KEY=eyJ...    # 공개 키 (RLS 적용, 클라이언트에서 사용)
```
> **참고**: `SUPABASE_URL`과 `SUPABASE_ANON_KEY`는 Supabase Dashboard > Settings > API에서 확인합니다. 백엔드 명세 2.2 참고.

---

## 16. 빌드 및 배포

### 16.1 로컬 실행
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web (HTTPS 필수)
flutter run -d chrome --web-port=8080 --web-hostname=localhost
```

### 16.2 프로덕션 빌드
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## 17. 권한 관리

### 17.1 카메라 권한
- **Android**: `AndroidManifest.xml`에 카메라 권한 추가
- **iOS**: `Info.plist`에 카메라 사용 설명 추가
- **Web**: HTTPS 환경에서만 작동, 브라우저 권한 허용 필요

### 17.2 저장소/갤러리 권한
- **Android**: 저장소 읽기/쓰기 권한 (도면 이미지 업로드, 서명 이미지 저장)
- **iOS**: 사진 라이브러리 접근 권한 (도면 이미지 선택)
- **용도**: image_picker를 통한 도면 이미지 선택, 서명 PNG 로컬 저장

### 17.3 권한 거부 시 처리
- 설정 화면으로 이동하는 버튼 표시
- 권한 요청 안내 다이얼로그

---

## 18. 테스트

### 18.1 테스트 플로우

#### 18.1.1 실사 테스트
1. 홈에서 "QR 코드 촬영" 버튼 클릭
2. QR 코드 스캔 → 자동으로 실사 화면 이동
3. 위치 정보 입력 (건물, 층수, 자리번호)
4. 자산 상태 선택
5. 메모 입력
6. **친필 서명 입력**:
   - 서명 버튼 클릭 → 서명 화면 이동
   - Signature Pad에 서명 작성
   - 확인 버튼으로 서명 저장
7. 실사 데이터 저장 (서버 동기화 또는 로컬 저장)
8. 실사 목록에서 미동기화 필터 확인
9. 자산 목록에서 건물별/부서별 그룹화 확인
10. 실사 목록에서 항목 선택 → 실사 상세(`/inspection/:id`) 진입 확인
11. 실사 상세에서 자산번호 클릭 → 자산 상세(`/asset/:id`) 이동 확인
12. 완료 상태(`completed=true`) 실사에 대해 일반사용자 수정/초기화 시 403 확인
13. 관리자 계정으로 동일 실사 수정/초기화 가능 확인

#### 18.1.2 자산 관리 테스트
1. **자산 등록**:
   - 자산 등록 화면 진입
   - 공통 정보 입력 (자산명, 시리얼번호, 모델명, 건물, 층, 소유자/사용자/관리자 및 각 부서)
   - 지급형태(supply_type) 선택 → 지급/렌탈/대여/창고(대기)/창고(점검) 확인
   - 자산 유형(category) 선택 → 해당 유형의 추가 사양 폼 동적 표시 확인
   - 데스크탑 선택 시: 램용량, 램슬롯수, OS종류, OS버전, OS상세버전 입력 폼 확인
   - 모니터 선택 시: 인치, 해상도, 4K여부 입력 폼 확인
   - 태블릿 선택 시: 키보드/펜 지급 여부 체크박스 확인
   - 스캐너/프린터 선택 시: 추가 사양 폼 없음 확인
   - 저장 → specifications JSON 정상 저장 확인
2. **자산 수정**:
   - 자산 상세 화면에서 편집 모드 진입
   - 공통 정보 및 유형별 사양 수정
   - 저장 → 서버 반영 확인
3. **자산 삭제**:
   - 자산 목록에서 슬라이드 삭제 또는 상세 화면 삭제
   - 삭제 확인 다이얼로그 표시 확인
   - 삭제 후 목록 갱신 확인

#### 18.1.3 도면 관리 테스트
1. **도면 추가**:
   - 도면 관리 화면 진입
   - "도면 추가" 버튼 클릭
   - 건물명 입력 (예: "본관")
   - 층수 입력 (예: "3F")
   - 이미지 업로드 (갤러리 또는 파일 선택)
   - 격자 설정 (행: 10, 열: 8)
   - 저장 → 서버 업로드 확인
2. **도면 뷰어 테스트**:
   - 도면 목록에서 특정 도면 선택
   - 도면 이미지 + 격자 오버레이 표시 확인
   - 확대/축소/팬 제스처 작동 확인
   - 자산 마커 표시 확인 (상태별 색상 구분)
   - 마커 클릭 → 자산 정보 팝업 확인
3. **자산 위치 지정 테스트**:
   - 자산 상세 화면에서 "위치 지정" 버튼 클릭
   - 도면 뷰어 열림
   - 격자 셀 클릭 → 자산 위치 저장
   - 도면에 마커 표시 확인
4. **도면 삭제 테스트**:
   - 도면 목록에서 삭제 버튼 클릭
   - 사용 중인 자산 경고 표시 확인
   - 삭제 확인 → 도면 제거 확인

#### 18.1.4 인증 테스트
1. **로그인**:
   - 로그인 화면 진입
   - 사번 + 비밀번호 입력
   - 로그인 버튼 클릭 → Access/Refresh Token 발급 확인
   - 토큰 로컬 저장 확인 (flutter_secure_storage)
   - 홈 화면 자동 이동 확인
2. **토큰 만료 처리**:
   - Access Token 만료 시 자동 갱신 확인 (Dio Interceptor)
   - Refresh Token 만료 시 로그인 화면 강제 이동 확인
3. **로그아웃**:
   - 로그아웃 버튼 클릭 → 토큰 삭제 확인
   - 로그인 화면 이동 확인
   - 로그아웃 후 인증 필요 페이지 접근 시 리다이렉트 확인

#### 18.1.5 오프라인/동기화 테스트
1. **오프라인 모드 진입**:
   - 네트워크 끊김 → 오프라인 배너 표시 확인
   - 캐시된 자산 목록 정상 표시 확인
2. **오프라인 실사 생성**:
   - 오프라인 상태에서 QR 스캔 실사 생성
   - 로컬 저장 확인 (synced = false)
   - 실사 목록에서 미동기화 표시 확인
3. **동기화**:
   - 네트워크 복구 → 자동 동기화 시작 확인
   - 미동기화 데이터 서버 전송 확인
   - synced = true 변경 확인
   - 충돌 발생 시 사용자 확인 다이얼로그 표시 확인

### 18.2 단위 테스트
```bash
flutter test
```

---

## 19. 향후 작업 (TODO)

### 19.1 기능 개선
- [ ] 동기화 API 연동 및 미동기화 전송 큐
- [ ] 로컬 영속화 (Hive/Sqflite) 지원
- [ ] 카메라 라이트 토글/전면 카메라 전환
- [ ] 실사 검색 (자산 UID/메모)
- [ ] 엑셀 내보내기 기능
- [ ] **서명 필기 인식 (OCR)** - 서명자 이름 자동 추출
- [ ] **그룹화 필터 저장** - 사용자가 선택한 그룹화 옵션 저장
- [ ] **다중 서명** - 복수 담당자 서명 지원
- [ ] **서명 이력 조회** - 자산별 서명 이력 타임라인
- [ ] **도면 PDF 지원** - PDF 도면 렌더링 및 격자 오버레이
- [ ] **도면 일괄 업로드** - 여러 층의 도면을 한 번에 업로드
- [ ] **자산 위치 드래그 앤 드롭** - 마커를 드래그하여 위치 변경
- [ ] **도면 히트맵** - 자산 밀집도를 색상으로 표시
- [ ] **도면 자동 격자 생성** - AI/이미지 분석으로 격자 자동 설정

### 19.2 성능 최적화
- [ ] 이미지 압축 및 캐싱 (서명 이미지 포함)
- [ ] 페이지네이션 성능 개선 (Lazy Loading)
- [ ] 오프라인 모드 지원 (로컬 DB 동기화)
- [ ] Riverpod 코드 생성 최적화
- [ ] 그룹화된 리스트 렌더링 성능 개선
- [ ] **도면 이미지 캐싱** - 네트워크 사용량 최소화
- [ ] **도면 타일 렌더링** - 대용량 도면 분할 로딩
- [ ] **격자 오버레이 성능** - Canvas API 최적화

---

## 20. 참고사항

### 20.1 Git 브랜치 전략
- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 브랜치
- `feature/*`: 기능 개발 브랜치

### 20.2 코딩 컨벤션
- **Dart**: [Effective Dart](https://dart.dev/guides/language/effective-dart) 준수
- **파일명**: snake_case
- **클래스명**: PascalCase
- **변수/함수명**: camelCase

---

## 문의
프로젝트 관련 문의사항은 개발팀에 문의해주세요.
