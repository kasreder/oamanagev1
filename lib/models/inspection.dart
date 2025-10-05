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
    this.userId,
    this.assetType,
    bool? isVerified,
    this.barcodePhotoUrl,
  }) : isVerified = isVerified ?? synced;

  final String id;
  final String assetUid;
  String status;
  String? memo;
  DateTime scannedAt;
  bool synced;
  String? userTeam;
  final String? userId;
  final String? assetType;
  final bool isVerified;
  final String? barcodePhotoUrl;

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      assetUid: json['assetUid'] as String,
      status: json['status'] as String,
      memo: json['memo'] as String?,
      scannedAt: DateTime.parse(json['scannedAt'] as String),
      synced: json['synced'] as bool? ?? false,
      userTeam: json['userTeam'] as String?,
      userId: json['userId'] as String? ?? json['user_id'] as String?,
      assetType: json['assetType'] as String? ?? json['asset_type'] as String?,
      isVerified: json['isVerified'] as bool? ??
          json['is_verified'] as bool? ??
          (json['synced'] as bool? ?? false),
      barcodePhotoUrl: json['barcodePhotoUrl'] as String? ??
          json['barcode_photo_url'] as String? ??
          json['barcode_photo'] as String?,
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
      'userId': userId,
      'assetType': assetType,
      'isVerified': isVerified,
      'barcodePhotoUrl': barcodePhotoUrl,
    };
  }

  Inspection copyWith({
    String? status,
    String? memo,
    DateTime? scannedAt,
    bool? synced,
    String? userTeam,
    String? userId,
    String? assetType,
    bool? isVerified,
    String? barcodePhotoUrl,
  }) {
    return Inspection(
      id: id,
      assetUid: assetUid,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      scannedAt: scannedAt ?? this.scannedAt,
      synced: synced ?? this.synced,
      userTeam: userTeam ?? this.userTeam,
      userId: userId ?? this.userId,
      assetType: assetType ?? this.assetType,
      isVerified: isVerified ?? this.isVerified,
      barcodePhotoUrl: barcodePhotoUrl ?? this.barcodePhotoUrl,
    );
  }

  static List<Inspection> listFromJson(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Inspection.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
