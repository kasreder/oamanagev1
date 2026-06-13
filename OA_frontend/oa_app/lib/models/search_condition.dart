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
  SearchableColumn('asset_uid',        '자산번호',     SearchOp.ilike),
  SearchableColumn('name',             '자산명',       SearchOp.ilike),
  SearchableColumn('serial_number',    '시리얼',       SearchOp.ilike),
  SearchableColumn('user_name',        '실사용자',     SearchOp.ilike),
  SearchableColumn('user_employee_id', '사용자사번',   SearchOp.ilike),
  SearchableColumn('user_department',  '실사용자부서', SearchOp.ilike),
  SearchableColumn('owner_name',       '소유자',       SearchOp.ilike),
  SearchableColumn('owner_department', '소유자부서',   SearchOp.ilike),
  SearchableColumn('admin_name',       '관리자',       SearchOp.ilike),
  SearchableColumn('admin_department', '관리자부서',   SearchOp.ilike),
  SearchableColumn('vendor',           '제조사',       SearchOp.ilike),
  SearchableColumn('model_name',       '모델명',       SearchOp.ilike),
  SearchableColumn('building',         '건물',         SearchOp.eq),
  SearchableColumn('floor',            '층',           SearchOp.eq),
  SearchableColumn('category',         '유형',         SearchOp.eq),
  SearchableColumn('assets_status',    '상태',         SearchOp.eq),
  SearchableColumn('supply_type',      '지급형태',     SearchOp.eq),
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
