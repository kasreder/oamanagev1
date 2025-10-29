# 데이터베이스 구조 설계

> 현재 앱은 로컬 JSON과 로컬 파일 시스템을 사용하지만, 동일한 구조로 RDB/NoSQL 백엔드를 확장할 수 있도록 스키마를 정의한다.

## 개체 관계 개요
```
Users (1) ────< AssetAssignments >──── (1) Assets
     \                                 /
      \                               /
       └────────────< Inspections >──┘
                        |
                        └────< Signatures
```

- **Users**: 자산을 사용하는 직원 정보. 조직 계층 및 사번을 포함.
- **Assets**: OA 자산 기본 정보 및 자유 형식 메타데이터.
- **AssetAssignments**: 사용자와 자산의 소유 관계(옵션). 더미 데이터에서는 `assets` 테이블에 직접 포함되지만, 정규화를 대비해 분리.
- **Inspections**: 실사 기록. 스캔 시각, 상태, 메모, 담당자 등을 보관.
- **Signatures**: 인증 서명 이미지 및 메타데이터. 로컬 파일 경로/브라우저 스토리지 키를 참조.

## 테이블 상세

### users
| 컬럼 | 타입 | 제약 | 설명 |
| --- | --- | --- | --- |
| id | BIGINT | PK | 사용자 고유 ID (`assets/users.json`의 `id`). |
| employee_id | VARCHAR(32) | UNIQUE | 사번. 일부 JSON에서는 문자열이므로 문자형으로 저장. |
| name | VARCHAR(64) | NOT NULL | 사용자 이름. (`employee_name`). |
| department_hq | VARCHAR(64) |  | 본부. |
| department_dept | VARCHAR(64) |  | 부서. |
| department_team | VARCHAR(64) |  | 팀. |
| department_part | VARCHAR(64) |  | 파트/실. |
| contact_email | VARCHAR(128) |  | (확장) 이메일. |
| contact_phone | VARCHAR(32) |  | (확장) 전화번호. |
| created_at | TIMESTAMP | DEFAULT now() | 등록 일시. |
| updated_at | TIMESTAMP | DEFAULT now() | 갱신 일시. |

### assets
| 컬럼 | 타입 | 제약 | 설명 |
| --- | --- | --- | --- |
| uid | VARCHAR(64) | PK | 자산 관리 코드 (`asset_uid`). |
| legacy_id | BIGINT |  | 더미 데이터의 `id`.
| name | VARCHAR(128) |  | 자산 이름 또는 사용자명. |
| asset_type | VARCHAR(64) |  | 장비 분류. (`assets_types` 또는 `category`). |
| model_name | VARCHAR(128) |  | 모델명. |
| serial_number | VARCHAR(128) |  | 시리얼 넘버. |
| vendor | VARCHAR(128) |  | 제조사. |
| status | VARCHAR(32) | DEFAULT '사용' | 자산 상태 (`assets_status`). |
| location_text | VARCHAR(256) |  | 가공된 위치 문자열. |
| building | VARCHAR(64) |  | 건물명. |
| floor | VARCHAR(32) |  | 층 정보. |
| location_row | INTEGER |  | 평면도 행. |
| location_col | INTEGER |  | 평면도 열. |
| owner_user_id | BIGINT | FK → users.id | 현재 소유자. (없을 수 있음) |
| metadata | JSONB |  | 추가 필드 (os, network, memo 등). |
| created_at | TIMESTAMP | DEFAULT now() | 등록 일시. |
| updated_at | TIMESTAMP | DEFAULT now() | 갱신 일시. |

### asset_assignments (선택)
| 컬럼 | 타입 | 제약 | 설명 |
| --- | --- | --- | --- |
| id | BIGSERIAL | PK | |
| asset_uid | VARCHAR(64) | FK → assets.uid | 자산 식별자. |
| user_id | BIGINT | FK → users.id | 사용자. |
| assigned_at | TIMESTAMP |  | 배정 일시. |
| revoked_at | TIMESTAMP |  | 회수 일시. |
| memo | TEXT |  | 특이사항. |

### inspections
| 컬럼 | 타입 | 제약 | 설명 |
| --- | --- | --- | --- |
| id | VARCHAR(64) | PK | 실사 식별자. JSON에서 숫자이지만 문자열 ID로 통일. |
| asset_uid | VARCHAR(64) | FK → assets.uid | 실사 대상 자산. |
| status | VARCHAR(32) | NOT NULL | 실사 결과 상태. |
| memo | TEXT |  | 메모/특이사항. |
| scanned_at | TIMESTAMP | NOT NULL | 스캔 시각. |
| synced | BOOLEAN | DEFAULT false | 서버 반영 여부. |
| user_team | VARCHAR(128) |  | 실사자 소속. |
| user_id | BIGINT | FK → users.id | 실사자 ID. (없을 수 있음) |
| asset_type | VARCHAR(64) |  | 실사 시 확인된 장비 유형. |
| verified | BOOLEAN | DEFAULT false | 인증 여부 (`isVerified`). |
| barcode_photo_url | VARCHAR(256) |  | 바코드 사진 경로(번들 또는 업로드). |
| created_at | TIMESTAMP | DEFAULT now() | 기록 생성 시각. |
| updated_at | TIMESTAMP | DEFAULT now() | 최근 수정 시각. |

### signatures
| 컬럼 | 타입 | 제약 | 설명 |
| --- | --- | --- | --- |
| id | BIGSERIAL | PK | |
| asset_uid | VARCHAR(64) | FK → assets.uid | 서명 대상 자산. |
| user_id | BIGINT | FK → users.id | 서명자 ID. |
| user_name | VARCHAR(64) |  | 서명자 이름(보조). |
| storage_location | VARCHAR(256) | NOT NULL | 로컬 파일 경로 또는 `localStorage://` 키. |
| sha256 | CHAR(64) | UNIQUE | 이미지 무결성 체크용 해시. |
| captured_at | TIMESTAMP | DEFAULT now() | 서명 저장 시각. |
| migrated | BOOLEAN | DEFAULT false | 레거시 스토리지에서 마이그레이션 여부. |

## 인덱스 및 최적화
- `inspections(asset_uid, scanned_at DESC)` : 자산별 최신 실사를 빠르게 조회 (`latestByAssetUid`).
- `assets(status)` : 상태별 필터링.
- `assets USING gin(metadata jsonb_path_ops)` : 메타데이터 키/값 검색.
- `signatures(asset_uid, user_id)` : 인증 존재 여부 판단을 빠르게 처리.

## 시드 및 동기화 전략
1. **초기화**: 앱 시작 시 `assets/dummy/mock/*.json`을 읽어 `inspections`, `assets`, `users` 테이블을 채운다.
2. **오프라인 저장**: `signatures`는 로컬 파일/브라우저 저장소에 실제 바이너리를 두고, 테이블에는 메타 정보만 기록.
3. **동기화 파이프라인(향후)**
   - 새 실사/자산/서명 생성 시 `synced=false`로 표시.
   - 네트워크 가능 시 배치 업로드 API 호출 → 성공 시 `synced=true`, `storage_location`을 서버 URL로 교체.
   - 충돌 처리: `updated_at` 비교 후 최신 데이터 우선, 필요 시 사용자 확인.

## 데이터 검증 규칙
- 자산 UID, 사용자 ID는 대소문자/공백을 정규화하여 저장 (trim, lower-case).
- 서명 저장 시 PNG로 강제 변환하여 파일 크기와 호환성을 확보.
- 실사 메모는 줄바꿈 제거 후 2KB 이내로 제한.
- 메타데이터 JSON은 허용된 키 목록(예: `os`, `os_ver`, `network`, `memo`, `memo2`)을 기준으로 검증하되, 확장 키는 별도 테이블에 로깅.

## 마이그레이션 고려 사항
- 더미 JSON의 `inspection_count`, `maintenance_company_staff` 등 추가 필드는 별도 테이블 또는 메타데이터 컬럼으로 확장 가능.
- 브라우저 로컬스토리지에 저장된 구 버전 `.webp` 서명 파일은 첫 접근 시 PNG로 변환하여 signatures 레코드에 반영.
- 자산 위치 좌표(`location_row`, `location_col`)를 이용해 도면 매핑 기능이 도입되면 `asset_locations` 보조 테이블을 생성.
