# OA Asset Manager 프로젝트 개요

## 비전과 목표
- **비전**: 현장 실사·인증 업무를 모바일/웹 어디에서든 일관되게 처리할 수 있는 하이브리드 OA 자산 관리 플랫폼을 제공한다.
- **핵심 목표**
  - 실사, 자산 관리, 인증 과정을 하나의 애플리케이션에 통합해 사용자의 작업 전환 비용을 줄인다.
  - 네트워크 연결이 불안정한 환경에서도 동작하도록 더미 데이터를 기반으로 오프라인 친화적인 구조를 갖춘다.
  - 서명, 바코드 사진 등 증빙 자료를 간편히 수집하고 차후 동기화를 대비한 로컬 저장 계층을 제공한다.

## 제품 요약
- **앱 이름**: OA Asset Manager
- **플랫폼**: Flutter 3.x (모바일, 데스크톱, 웹 동시 지원)
- **주요 사용자**: OA 자산 실사자, IT 자산 관리자, 인증 담당자
- **핵심 기능 영역**
  1. 자산 실사 현황 조회 및 편집
  2. 자산 스캔/등록 및 메타데이터 관리
  3. 인증(서명·바코드 사진) 수집 및 배치 검증
  4. 사용자/조직 참조 데이터 활용을 통한 검색 및 자동 입력

## 아키텍처 개요
| 계층 | 구성 요소 | 설명 |
| --- | --- | --- |
| 프레젠테이션 | `lib/view/**` | AppScaffold로 감싼 페이지들이 GoRouter 경로에 매핑되어 있으며, Consumer/Provider 패턴으로 상태를 구독한다. |
| 상태 관리 | `lib/providers/inspection_provider.dart` | InspectionProvider가 자산·사용자 레퍼런스, 실사 목록, 필터 상태를 보유하고 ChangeNotifier로 라우터 및 UI를 갱신한다. |
| 데이터 | `lib/data/**` | InspectionRepository가 JSON 더미 데이터를 파싱해 정렬된 실사 리스트를 구성하고, SignatureStorage가 플랫폼별(웹/모바일)로 서명 파일을 저장한다. |
| 모델 | `lib/models/inspection.dart` | Inspection 엔터티를 정의하고 JSON 변환, copyWith 로직을 제공한다. |
| 라우팅 | `lib/router/app_router.dart` | GoRouter 기반의 경로 정의 및 오류 처리, 라우터 refreshListenable로 상태 변화에 반응한다. |

## 실행 플로우
1. `main.dart`에서 `InspectionRepository`와 `InspectionProvider`를 생성하고 더미 데이터 및 참조 정보를 초기화한다.
2. 초기화가 완료되면 `AppRouter`를 통해 페이지 라우팅을 구성하고 Material 3 테마로 앱을 실행한다.
3. 각 페이지는 Provider를 통해 실사 목록, 자산 정보, 사용자 정보를 구독하며 사용자 상호작용(검색, 수정, 서명 저장 등)에 따라 상태를 갱신한다.
4. 서명 및 바코드 이미지는 `SignatureStorage`가 플랫폼별 API(FileSystemAccess API 또는 로컬 파일 시스템)를 통해 저장/조회하며, 오프라인 환경에서도 재활용된다.

## 기술 스택
- **프레임워크**: Flutter, Dart
- **라우팅/상태관리**: go_router, provider
- **하드웨어 연동**: mobile_scanner(카메라), permission_handler(권한)
- **미디어 처리**: image(바코드/서명 PNG 인코딩), audioplayers(피드백 사운드)
- **데이터 형식**: 로컬 JSON(`assets/dummy/mock/*.json`), 메모리 캐시, 로컬 파일/브라우저 스토리지

## 품질 및 확장 전략
- **테스트 대상**: 데이터 파서(InspectionRepository), 서명 저장 추상화(SignatureStorage), 검색/필터 로직(AssetsListPage, AssetVerificationListPage)
- **확장 포인트**
  - InspectionRepository를 REST/gRPC 백엔드 클라이언트로 교체하여 실데이터와 동기화.
  - SignatureStorage에 업로드 큐를 추가해 서버 동기화.
  - Provider를 Riverpod/BLoC 등으로 교체할 수 있도록 상태 의존성을 명확히 분리.
- **배포 고려 사항**: 자산/사용자 더미 데이터를 앱 번들에 포함하므로 빌드 전 최신화, 모바일에서는 카메라/파일 권한 선언 필요.

## 더미 데이터 → 실 DB 전환 시나리오
- **전환 배경**: 향후에는 번들된 JSON을 제거하고, 초기 실행 시점부터 실 DB와 동기화된 상태로 앱이 구동되어야 한다.
- **단계별 계획**
  1. 앱 초기화 루틴에서 더미 JSON 로딩 코드를 제거하고, `InspectionRepository`를 REST 클라이언트 또는 gRPC 클라이언트 구현으로 교체한다.
  2. 앱 기동 시 `/auth/token`으로 인증 후 `/assets`, `/inspections`, `/references/users` API를 호출해 초기 데이터를 가져오고, 로컬 캐시에 저장한다.
  3. 로컬 캐시는 `sqflite`/`floor` 등의 온디바이스 DB 혹은 Hive로 대체하고, `synced` 플래그를 이용해 오프라인 업데이트 내역을 서버에 재전송한다.
  4. 실 DB 스키마는 `docs/db_schema.md`의 정의대로 PostgreSQL(MySQL 등)에서 생성하고, 기존 더미 JSON은 데이터 마이그레이션 스크립트로 1회 이관한다.
- **운영 시 고려사항**
  - 실 DB에서 `assets`, `users` 테이블을 기준으로 권한/감사 로그를 관리하며, 앱은 읽기/쓰기 모두 API를 통해 수행한다.
  - 데이터 초기화나 테스트가 필요한 경우 별도의 스테이징 DB 인스턴스를 마련하고, 더미 JSON 대신 SQL seed 스크립트를 사용한다.
  - 레거시 더미 데이터 경로(`assets/dummy/mock`)는 제거하거나 테스트용으로만 유지하고, 프로덕션 빌드에서는 번들에 포함하지 않는다.

## 용어 정의
- **실사(Inspection)**: 자산 상태 점검 결과. 스캔 시각, 상태, 메모, 사용자 소속 등을 포함.
- **자산(AssetInfo)**: 자산 UID 기반 기본 정보와 자유 형식 메타데이터 맵을 가진 레퍼런스.
- **인증(Verification)**: 서명 수집 및 바코드 사진을 통해 자산 소유/상태를 검증하는 프로세스.
- **동기화(Sync)**: 서버 반영 여부를 나타내는 플래그. 현재는 더미 값으로 오프라인 우선 시나리오를 모사한다.
