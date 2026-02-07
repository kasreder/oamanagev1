# OA Manager v1 - 프론트엔드 명세서

## ⚠️ 중요 사항
> **본 문서는 OA 자산관리 시스템의 프론트엔드 개발 명세서입니다.**
> **DB 스키마 및 API 연동 규격은 반드시 백엔드팀과 협의 후 진행해야 합니다.**
> **QR 스캔 기능은 HTTPS 환경에서만 정상 작동합니다.**

---

## 1. 프로젝트 개요

### 1.1 목적
OA 자산의 효율적인 관리 및 실사를 위한 웹/모바일 통합 애플리케이션 개발

### 1.2 주요 기능
본 시스템은 다음 **세 가지 핵심 기능**을 제공합니다:

#### 1) 자산관리
- **자산 등록**: 신규 OA 자산 정보 입력 및 QR 코드 생성
- **자산 변경**: 기존 자산 정보 수정 (위치, 담당자, 상태 등)
- **자산 삭제**: 폐기/이관된 자산 삭제 처리

#### 2) 자산실사
- **위치 정보 관리**: 건물, 층수, 자리번호 기반 자산 위치 추적
- **QR 촬영 확인**: 모바일 카메라를 통한 QR 스캔으로 자산 실사
- **실사 사인**: 실사 담당자 서명 기능으로 책임 소재 명확화
- **실사 기록 저장**: 실사 일시, 담당자, 자산 상태 등 이력 관리

#### 3) 실시간 현황 파악
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

### 2.3 개발 도구 (dev_dependencies)
| 패키지명 | 버전 | 용도 |
|---------|------|------|
| `build_runner` | ^2.4.0 | Riverpod 코드 생성 |
| `riverpod_generator` | ^2.3.0 | Riverpod 어노테이션 프로세서 |
| `flutter_lints` | ^3.0.0 | Dart 코드 린트 |

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
│   └── drawing_notifier.dart      # 도면 상태 관리
├── screens/                       # 화면 UI
│   ├── home_page.dart             # 홈 대시보드
│   ├── scan_page.dart             # QR 스캔 화면
│   ├── list_page.dart             # 자산 리스트 (그룹화 표시)
│   ├── detail_page.dart           # 자산 상세 및 편집
│   ├── signature_page.dart        # 친필 서명 화면
│   ├── drawing_manager_page.dart  # 도면 관리 화면 (추가/삭제)
│   └── drawing_viewer_page.dart   # 도면 뷰어 (격자+자산위치)
├── widgets/                       # 재사용 컴포넌트
│   ├── common/                    # 공통 위젯
│   ├── signature_pad.dart         # 서명 패드 위젯
│   ├── grouped_asset_list.dart    # 그룹화된 자산 리스트
│   ├── drawing_grid_overlay.dart  # 도면 격자 오버레이
│   └── asset_marker.dart          # 도면 위 자산 마커
└── services/                      # API 통신 레이어
    ├── api_service.dart           # Dio 기반 API 서비스
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
- **등록**: 자산 정보 입력 폼 → 서버 전송 → QR 코드 생성 및 다운로드
- **조회**:
  - 자산 목록 페이지네이션 (20개/페이지)
  - **그룹화 리스트**: 건물별, 부서별, 상태별 그룹 표시
  - 슬라이드 액션 (편집/삭제)
- **수정**: 상세 페이지에서 인라인 편집
- **삭제**: 삭제 확인 다이얼로그 → 서버 DELETE 요청

### 4.2 QR 스캔 실사
1. 스캔 페이지 진입 → 카메라 권한 확인
2. QR 코드 스캔 → `asset_uid` 추출
3. 서버에서 자산 정보 조회
4. 실사 데이터 생성:
   - 위치 정보 입력 (건물, 층수, 자리번호)
   - 자산 상태 선택
   - **친필 서명**: Signature Pad로 담당자 서명 입력
   - 서명 이미지 자동 저장 (PNG 포맷)
5. 서버 동기화 (온라인) 또는 로컬 저장 (오프라인)

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
| 홈 | `/` | 대시보드 및 주요 기능 진입 |
| 스캔 | `/scan` | QR 코드 스캔 화면 |
| 실사 목록 | `/inspections` | 실사 기록 목록 (그룹화 표시) |
| 자산 목록 | `/assets` | 전체 자산 목록 (건물별/부서별 그룹화) |
| 자산 상세 | `/asset/:id` | 자산 정보 상세 및 편집 |
| 친필 서명 | `/signature` | 실사 담당자 서명 입력 화면 |
| **도면 관리** | `/drawings` | 건물/층별 도면 추가/삭제/수정 |
| **도면 뷰어** | `/drawing/:id` | 도면 + 격자 + 자산 위치 표시 |
| 미검증 자산 | `/unverified` | 실사 미완료 자산 목록 |

### 5.2 네비게이션

#### 반응형 조건
- **화면 너비 < 600px**: 모바일 레이아웃
  - BottomNavigationBar 사용
  - 주요 메뉴: 홈/스캔/목록
- **화면 너비 ≥ 600px**: 웹/태블릿 레이아웃
  - NavigationRail 사용 (좌측 사이드바)
  - 확장 가능한 메뉴 레이블

#### 디자인
- **Material 3 디자인 시스템** 적용
- 다크 모드 지원 (선택 사항)

---

## 6. API 연동 명세

### 6.1 엔드포인트
| 메서드 | 경로 | 설명 |
|--------|------|------|
| GET | `/api/assets` | 자산 목록 조회 |
| GET | `/api/assets/:id` | 자산 상세 조회 |
| POST | `/api/assets` | 자산 등록 |
| PUT | `/api/assets/:id` | 자산 수정 |
| DELETE | `/api/assets/:id` | 자산 삭제 |
| GET | `/api/inspections` | 실사 목록 조회 |
| POST | `/api/inspections` | 실사 기록 생성 |
| **GET** | **`/api/drawings`** | **도면 목록 조회** |
| **GET** | **`/api/drawings/:id`** | **도면 상세 조회** |
| **POST** | **`/api/drawings`** | **도면 등록 (이미지 업로드 포함)** |
| **PUT** | **`/api/drawings/:id`** | **도면 수정** |
| **DELETE** | **`/api/drawings/:id`** | **도면 삭제** |
| **GET** | **`/api/drawings/:id/assets`** | **도면 내 자산 목록 조회** |

### 6.2 요청/응답 예시
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

## 7. 데이터 모델 (DB 스키마)

### 7.1 assets (자산 정보)
| 컬럼 | 타입 | 설명                  |
| --- | --- |---------------------|
| `id` | INTEGER | 자산 기본 키             |
| `asset_uid` | TEXT | 자산 고유 코드(실사 시 매칭 키) |
| `name` | TEXT | 자산 명칭 또는 사용자        |
| `assets_status` | TEXT | 사용/가용/이동 등 자산 상태    |
| `category` | TEXT | 자산 분류(사무기기, 네트워크 등) |
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

### 7.2 users (사원 정보)
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

### 7.3 asset_inspections (실사 기록)
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
| `status` | TEXT | 앱에서 병합된 상태(assets 상태와 동기화) |
| `memo` | TEXT | 점검 메모(점검자/소속/모델 등) |
| `synced` | BOOLEAN | 서버 동기화 여부 |

### 7.4 drawings (도면 정보)
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

## 8. 상태 관리

### 8.1 Riverpod 기반 상태 관리
본 프로젝트는 **Flutter Riverpod**을 사용하여 상태를 관리합니다.

### 8.2 AssetNotifier
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

### 8.3 InspectionNotifier
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

### 8.4 SignatureNotifier
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

### 8.5 DrawingNotifier
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

## 9. 라우팅

### 9.1 GoRouter 설정
```dart
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => HomePage()),
    GoRoute(path: '/scan', builder: (context, state) => ScanPage()),
    GoRoute(path: '/inspections', builder: (context, state) => ListPage()),
    GoRoute(path: '/assets', builder: (context, state) => AssetListPage()),
    GoRoute(path: '/asset/:id', builder: (context, state) => DetailPage()),
    GoRoute(path: '/signature', builder: (context, state) => SignaturePage()),
    GoRoute(path: '/drawings', builder: (context, state) => DrawingManagerPage()),
    GoRoute(path: '/drawing/:id', builder: (context, state) => DrawingViewerPage()),
    GoRoute(path: '/unverified', builder: (context, state) => UnverifiedPage()),
  ],
);
```

---

## 10. 개발 환경 설정

### 10.1 의존성 설치
```bash
flutter pub get
```

### 10.2 Riverpod 코드 생성 (필수)
Riverpod의 `@riverpod` 어노테이션을 사용하려면 코드 생성이 필요합니다.

```bash
# 일회성 코드 생성
dart run build_runner build

# 파일 변경 감지 및 자동 생성 (개발 시 권장)
dart run build_runner watch --delete-conflicting-outputs
```

### 10.3 환경 변수 설정
`.env` 파일 생성 (루트 디렉토리)
```
API_BASE_URL=https://api.oamanager.com
```

---

## 11. 빌드 및 배포

### 11.1 로컬 실행
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web (HTTPS 필수)
flutter run -d chrome --web-port=8080 --web-hostname=localhost
```

### 11.2 프로덕션 빌드
```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## 12. 권한 관리

### 12.1 카메라 권한
- **Android**: `AndroidManifest.xml`에 카메라 권한 추가
- **iOS**: `Info.plist`에 카메라 사용 설명 추가
- **Web**: HTTPS 환경에서만 작동, 브라우저 권한 허용 필요

### 12.2 권한 거부 시 처리
- 설정 화면으로 이동하는 버튼 표시
- 권한 요청 안내 다이얼로그

---

## 13. 테스트

### 13.1 테스트 플로우

#### 13.1.1 실사 테스트
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

#### 13.1.2 도면 관리 테스트
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

### 13.2 단위 테스트
```bash
flutter test
```

---

## 14. 향후 작업 (TODO)

### 14.1 기능 개선
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

### 14.2 성능 최적화
- [ ] 이미지 압축 및 캐싱 (서명 이미지 포함)
- [ ] 페이지네이션 성능 개선 (Lazy Loading)
- [ ] 오프라인 모드 지원 (로컬 DB 동기화)
- [ ] Riverpod 코드 생성 최적화
- [ ] 그룹화된 리스트 렌더링 성능 개선
- [ ] **도면 이미지 캐싱** - 네트워크 사용량 최소화
- [ ] **도면 타일 렌더링** - 대용량 도면 분할 로딩
- [ ] **격자 오버레이 성능** - Canvas API 최적화

---

## 15. 참고사항

### 15.1 Git 브랜치 전략
- `main`: 프로덕션 배포 브랜치
- `develop`: 개발 브랜치
- `feature/*`: 기능 개발 브랜치

### 15.2 코딩 컨벤션
- **Dart**: [Effective Dart](https://dart.dev/guides/language/effective-dart) 준수
- **파일명**: snake_case
- **클래스명**: PascalCase
- **변수/함수명**: camelCase

---

## 문의
프로젝트 관련 문의사항은 개발팀에 문의해주세요.
