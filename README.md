<!-- Path: README.md -->

# OA Manage v1

OA 자산 실사 관리 앱입니다. 에셋 JSON을 로드하여 실사 목록을 관리하고, QR 스캔으로 신규 실사를 생성합니다.

## 주요 기능
- 홈/스캔/실사 목록/미검증 자산 화면 제공
- 모바일/웹 카메라 권한 안내 및 QR 스캔 처리
- 실사 상세 편집, 삭제, 미동기화 필터링
- Material 3 및 반응형 NavigationBar/NavigationRail 적용

## 더미 데이터
에셋 JSON은 `assets/dummy/mock` 아래에 위치하며, `pubspec.yaml`에 등록되어 있습니다.
```
assets/dummy/mock/users.json
assets/dummy/mock/assets.json
assets/dummy/mock/asset_inspections.json
```

## DB 스키마 요약
더미 JSON 구조를 기반으로 한 주요 테이블(또는 컬렉션)의 스키마입니다. 실제 구현 시 RDB 또는 NoSQL에 맞춰 타입을 조정하면 됩니다.

### assets (자산 정보)
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

### users (사원 정보)
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

### asset_inspections (실사 기록)
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

## 개발 환경
- Flutter 3.22.x 이상 (Dart 3.7)
- 주요 패키지: provider, go_router, mobile_scanner, permission_handler

## 실행 방법
1. 의존성 설치
   ```bash
   flutter pub get
   ```
2. 앱 실행 (예: Android 에뮬레이터 또는 Chrome)
   ```bash
   flutter run
   ```

## 권한 안내
- 모바일 기기에서 카메라 권한이 필요합니다. 권한을 거부하면 스캔 화면에서 설정으로 이동하는 버튼이 노출됩니다.
- 웹에서는 HTTPS 환경에서만 카메라 사용이 가능하며, 브라우저 권한 허용이 필요합니다.

## 테스트 플로우
1. 홈에서 "QR 코드 촬영" 버튼 또는 하단 버튼을 눌러 스캔 화면으로 이동합니다.
2. QR 코드를 스캔하면 신규 실사가 생성되고 상세 화면으로 이동합니다.
3. 상태/메모를 수정 후 저장합니다.
4. 실사 목록에서 미동기화 필터 토글을 확인합니다.

## 향후 작업(TODO)
- 동기화 API 연동 및 미동기화 전송 큐
- 로컬 영속화(Hive/Sqflite) 지원
- 카메라 라이트 토글/전면 카메라 전환
- 실사 검색(자산 UID/메모)


2. 지금 작업 중인 브랜치를 main으로 만들고 싶을 때
즉, codex/... 브랜치를 main 이름으로 바꾸려는 경우:

git branch -M main