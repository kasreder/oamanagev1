/// 자산 카테고리 목록 (14종)
const List<String> assetCategories = [
  '데스크탑',
  '모니터',
  '노트북',
  'IP전화기',
  '스캐너',
  '프린터',
  '태블릿',
  '테스트폰',
  '네트워크장비',
  '서버',
  '웨어러블',
  '특수목적장비',
  '현장업무 태블릿',
  '법인폰',
];

/// 실사 상태 옵션 (2026-06-14)
const List<String> inspectionStatusOptions = [
  '이상없음',
  '반납요청(미사용)',
  '반납요청(사용자변경)',
  '재확인 필요',
];

/// 자산 지급형태 목록 (2026-06-14 확장: 이동/폐기/도급/개인 추가)
/// (assets_status는 2026-06-14 폐기됨 — UI/필터/색상 모두 supply_type 기준)
const List<String> supplyTypes = [
  '지급',
  '렌탈',
  '대여',
  '이동',
  '창고(대기)',
  '창고(점검)',
  '폐기',
  '도급',
  '개인',
];

/// 지급형태 중 만료일(supply_end_date) 입력이 필수인 옵션
const Set<String> supplyTypesRequireEndDate = {
  '렌탈',
  '대여',
  '도급',
  '개인',
};

/// 위치(건물 대분류) 옵션 — assets.building1 컬럼용
const List<String> building1Options = [
  '콘코디언',
  '부영',
  '태평로',
  '국제',
  '센터 및 지점',
];

/// 담당자 소속 옵션 — assets.admin_affiliation 컬럼용
const List<String> adminAffiliationOptions = [
  '롯데카드',
  '롯데카드 외',
];

/// 층 옵션 — assets.floor, drawings.floor 등 공통
const List<String> floorOptions = [
  'B2', 'B1',
  '1F', '2F', '3F', '4F', '5F', '6F',
  '옥상',
];

/// 사용망 목록 (네트워크 컬럼 — UI 드롭다운용. DB는 텍스트라 자유 입력도 허용)
const List<String> networkOptions = [
  '업무망',
  '개발망',
  '시스템망',
  '인터넷망',
  '셀룰러',
];

/// 고용형태 목록
const List<String> employmentTypes = [
  '정규직',
  '계약직',
  '도급직',
];

/// asset_uid 검증 정규식 (두 형식 병행 — DB CHECK/트리거와 동일)
/// - 현재기준: 영문 1~2자리 + 숫자 4~5자리 (D00001, TP0001, EH0001)
/// - 변경후: 등록경로 1 + 장비코드 2 + 숫자 5 (BDT00001, STP22222)
final RegExp assetUidRegex = RegExp(
  r'^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$',
);

/// 페이지네이션 기본 사이즈
const int defaultPageSize = 30;

/// QR 스캔 최대 연속 건수
const int maxScanCount = 5;

/// 서명 패드 크기
const double signaturePadSize = 400.0;

/// 도면 배율 설정
const double drawingMinScale = 0.5;
const double drawingMaxScale = 3.0;
const double drawingScaleStep = 0.5;

/// 비밀번호 정책 안내 문구 (설정/재설정/생성 공통)
const String passwordPolicyText = '8자 이상 · 대문자/소문자/숫자/특수문자 각 1자 이상';

/// 비밀번호 정책 검증 — 통과하면 null, 아니면 이유 반환.
/// 관리자 비밀번호 설정 / 아이디 생성 / 본인 재설정 모두 이 기준 하나를 쓴다.
String? validatePassword(String pw) {
  if (pw.length < 8) return '8자 이상이어야 합니다.';
  if (!RegExp(r'[A-Z]').hasMatch(pw)) return '대문자를 1자 이상 포함하세요.';
  if (!RegExp(r'[a-z]').hasMatch(pw)) return '소문자를 1자 이상 포함하세요.';
  if (!RegExp(r'[0-9]').hasMatch(pw)) return '숫자를 1자 이상 포함하세요.';
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(pw)) return '특수문자를 1자 이상 포함하세요.';
  return null;
}
