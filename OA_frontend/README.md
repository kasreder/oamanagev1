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
| `provider` | ^6.0.0 | 상태 관리 |
| `go_router` | ^14.0.0 | 라우팅 및 네비게이션 |
| `mobile_scanner` | ^5.0.0 | QR 코드 스캔 |
| `permission_handler` | ^11.0.0 | 카메라 권한 관리 |
| `http` | ^1.0.0 | REST API 통신 |

---

## 3. 시스템 아키텍처

### 3.1 디렉토리 구조
```
lib/
├── main.dart                 # 앱 진입점
├── app_router.dart           # 라우팅 설정
├── models/                   # 데이터 모델
│   ├── asset.dart
│   ├── user.dart
│   └── asset_inspection.dart
├── providers/                # 상태 관리
│   ├── asset_provider.dart
│   └── inspection_provider.dart
├── screens/                  # 화면 UI
│   ├── home_page.dart
│   ├── scan_page.dart
│   ├── list_page.dart
│   └── detail_page.dart
├── widgets/                  # 재사용 컴포넌트
│   └── common/
└── services/                 # API 통신 레이어
    └── api_service.dart
```

### 3.2 상태 관리 패턴
- **Provider 패턴** 사용
- 각 도메인별로 독립적인 Provider 관리
- ChangeNotifier를 통한 UI 자동 갱신

---

## 4. 주요 기능 명세

### 4.1 자산 관리
- **등록**: 자산 정보 입력 폼 → 서버 전송 → QR 코드 생성
- **조회**: 자산 목록 페이지네이션 (20개/페이지)
- **수정**: 상세 페이지에서 인라인 편집
- **삭제**: 삭제 확인 다이얼로그 → 서버 DELETE 요청

### 4.2 QR 스캔 실사
1. 스캔 페이지 진입 → 카메라 권한 확인
2. QR 코드 스캔 → `asset_uid` 추출
3. 서버에서 자산 정보 조회
4. 실사 데이터 생성 (위치, 상태, 서명)
5. 서버 동기화 (온라인) 또는 로컬 저장 (오프라인)

### 4.3 실시간 현황
- **대시보드**: 총 자산 수, 실사 완료율, 미검증 자산 수
- **필터링**: 건물별, 부서별, 상태별 필터
- **검색**: 자산 코드, 담당자 이름으로 검색

---

## 5. 화면 구성

### 5.1 화면 목록
| 화면명 | 라우트 | 설명 |
|--------|--------|------|
| 홈 | `/` | 대시보드 및 주요 기능 진입 |
| 스캔 | `/scan` | QR 코드 스캔 화면 |
| 실사 목록 | `/inspections` | 실사 기록 목록 |
| 자산 상세 | `/asset/:id` | 자산 정보 상세 및 편집 |
| 미검증 자산 | `/unverified` | 실사 미완료 자산 목록 |

### 5.2 네비게이션
- **모바일**: BottomNavigationBar (홈/스캔/목록)
- **웹/태블릿**: NavigationRail (반응형)
- **Material 3 디자인** 적용

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

---

## 8. 상태 관리

### 8.1 AssetProvider
```dart
class AssetProvider extends ChangeNotifier {
  List<Asset> _assets = [];
  bool _isLoading = false;

  Future<void> fetchAssets() async { ... }
  Future<void> updateAsset(Asset asset) async { ... }
  Future<void> deleteAsset(int id) async { ... }
}
```

### 8.2 InspectionProvider
```dart
class InspectionProvider extends ChangeNotifier {
  List<AssetInspection> _inspections = [];

  Future<void> createInspection(AssetInspection inspection) async { ... }
  List<AssetInspection> getUnsyncedInspections() { ... }
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
    GoRoute(path: '/asset/:id', builder: (context, state) => DetailPage()),
  ],
);
```

---

## 10. 개발 환경 설정

### 10.1 의존성 설치
```bash
flutter pub get
```

### 10.2 환경 변수 설정
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
1. 홈에서 "QR 코드 촬영" 버튼 클릭
2. QR 코드 스캔 → 자동으로 실사 화면 이동
3. 위치 정보, 상태, 메모 입력
4. 서명 후 저장
5. 실사 목록에서 미동기화 필터 확인

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

### 14.2 성능 최적화
- [ ] 이미지 압축 및 캐싱
- [ ] 페이지네이션 성능 개선
- [ ] 오프라인 모드 지원

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
