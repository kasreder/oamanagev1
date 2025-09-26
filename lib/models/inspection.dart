import 'dart:convert';

/// 모델: 자산 실사 결과를 표현.
class Inspection {
  Inspection({
    required this.id,
    required this.assetUid,
    required this.status,
    this.memo,
    required this.scannedAt,
    required this.synced,
  });

  final String id;
  final String assetUid;
  String status;
  String? memo;
  DateTime scannedAt;
  bool synced;

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      assetUid: json['assetUid'] as String,
      status: json['status'] as String,
      memo: json['memo'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      synced: json['synced'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'assetUid': assetUid,
      'status': status,
      'memo': memo,
      'scannedAt': scannedAt.toUtc().toIso8601String(),
      'synced': synced,
    };
  }

  Inspection copyWith({
    String? status,
    String? memo,
    DateTime? scannedAt,
    bool? synced,
  }) {
    return Inspection(
      id: id,
      assetUid: assetUid,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      scannedAt: scannedAt ?? this.scannedAt,
      synced: synced ?? this.synced,
    );
  }

  static List<Inspection> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Inspection.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
