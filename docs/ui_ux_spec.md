# UI·UX 설계 문서

## 디자인 원칙
- **일관된 네비게이션**: AppScaffold가 화면 크기에 따라 NavigationRail/Drawer/BottomNavigationBar를 전환, 동일한 메뉴 구성을 유지한다.
- **오프라인 친화 UI**: 로딩 지표보다 상태 배지를 강조하여 데이터 최신 여부와 관계없이 작업 가능하도록 설계.
- **가독성 우선**: DataTable, Card, Chip 등을 활용해 표 형태 정보를 명확히 구분. 텍스트는 Material 3 기본 폰트 크기에서 -1~0 조정.
- **즉각 피드백**: SnackBar, Chip, IconButton 상태로 작업 성공/실패를 즉시 전달한다.
- **접근성 고려**: 모든 상호작용 요소에 Icon+Text 조합, 최소 44px 터치 영역을 확보.

## 레이아웃 가이드
| 구분 | 모바일(<450px) | 태블릿/데스크톱(≥450px) |
| --- | --- | --- |
| AppBar | 상단 고정, 햄버거 메뉴+설정 아이콘 | 동일 |
| 네비게이션 | BottomNavigationBar + Drawer | NavigationRail + Drawer |
| 컨텐츠 폭 | 기본 padding 16 | 카드/테이블은 1200px까지 확장 |
| 하단 CTA | ScannedFooter 버튼 고정 | NavigationRail 옆 본문 하단에 배치 |

## 공통 컴포넌트
- **AppScaffold**
  - Header: 제목, 설정 아이콘.
  - Navigation: 메뉴 4개(홈/자산리스트/자산인증/자산등록).
  - Footer: `ScannedFooter` (QR 버튼) → 모바일에서는 BottomNavigationBar 위, 데스크톱에서는 본문 하단.
- **카드(Card)**: 섹션 구분, 16px padding, 제목은 `titleMedium`, 내용은 `bodyMedium`.
- **데이터 테이블**
  - 헤더 높이 40px, 본문 40px.
  - 열 간격 최소화(0~8px)로 정보 밀도 증가.
  - 스크롤바 항상 표시하여 긴 목록 탐색 용이.

## 페이지별 UX
### 홈
- **히어로 섹션**: 2x2 카드 그리드. 아이콘+제목+설명.
- **최근 실사**: ListTile 카드. 상태/시간을 서브타이틀로, 모델명을 trailing 텍스트로 표시.
- **빈 상태**: "최근 실사 기록이 없습니다" 카드.

### QR 스캔
- **뷰파인더**: MobileScanner 전 화면. 토치/카메라 전환 FloatingActionButton 스타일 버튼 배치.
- **상태 표시**: 권한 거부 시 전체 화면 안내와 설정 이동 버튼.
- **최근 스캔 패널**: 하단 Sheet 스타일(최근 5건, 등록 여부 칩, 썸네일).
- **피드백**: 스캔 성공 시 진동+비프음, UI에 강조 색상.

### 자산 목록
- **필터 영역**: Card + Wrap. 검색 입력, 필드 드롭다운, 미동기화 스위치, 건수 배지, 초기화 버튼.
- **테이블 영역**: 가로 스크롤 지원, 컬럼 폭 지정(메모/위치는 200px).
- **페이징 컨트롤**: 중앙 정렬, Prev/Next 아이콘 버튼, 현재 페이지 Bold.
- **빈 상태**: "표시할 실사 내역이 없습니다" 텍스트.

### 자산 상세
- **검색 카드**: TextField + 검색 버튼. 결과 없을 때 빨간 안내 텍스트.
- **자산 정보 카드**: 기본 필드+메타데이터를 정보 행으로 배치. 편집 모드 시 TextFormField로 교체.
- **실사 메타 카드**: 상태/최근 실사 일시, 동기화 여부, 증빙 링크.
- **액션 영역**: 수정/취소/저장/삭제 버튼. 삭제는 TextButton+빨간색.

### 자산 등록
- **폼 레이아웃**: 두 열(Grid) 이상 화면에서는 좌측 폼, 우측 미리보기 카드. 모바일은 순차 배치.
- **메타데이터 입력**: 동적 필드 추가/삭제 버튼(OutlinedButton, IconButton).
- **검증 메시지**: 필수 입력 미기재 시 TextFormField 하단에 오류 텍스트.
- **저장 후 피드백**: SnackBar로 성공/실패 전달, 폼 초기화 옵션 안내.

### 자산 인증 목록
- **필터 패널**: 컬럼 선택 라디오 버튼, 검색창, 적용/초기화 버튼.
- **테이블**: 체크박스 열(선택), 팀/사용자/장비/위치/서명/바코드 컬럼. 서명/사진 여부는 Chip(초록=확인, 주황=미등록).
- **선택 요약**: 상단에 "선택 n건" 텍스트, 그룹 인증 버튼을 우측 배치.

### 자산 인증 상세
- **정보 테이블**: DataTable 한 행으로 세부 정보 표현. Chip으로 상태/사진 여부 강조.
- **서명/바코드 섹션**: Expansion 패널 스타일. 이미지 없을 때 안내 Chip.
- **작업 섹션**: VerificationActionSection → 서명 캡처, 파일 업로드, PDF, 공유, 초기화.
- **로딩 상태**: FutureBuilder 대기 중일 때 SelectableText("불러오는 중...").

### 선택 자산 인증
- **요약 카드**: 선택 자산 목록을 카드 그리드로 표시(최대 3열). 각 카드에 사용자/팀/사진/서명 상태.
- **경고 영역**: 누락 자산은 빨간 텍스트로 상단 표시.
- **하단 액션**: VerificationActionSection 확장/축소 토글, 공통 서명 진행.

## 색상 및 타이포그래피
- **Color Scheme**: Material3 `colorSchemeSeed=Colors.indigo`. 프라이머리 인디고, 보조 색상으로 토글.
- **상태 색상**
  - 정상/확인: `colorScheme.primary`
  - 경고/미완료: `Colors.orange`
  - 오류/삭제: `colorScheme.error`
- **폰트**: 기본 Roboto/Noto Sans. 본문 14~16pt, 테이블 13pt.

## 아이콘 가이드
- 홈 카드: `Icons.qr_code`, `Icons.history`, `Icons.cloud_upload_outlined`, `Icons.add_box_outlined`
- 스캔: `Icons.flash_on`, `Icons.cameraswitch`, `Icons.pause`, `Icons.play_arrow`
- 자산: `Icons.list_alt`, `Icons.inventory`, `Icons.search`, `Icons.filter_alt`
- 인증: `Icons.draw`, `Icons.verified`, `Icons.cloud_upload`, `Icons.group`

## 상호작용 패턴
- **SnackBar**: 3초 지속, 단일 액션 버튼은 사용하지 않음.
- **다이얼로그**: 삭제/덮어쓰기 등 파괴적 행동에 `AlertDialog` 사용.
- **Chip**: 상태 표시용. 배경색은 상태별 투명도 0.15 적용.
- **폼 제출**: 유효성 검증 실패 시 첫 오류 필드로 포커스 이동.

## 향후 개선 제안
- 다국어 지원(i18n) → `intl` 패키지 활용.
- 다크 모드 대비 색상 조정.
- 테이블 열 고정 및 CSV 내보내기.
- 스캔 화면에서 실시간 서버 조회(UID 존재 여부) 표시.
