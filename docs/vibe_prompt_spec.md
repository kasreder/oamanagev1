# VIBE AI 코딩 프롬프트 명세

본 문서는 OA Asset Manager 코드베이스를 수정할 때 AI Pair Programmer에게 전달할 기본 지침을 정의한다.

## 1. 컨텍스트 제공
1. **프로젝트 개요**
   - Flutter 기반 OA 자산 관리 앱.
   - Provider + GoRouter 구조, Material 3 디자인 시스템.
2. **핵심 폴더**
   - `lib/data`: 저장소/서명 스토리지.
   - `lib/providers`: 상태 관리(InspectionProvider).
   - `lib/view`: 페이지 및 공통 위젯.
   - `assets/dummy/mock`: 더미 데이터 소스.
3. **실행 방법**
   - `flutter pub get`
   - `flutter run -d chrome` 또는 `flutter run -d macos` 등 환경에 맞는 대상 지정.

## 2. 작업 정의 템플릿
AI에게 작업을 지시할 때 아래 템플릿을 사용한다.
```
목표: <사용자 스토리 또는 버그 설명>
범위: <수정/추가 대상 경로>
제약: <디자인, 성능, 접근성 요구사항>
테스트: <필수 실행 테스트/명령>
산출물: <코드/문서/이미지 등>
```

## 3. 구현 가이드라인
- **상태 관리**: `InspectionProvider`를 재사용하고 필요 시 메서드 추가. 다른 상태관리 패턴을 도입하지 않는다.
- **데이터 접근**: 더미 JSON → `InspectionRepository` 확장을 우선 고려. 로컬 상태 변경은 Provider API(`addOrUpdate`, `upsertAssetInfo`, `setOnlyUnsynced`) 사용.
- **실 DB 전환 지침**: 더미 데이터가 제거된 이후에는 `InspectionRepository`를 실제 API/DB 클라이언트 구현으로 교체하고, 네트워크 지연을 고려한 optimistic update 및 재시도 큐를 작성한다. 로컬 캐시는 `sqflite`/`drift` 등으로 구성하고, 테스트 시에는 스테이징 DB 또는 mock 서버를 사용한다.
- **UI 작성 규칙**
  - AppScaffold를 최상단에 배치.
  - Material 3 컴포넌트 사용(FilledButton, NavigationBar 등).
  - 반응형을 고려하여 `MediaQuery.sizeOf` 기반 조건 분기.
- **서명/파일 처리**: `SignatureStorage` 추상화를 통해 저장, 직접 `dart:io` 접근 금지.
- **국제화**: 현재 한글 UI 유지, 새 텍스트도 한글 기본. DateFormat은 `InspectionProvider.formatDateTime` 재사용.
- **코드 스타일**
  - `const` 생성자/위젯 적극 사용.
  - `final` 기본, 필요한 경우에만 `var`.
  - `dartfmt`(Flutter format)에 맞춘 trailing comma.
  - import 순서: Flutter → 패키지 → 프로젝트 상대 경로.
- **오류 처리**
  - 사용자 피드백은 SnackBar/AlertDialog 활용.
  - 비동기 함수는 `try/catch`로 사용자 메시지 제공.
  - 디버그 로그는 `if (kDebugMode)` 조건으로 감싼다.

## 4. 테스트 지침
- **필수**: `flutter analyze`, `flutter test`.
- **선택**: UI 변경 시 `golden test` 또는 스크린샷 첨부.
- **QR/카메라 기능**: 시뮬레이터에서 테스트 어려울 수 있으므로 논리 단위 테스트(파서, 중복 처리) 작성.

## 5. 코드 리뷰 체크리스트
- [ ] 상태 변경 후 `notifyListeners()` 호출 여부 확인.
- [ ] 라우터 경로/파라미터가 정의된 규칙과 일치하는가?
- [ ] SignatureStorage 호출 시 플랫폼별 경로/마이그레이션 고려했는가?
- [ ] UI 반응형 분기(≥450px)에서 레이아웃 깨짐이 없는가?
- [ ] 더미 데이터와 실제 백엔드 연동 간 확장 포인트가 손상되지 않았는가?

## 6. 커밋/PR 정책
- 커밋 메시지: `feat: ...`, `fix: ...`, `docs: ...` 등 Conventional Commits.
- PR 템플릿
```
## Summary
- 변경 요약 2~3줄

## Testing
- [ ] flutter analyze
- [ ] flutter test
- [ ] 기타(필요 시)
```
- 스크린샷/영상: UI 변경 시 첨부.

## 7. 금지 사항
- Provider 미사용 상태관리 도입(예: Bloc) 금지.
- Try/Catch로 import 감싸기 금지.
- 하드코딩된 절대 경로 사용 금지. 자산 경로는 `AssetManifest` 또는 `rootBundle` 활용.
- QR 스캔 로직에서 동기 I/O 사용 금지.

## 8. 예시 프롬프트
```
목표: 자산 인증 상세 화면에 서명 공유 버튼을 추가한다.
범위: lib/view/asset_verification/detail_page.dart, widgets/verification_action_section.dart
제약: Material 3 스타일, 모바일/데스크톱 반응형 유지
테스트: flutter analyze, flutter test
산출물: 코드 변경 및 스크린샷
```

위 템플릿을 기반으로 AI가 코드를 생성하면 검토자가 추가 지시를 내리기 쉽다.
