class Drawing {
  final int id;
  final String building;
  final String floor;
  final String? drawingFile;
  final int gridRows;
  final int gridCols;
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Drawing({
    required this.id,
    required this.building,
    required this.floor,
    this.drawingFile,
    this.gridRows = 10,
    this.gridCols = 8,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  factory Drawing.fromJson(Map<String, dynamic> json) {
    return Drawing(
      id: json['id'] as int,
      building: json['building'] as String,
      floor: json['floor'] as String,
      drawingFile: json['drawing_file'] as String?,
      gridRows: json['grid_rows'] as int? ?? 10,
      gridCols: json['grid_cols'] as int? ?? 8,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'building': building,
      'floor': floor,
      'drawing_file': drawingFile,
      'grid_rows': gridRows,
      'grid_cols': gridCols,
      'description': description,
    };
  }

  /// 격자 좌표 → 자리번호 변환
  /// 예: row=0,col=0 → "A-1" / row=2,col=3 → "C-4" / row=26,col=0 → "AA-1"
  /// 행은 엑셀 컬럼 스타일(A..Z, AA..AZ, BA..)로 26개 초과도 지원.
  static String getGridLabel(int row, int col) {
    return '${_excelLabel(row)}-${col + 1}';
  }

  static String _excelLabel(int n) {
    var s = '';
    var v = n + 1;
    while (v > 0) {
      v--;
      s = String.fromCharCode(65 + v % 26) + s;
      v ~/= 26;
    }
    return s;
  }

  Drawing copyWith({
    int? id,
    String? building,
    String? floor,
    String? drawingFile,
    int? gridRows,
    int? gridCols,
    String? description,
  }) {
    return Drawing(
      id: id ?? this.id,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      drawingFile: drawingFile ?? this.drawingFile,
      gridRows: gridRows ?? this.gridRows,
      gridCols: gridCols ?? this.gridCols,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
