/// 전사 실사 라운드(차수) 모델
class InspectionRound {
  final int id;
  final int year;
  final int round;
  final String title;
  final String status; // draft, active, closed
  final int? startedBy;
  final DateTime? startedAt;
  final int? closedBy;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const InspectionRound({
    required this.id,
    required this.year,
    required this.round,
    required this.title,
    this.status = 'draft',
    this.startedBy,
    this.startedAt,
    this.closedBy,
    this.closedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isDraft => status == 'draft';
  bool get isActive => status == 'active';
  bool get isClosed => status == 'closed';

  factory InspectionRound.fromJson(Map<String, dynamic> json) {
    return InspectionRound(
      id: json['id'] as int,
      year: json['year'] as int,
      round: json['round'] as int,
      title: json['title'] as String,
      status: json['status'] as String? ?? 'draft',
      startedBy: json['started_by'] as int?,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String).toLocal()
          : null,
      closedBy: json['closed_by'] as int?,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String).toLocal()
          : null,
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
      'year': year,
      'round': round,
      'title': title,
      'status': status,
    };
  }
}
