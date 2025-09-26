<!-- assets/dummy/mock/SCHEMA.md -->
# 더미 데이터 스키마 정리

이 문서는 `assets/dummy/mock` 경로에 포함된 JSON 더미 데이터의 필드 스키마를 정리한 것입니다. 모든 날짜는 ISO-8601 형식의 문자열이며, 명시되지 않은 필드는 `null`이 될 수 있습니다.

## assets.json
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | number | 자산 고유 식별자. |
| `asset_uid` | string | 자산의 관리용 코드. |
| `name` | string | 자산 명칭 또는 사용자 이름. |
| `assets_status` | string | 자산 상태(예: `사용`, `가용(창고)` 등). |
| `category` | string | 자산 분류 카테고리. |
| `serial_number` | string \| null | 시리얼 넘버. |
| `model_name` | string \| null | 자산 모델명. |
| `vendor` | string \| null | 제조사 또는 공급사. |
| `network` | string \| null | 네트워크 구분. |
| `physical_check_date` | string \| null | 최근 물리 점검 일시. |
| `confirmation_date` | string \| null | 확인 완료 일시. |
| `normal_comment` | string \| null | 일반 메모. |
| `oa_comment` | string \| null | OA 관련 메모. |
| `mac_address` | string \| null | MAC 주소. |
| `building1` | string \| null | 건물군(내부/외부 직원 등). |
| `building` | string \| null | 건물명. |
| `floor` | string \| null | 층 정보. |
| `member_name` | string \| null | 사용자 이름(자산이 개인에게 할당된 경우). |
| `location_drawing_id` | number \| null | 평면도 ID. |
| `location_row` | number \| null | 평면도 상 행 위치. |
| `location_col` | number \| null | 평면도 상 열 위치. |
| `location_drawing_file` | string \| null | 평면도 파일명. |
| `created_at` | string | 자산 생성 일시. |
| `updated_at` | string | 최근 갱신 일시. |
| `user_id` | number \| null | 자산 사용자 ID(`users.json`의 `id`). |

## users.json
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | number | 사용자 고유 식별자. |
| `employee_id` | string | 사번. |
| `employee_name` | string | 사용자 이름. |
| `organization_hq` | string \| null | 본부. |
| `organization_dept` | string \| null | 부서. |
| `organization_team` | string \| null | 팀. |
| `organization_part` | string \| null | 파트 정보. |
| `organization_etc` | string \| null | 기타 직책/설명. |
| `work_building` | string \| null | 근무 건물. |
| `work_floor` | string \| null | 근무 층. |

## asset_inspections.json
| 필드 | 타입 | 설명 |
| --- | --- | --- |
| `id` | number | 실사 고유 식별자. |
| `asset_id` | number | 실사 대상 자산 ID(`assets.json`의 `id`). |
| `user_id` | number \| null | 실사 담당 사용자 ID(`users.json`의 `id`). |
| `inspector_name` | string \| null | 실사자 이름. |
| `user_team` | string \| null | 실사자 소속 팀. |
| `asset_code` | string | 실사된 자산 코드(`asset_uid`). |
| `asset_type` | string \| null | 자산 유형. |
| `asset_info` | object \| null | 자산 상세 정보 객체. |
| `asset_info.model_name` | string \| null | 실사 시 확인한 모델명. |
| `asset_info.usage` | string \| null | 사용 용도. |
| `asset_info.serial_number` | string \| null | 실사 시 확인한 시리얼. |
| `inspection_count` | number | 누적 실사 횟수. |
| `inspection_date` | string | 실사 수행 일시. |
| `maintenance_company_staff` | string \| null | 유지보수 담당자. |
| `department_confirm` | string \| null | 확인 부서. |

## 관계 요약
- `asset_inspections.json`의 `asset_code`는 `assets.json`의 `asset_uid`와 매칭됩니다.
- `asset_inspections.json`과 `assets.json`의 `user_id`는 `users.json`의 `id`와 연결됩니다.
