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
    this.userTeam,
  });

  final String id;
  final String assetUid;
  String status;
  String? memo;
  DateTime scannedAt;
  bool synced;
  String? userTeam;

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      assetUid: json['assetUid'] as String,
      status: json['status'] as String,
      memo: json['memo'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      synced: json['synced'] as bool? ?? false,
      userTeam: json['userTeam'] as String?,
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
      'userTeam': userTeam,
    };
  }

  Inspection copyWith({
    String? status,
    String? memo,
    DateTime? scannedAt,
    bool? synced,
    String? userTeam,
  }) {
    return Inspection(
      id: id,
      assetUid: assetUid,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      scannedAt: scannedAt ?? this.scannedAt,
      synced: synced ?? this.synced,
      userTeam: userTeam ?? this.userTeam,
    );
  }

  static List<Inspection> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Inspection.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
