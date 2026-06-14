// 자산 목록 고급 검색용 모델.
//
// PostgREST 매핑:
// - 모두 AND   → .eq() / .ilike() 체인
// - OR 섞임    → 단일 .or() 문자열 (평탄 OR — 1차 구현)

enum SearchOp { ilike, eq }
enum Joiner { and, or }

class SearchableColumn {
  final String key;        // DB 컬럼 (e.g. 'user_name')
  final String label;      // UI 라벨 ('실사용자')
  final SearchOp defaultOp;

  const SearchableColumn(this.key, this.label, this.defaultOp);
}

class SearchCondition {
  final SearchableColumn column;
  final SearchOp op;
  final String value;
  final Joiner joiner; // 이전 조건과의 결합. 첫 조건은 무시됨.

  const SearchCondition({
    required this.column,
    required this.op,
    required this.value,
    this.joiner = Joiner.and,
  });

  SearchCondition copyWith({
    SearchableColumn? column,
    SearchOp? op,
    String? value,
    Joiner? joiner,
  }) {
    return SearchCondition(
      column: column ?? this.column,
      op: op ?? this.op,
      value: value ?? this.value,
      joiner: joiner ?? this.joiner,
    );
  }

  /// 캐시키 직렬화용
  String get signature => '${joiner.name}|${column.key}|${op.name}|$value';
}

/// 검색 가능한 컬럼 목록.
/// ilike 대상은 텍스트 검색(자유 입력), eq 대상은 정확 일치(드롭다운 후보 권장).
const kSearchableColumns = <SearchableColumn>[
  // 기본 식별/이름
  SearchableColumn('asset_uid',           '자산번호',       SearchOp.ilike),
  SearchableColumn('name',                '자산명',         SearchOp.ilike),
  SearchableColumn('category',            '자산종류',       SearchOp.eq),
  SearchableColumn('supply_type',         '지급형태',       SearchOp.eq),
  SearchableColumn('serial_number',       '시리얼번호',     SearchOp.ilike),
  SearchableColumn('model_name',          '모델명',         SearchOp.ilike),
  SearchableColumn('vendor',              '제조사',         SearchOp.ilike),
  SearchableColumn('mac_address',         'MAC주소',        SearchOp.ilike),
  SearchableColumn('network',             '네트워크',       SearchOp.ilike),
  // 위치
  SearchableColumn('building1',           '건물(대)',       SearchOp.eq),
  SearchableColumn('building',            '건물',           SearchOp.eq),
  SearchableColumn('floor',               '층',             SearchOp.eq),
  // 사람
  SearchableColumn('user_name',           '실사용자',       SearchOp.ilike),
  SearchableColumn('user_employee_id',    '실사용자사번',   SearchOp.ilike),
  SearchableColumn('user_department',     '실사용자부서',   SearchOp.ilike),
  SearchableColumn('owner_name',          '소유자',         SearchOp.ilike),
  SearchableColumn('owner_employee_id',   '소유자사번',     SearchOp.ilike),
  SearchableColumn('owner_department',    '소유자부서',     SearchOp.ilike),
  SearchableColumn('admin_name',          '관리자',         SearchOp.ilike),
  SearchableColumn('admin_employee_id',   '관리자사번',     SearchOp.ilike),
  SearchableColumn('admin_department',    '관리자부서',     SearchOp.ilike),
  SearchableColumn('admin_affiliation',   '담당자 소속',    SearchOp.eq),
  // 비고
  SearchableColumn('normal_comment',      '일반비고',       SearchOp.ilike),
  SearchableColumn('oa_comment',          'OA비고',         SearchOp.ilike),
  // 일자
  SearchableColumn('physical_check_date', '실사일',         SearchOp.ilike),
  SearchableColumn('confirmation_date',   '확인일',         SearchOp.ilike),
  SearchableColumn('supply_end_date',     '지급만료일',     SearchOp.ilike),
  // 도면/위치
  SearchableColumn('location_drawing_id', '도면ID',         SearchOp.eq),
  SearchableColumn('location_row',        '위치(행)',       SearchOp.eq),
  SearchableColumn('location_col',        '위치(열)',       SearchOp.eq),
  SearchableColumn('location_drawing_file','도면파일',      SearchOp.ilike),
  // OS / 에이전트 (JSONB path)
  SearchableColumn('specifications->device_status->>os_version',
      'OS종류/버전', SearchOp.ilike),
  SearchableColumn('specifications->device_status->>os_detail_version',
      'OS상세', SearchOp.ilike),
  SearchableColumn('specifications->device_status->>os_security_patch',
      'OS보안패치', SearchOp.ilike),
];

/// PostgREST `or()` 문자열 빌더.
/// 평탄 OR 가정 (모든 조건을 OR로 묶음).
/// 예: `(name.ilike.*노트북*,user_name.ilike.*김대정*)`
String buildOrString(List<SearchCondition> conditions) {
  final parts = conditions.map((c) {
    final v = _escape(c.value);
    return c.op == SearchOp.eq
        ? '${c.column.key}.eq.$v'
        : '${c.column.key}.ilike.*$v*';
  });
  return parts.join(',');
}

/// PostgREST or() 필터 값 안에서 쉼표/괄호/별표 이스케이프.
String _escape(String v) {
  return v
      .replaceAll('\\', '\\\\')
      .replaceAll(',', '\\,')
      .replaceAll('(', '\\(')
      .replaceAll(')', '\\)')
      .replaceAll('*', '\\*');
}
