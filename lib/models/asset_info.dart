class AssetInfo {
  AssetInfo({
    required this.uid,
    required this.name,
    required this.model,
    required this.serial,
    required this.vendor,
    required this.location,
    this.status = '',
    this.assetsTypes = '',
    this.organization = '',
    this.owner,
    this.barcodePhotoUrl,
    Map<String, String> metadata = const {},
  }) : metadata = Map.unmodifiable(metadata);

  factory AssetInfo.fromJson(Map<String, dynamic> json) {
    final metadata = <String, String>{};
    final rawMetadata = json['metadata'];
    if (rawMetadata is Map<String, dynamic>) {
      for (final entry in rawMetadata.entries) {
        metadata[entry.key] = entry.value?.toString() ?? '';
      }
    }
    final ownerJson = json['owner'];
    return AssetInfo(
      uid: json['uid'] as String,
      name: json['name'] as String? ?? '',
      model: json['modelName'] as String? ?? json['model'] as String? ?? '',
      serial: json['serialNumber'] as String? ?? json['serial'] as String? ?? '',
      vendor: json['vendor'] as String? ?? '',
      location: json['location'] as String? ?? '',
      status: json['status'] as String? ?? '',
      assetsTypes: json['assetType'] as String? ?? json['assets_types'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      owner: ownerJson is Map<String, dynamic> ? OwnerInfo.fromJson(ownerJson) : null,
      barcodePhotoUrl: json['barcodePhotoUrl'] as String?,
      metadata: metadata,
    );
  }

  final String uid;
  final String name;
  final String model;
  final String serial;
  final String vendor;
  final String location;
  final String status;
  final String assetsTypes;
  final String organization;
  final OwnerInfo? owner;
  final String? barcodePhotoUrl;
  final Map<String, String> metadata;

  String get assets_types => assetsTypes;

  Map<String, dynamic> toApiPayload() {
    return {
      'uid': uid,
      'name': name,
      'assetType': assetsTypes,
      'modelName': model,
      'serialNumber': serial,
      'vendor': vendor,
      'location': location,
      'status': status,
      'organization': organization,
      'metadata': metadata,
      if (owner?.id != null) 'ownerId': owner!.id,
      if (barcodePhotoUrl != null) 'barcodePhotoUrl': barcodePhotoUrl,
    };
  }

  AssetInfo copyWith({
    String? name,
    String? model,
    String? serial,
    String? vendor,
    String? location,
    String? status,
    String? assetsTypes,
    String? organization,
    OwnerInfo? owner,
    Map<String, String>? metadata,
    String? barcodePhotoUrl,
  }) {
    return AssetInfo(
      uid: uid,
      name: name ?? this.name,
      model: model ?? this.model,
      serial: serial ?? this.serial,
      vendor: vendor ?? this.vendor,
      location: location ?? this.location,
      status: status ?? this.status,
      assetsTypes: assetsTypes ?? this.assetsTypes,
      organization: organization ?? this.organization,
      owner: owner ?? this.owner,
      metadata: metadata ?? this.metadata,
      barcodePhotoUrl: barcodePhotoUrl ?? this.barcodePhotoUrl,
    );
  }
}

class OwnerInfo {
  const OwnerInfo({required this.id, required this.name, this.department});

  factory OwnerInfo.fromJson(Map<String, dynamic> json) {
    return OwnerInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String?,
    );
  }

  final String id;
  final String name;
  final String? department;
}
