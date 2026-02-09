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
- **자산 유형별 관리**: 데스크탑, 모니터, 노트북, IP전화기, 스캐너, 프린터, 태블릿, 테스트폰

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
| `flutter_riverpod` | ^2.5.0 | 상태 관리 (Provider 대신 사용) |
| `riverpod_annotation` | ^2.3.0 | Riverpod 코드 생성 |
| `go_router` | ^14.0.0 | 라우팅 및 네비게이션 |
| `mobile_scanner` | ^5.0.0 | QR 코드 스캔 |
| `permission_handler` | ^11.0.0 | 카메라 권한 관리 |
| `signature` | ^5.5.0 | 친필 서명 기능 |
| `dio` | ^5.4.0 | REST API 통신 (http 대신) |
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
  - 각 행 표시 항목: 자산번호 | 자산명 | 유형(category) | 상태 | 건물/층
  - **30개 항목 단위 페이지네이션** (하단 페이지 번호 또는 무한 스크롤)
  - 현재 페이지 / 전체 페이지 표시
- **행 클릭 → 자산 상세 페이지 이동** (`/asset/:id`)
  - 상세 페이지에서 공통 정보 + 유형별 specifications 확인
  - 인라인 편집 모드 전환 가능
- **필터/정렬**:
  - 상단 필터바: 유형별, 상태별, 건물별 필터
  - 정렬 옵션: 자산번호순(기본), 등록일순, 상태순
- **검색**: 자산번호, 자산명, 시리얼번호로 즉시 검색
- **슬라이드 액션**: 좌측 스와이프 → 편집/삭제 버튼

#### 4.1.2 자산 등록
- 자산 정보 입력 폼 → 서버 전송 → QR 코드 생성 및 다운로드
- 유형(category) 선택 시 해당 specifications 입력 폼 동적 표시

#### 4.1.3 자산 수정
- 상세 페이지에서 편집 버튼 클릭 → 인라인 편집 모드
- 공통 정보 + 유형별 사양 수정 가능

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
- **필터링**: 건물별, 부서별, 상태별, 서명 유무별 필터
- **검색**: 자산 코드, 담당자 이름으로 검색
- **통계**: 건물별/부서별 실사 진행률 차트

---

## 5. 화면 구성

### 5.1 화면 목록
| 화면명 | 라우트 | 설명 |
|--------|--------|------|
| 로그인 | `/login` | 사번/비밀번호 입력 → 토큰 발급 |
| 홈 | `/` | 대시보드 및 주요 기능 진입 |
| 스캔 | `/scan` | QR 코드 스캔 화면 |
| 자산 목록 | `/assets` | 전체 자산 목록 (자산번호 기준 리스트) |
| 자산 상세 | `/asset/:id` | 자산 정보 상세 및 편집 |
| 실사 목록 | `/inspections` | 실사 기록 목록 (리스트 형식) |
| 실사 상세 | `/inspection/:id` | 실사 기록 상세 (사진/서명/메모) |
| 친필 서명 | `/signature` | 실사 담당자 서명 입력 화면 |
| **도면 관리** | `/drawings` | 건물/층별 도면 추가/삭제/수정 |
| **도면 뷰어** | `/drawing/:id` | 도면 + 격자 + 자산 위치 표시 |
| 미검증 자산 | `/unverified` | 실사 미완료 자산 목록 |

### 5.2 네비게이션

#### 공통 메뉴 항목
| 순서 | 아이콘 | 라벨 | 라우트 | 설명 |
|------|--------|------|--------|------|
| 1 | Home | 홈 | `/` | 대시보드 (자산 현황, 실사 진행률) |
| 2 | QrCodeScanner | 스캔 | `/scan` | QR 코드 스캔 실사 |
| 3 | ListAlt | 자산 목록 | `/assets` | 자산번호 기준 리스트 조회 |
| 4 | FactCheck | 실사 목록 | `/inspections` | 실사 기록 목록 |
| 5 | Map | 도면 | `/drawings` | 건물/층별 도면 관리 |

#### 반응형 조건
- **화면 너비 < 600px**: 모바일 레이아웃
  - **BottomNavigationBar** 사용
  - 하단에 위 5개 메뉴 아이콘 + 라벨 표시
  - 선택된 메뉴: Primary 색상 강조
- **화면 너비 ≥ 600px**: 웹/태블릿 레이아웃
  - **NavigationRail** 사용 (좌측 사이드바)
  - 아이콘 + 라벨 세로 배치
  - 확장 버튼으로 라벨 표시/숨김 토글

#### 디자인
- **Material 3 디자인 시스템** 적용
- 다크 모드 지원 (선택 사항)

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

### 6.3 자산 상태별 색상
| 상태 | Light Mode | Dark Mode | 용도 |
|------|-----------|-----------|------|
| 정상 (사용) | `#4CAF50` (Green) | `#81C784` (Green 300) | 리스트 뱃지, 도면 마커 |
| 가용 | `#2196F3` (Blue) | `#64B5F6` (Blue 300) | 리스트 뱃지, 도면 마커 |
| 점검필요 | `#FF9800` (Orange) | `#FFB74D` (Orange 300) | 리스트 뱃지, 도면 마커 |
| 고장 | `#F44336` (Red) | `#E57373` (Red 300) | 리스트 뱃지, 도면 마커 |
| 이동 | `#9C27B0` (Purple) | `#BA68C8` (Purple 300) | 리스트 뱃지, 도면 마커 |

> **Dark Mode 원칙**: 어두운 배경에서 가독성을 위해 Light Mode 대비 채도를 낮추고 밝기를 높인 **Material 300 톤**을 사용합니다.

### 6.4 타이포그래피
| 스타일 | 크기 | 용도 |
|--------|------|------|
| Title Large | 22sp | 화면 타이틀 |
| Title Medium | 16sp | 카드 헤더, 섹션 제목 |
| Body Large | 16sp | 본문 텍스트 |
| Body Medium | 14sp | 리스트 항목, 폼 입력 |
| Label Small | 11sp | 뱃지, 캡션, 도면 격자 라벨 |

### 6.5 공통 UI 상태
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
| 메서드 | 경로 | 설명 |
|--------|------|------|
| POST | `/api/auth/login` | 로그인 (사번+비밀번호 → Access/Refresh Token 발급) |
| POST | `/api/auth/refresh` | 토큰 갱신 (Refresh Token → 새 Access Token 발급) |
| POST | `/api/auth/logout` | 로그아웃 (Refresh Token 무효화) |
| GET | `/api/assets` | 자산 목록 조회 |
| GET | `/api/assets/:id` | 자산 상세 조회 |
| POST | `/api/assets` | 자산 등록 |
| PUT | `/api/assets/:id` | 자산 수정 |
| DELETE | `/api/assets/:id` | 자산 삭제 |
| GET | `/api/users` | 사용자(사원) 목록 조회 |
| GET | `/api/users/:id` | 사용자 상세 조회 |
| GET | `/api/inspections` | 실사 목록 조회 |
| POST | `/api/inspections` | 실사 기록 생성 |
| PUT | `/api/inspections/:id` | 실사 기록 수정 |
| DELETE | `/api/inspections/:id` | 실사 기록 삭제 |
| POST | `/api/inspections/:id/photo` | 실사 사진 이미지 업로드 |
| GET | `/api/inspections/:id/photo` | 실사 사진 이미지 조회 |
| POST | `/api/inspections/:id/signature` | 실사 서명 이미지 업로드 |
| GET | `/api/inspections/:id/signature` | 실사 서명 이미지 조회 |
| **GET** | **`/api/drawings`** | **도면 목록 조회** |
| **GET** | **`/api/drawings/:id`** | **도면 상세 조회** |
| **POST** | **`/api/drawings`** | **도면 등록 (이미지 업로드 포함)** |
| **PUT** | **`/api/drawings/:id`** | **도면 수정** |
| **DELETE** | **`/api/drawings/:id`** | **도면 삭제** |
| **GET** | **`/api/drawings/:id/assets`** | **도면 내 자산 목록 조회** |

### 7.2 요청/응답 예시
```json
// POST /api/inspections
{
  "asset_uid": "OA-2024-001",
  "inspector_name": "홍길동",
  "user_team": "IT팀",
  "inspection_date": "2024-02-07T16:00:00Z",
  "status": "정상",
  "memo": "건물 A동 3층 확인 완료"
}
```

---

## 8. 데이터 모델 (DB 스키마)

### 8.1 assets (자산 정보)
| 컬럼 | 타입 | 설명                  |
| --- | --- |---------------------|
| `id` | INTEGER | 자산 기본 키             |
| `asset_uid` | TEXT | 자산 고유 코드(실사 시 매칭 키) |
| `name` | TEXT | 자산 명칭 또는 사용자        |
| `assets_status` | TEXT | 사용/가용/이동 등 자산 상태    |
| `category` | TEXT | 자산 분류(데스크탑/모니터/노트북/IP전화기/스캐너/프린터/태블릿/테스트폰) |
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
| `member_name` | TEXT | 관리자 이름              |
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

```json
{
  "phone_number1": "02-1234-5678",
  "phone_number2": "02-8765-4321"
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

> **참고**: `specifications` JSON의 구조는 `category` 값에 따라 결정됩니다. 프론트엔드에서는 category별로 동적 폼을 렌더링하여 해당 필드만 입력받습니다. 향후 새로운 자산 유형이 추가되더라도 테이블 스키마 변경 없이 JSON 구조만 정의하면 됩니다.

### 8.3 users (사원 정보)
| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER | 사용자 기본 키 |
| `employee_id` | TEXT | 사번 |
| `employee_name` | TEXT | 사원 이름 |
| `organization_hq` | TEXT | 소속 본부 |
| `organization_dept` | TEXT | 소속 부서 |
| `organization_team` | TEXT | 소속 팀 |
| `organization_part` | TEXT | 파트 정보 |
| `organization_etc` | TEXT | 직책/기타 정보 |
| `work_building` | TEXT | 근무 건물 |
| `work_floor` | TEXT | 근무 층 |

### 8.4 asset_inspections (실사 기록)
| 컬럼 | 타입 | 설명 |
| --- | --- | --- |
| `id` | INTEGER 또는 TEXT | 실사 기본 키(없을 경우 `ins_{asset_uid}` 형태 생성) |
| `asset_id` | INTEGER | 자산 FK |
| `user_id` | INTEGER | 사용자 FK |
| `inspector_name` | TEXT | 실사 담당자 |
| `user_team` | TEXT | 담당자 팀 |
| `asset_code` | TEXT | 자산 코드(자산 UID와 매칭) |
| `asset_type` | TEXT | 자산 종류 |
| `asset_info` | JSON | 모델명/용도/시리얼 등 상세 정보 |
| `inspection_count` | INTEGER | 실사 횟수 |
| `inspection_date` | DATETIME | 실사 일시 |
| `maintenance_company_staff` | TEXT | 유지보수 담당자 |
| `department_confirm` | TEXT | 확인 부서 |
| `inspection_building` | TEXT | 실사 시 확인한 건물명 |
| `inspection_floor` | TEXT | 실사 시 확인한 층 정보 |
| `inspection_position` | TEXT | 실사 시 확인한 자리번호 (예: "A-3") |
| `status` | TEXT | 앱에서 병합된 상태(assets 상태와 동기화) |
| `memo` | TEXT | 점검 메모(점검자/소속/모델 등) |
| `inspection_photo` | TEXT | 실사 사진 이미지 파일 경로 또는 URL (JPG/PNG) |
| `signature_image` | TEXT | 친필 서명 이미지 파일 경로 또는 URL (PNG) |
| `synced` | BOOLEAN | 서버 동기화 여부 |

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
  Future<void> logout() async { ... }
  Future<void> refreshToken() async { ... }
  bool get isLoggedIn { ... }
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
- Access Token: API 요청 시 `Authorization: Bearer {token}` 헤더 포함
- Refresh Token: Access Token 만료 시 자동 갱신

### 11.2 로그인 플로우
1. 사번 + 비밀번호 입력
2. `POST /api/auth/login` → 토큰 발급
3. 토큰을 `SharedPreferences` (또는 `flutter_secure_storage`)에 저장
4. 이후 모든 API 요청에 토큰 자동 포함 (Dio Interceptor)

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
- **형식 검증**: MAC 주소, 전화번호 등 포맷 체크
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
- **SharedPreferences**: 설정값, 토큰, 마지막 동기화 시간
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
`.env` 파일 생성 (루트 디렉토리)
```
API_BASE_URL=https://api.oamanager.com
```

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

#### 18.1.2 자산 관리 테스트
1. **자산 등록**:
   - 자산 등록 화면 진입
   - 공통 정보 입력 (자산명, 시리얼번호, 모델명, 건물, 층 등)
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
