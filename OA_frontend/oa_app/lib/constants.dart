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

/// 자산 상태 목록
const List<String> assetStatuses = [
  '사용',
  '가용',
  '이동',
  '점검필요',
  '고장',
];

/// 자산 지급형태 목록
const List<String> supplyTypes = [
  '지급',
  '렌탈',
  '대여',
  '창고(대기)',
  '창고(점검)',
];

/// 고용형태 목록
const List<String> employmentTypes = [
  '정규직',
  '계약직',
  '도급직',
];

/// asset_uid 검증 정규식 — 현재기준 (기본)
/// D00001, N00001, TP0001, EH0001, ET0001 등
final RegExp assetUidCurrentRegex = RegExp(
  r'^[A-Z]{1,2}[0-9]{4,5}$',
);

/// asset_uid 검증 정규식 — 변경후 기준
/// BDT00001, RNB12345, STP22222 등
final RegExp assetUidNewRegex = RegExp(
  r'^(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5}$',
);

/// asset_uid 검증 정규식 — 둘 다 허용 (조회/스캔용)
final RegExp assetUidRegex = RegExp(
  r'^([A-Z]{1,2}[0-9]{4,5}|(B|R|C|L|S)(DT|NB|MN|PR|TB|SC|IP|NW|SV|WR|SD|TP|ET|EH)[0-9]{5})$',
);

/// 등록경로 코드
const Map<String, String> supplyPathCodes = {
  'B': 'Buy',
  'R': 'Rental',
  'C': 'Contact',
  'L': 'Lease',
  'S': 'Spot',
};

/// 등록장비 코드 → 카테고리 매핑
const Map<String, String> equipmentCodeToCategory = {
  'DT': '데스크탑',
  'NB': '노트북',
  'MN': '모니터',
  'PR': '프린터',
  'TB': '태블릿',
  'SC': '스캐너',
  'IP': 'IP전화기',
  'NW': '네트워크장비',
  'SV': '서버',
  'WR': '웨어러블',
  'SD': '특수목적장비',
  'TP': '테스트폰',
  'ET': '현장업무 태블릿',
  'EH': '법인폰',
};

/// 카테고리 → 장비코드 역매핑
const Map<String, String> categoryToEquipmentCode = {
  '데스크탑': 'DT',
  '노트북': 'NB',
  '모니터': 'MN',
  '프린터': 'PR',
  '태블릿': 'TB',
  '스캐너': 'SC',
  'IP전화기': 'IP',
  '네트워크장비': 'NW',
  '서버': 'SV',
  '웨어러블': 'WR',
  '특수목적장비': 'SD',
  '테스트폰': 'TP',
  '현장업무 태블릿': 'ET',
  '법인폰': 'EH',
};

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
