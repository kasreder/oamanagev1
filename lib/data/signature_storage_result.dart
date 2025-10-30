class StoredSignature {
  const StoredSignature({
    required this.signatureId,
    required this.location,
    this.assetUid,
    this.userId,
    this.userName,
    this.capturedAt,
  });

  final String signatureId;
  final String location;
  final String? assetUid;
  final String? userId;
  final String? userName;
  final DateTime? capturedAt;

  StoredSignature copyWith({
    String? signatureId,
    String? location,
    String? assetUid,
    String? userId,
    String? userName,
    DateTime? capturedAt,
  }) {
    return StoredSignature(
      signatureId: signatureId ?? this.signatureId,
      location: location ?? this.location,
      assetUid: assetUid ?? this.assetUid,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      capturedAt: capturedAt ?? this.capturedAt,
    );
  }

  static StoredSignature fromJson(Map<String, dynamic> json) {
    final signatureId = json['signatureId'] ?? json['id'];
    final location = json['storageLocation'] ?? json['fileName'] ?? '';
    final assetUid = json['assetUid'];
    final userId = json['userId'];
    final userName = json['userName'];
    final capturedAtRaw = json['capturedAt'];
    return StoredSignature(
      signatureId: signatureId?.toString() ?? '',
      location: location?.toString() ?? '',
      assetUid: assetUid?.toString(),
      userId: userId?.toString(),
      userName: userName?.toString(),
      capturedAt: capturedAtRaw is String ? DateTime.tryParse(capturedAtRaw) : null,
    );
  }
}
