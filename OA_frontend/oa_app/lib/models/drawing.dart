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
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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

  /// 격자 좌표 → 자리번호 변환 (예: row=2, col=3 → "C-4")
  static String getGridLabel(int row, int col) {
    final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + row);
    return '$rowLabel-${col + 1}';
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
