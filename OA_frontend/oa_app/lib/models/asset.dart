class Asset {
  final int id;
  final String assetUid;
  final String? name;
  final String assetsStatus;
  final String supplyType;
  final DateTime? supplyEndDate;
  final String category;
  final String? serialNumber;
  final String? modelName;
  final String? vendor;
  final String? network;
  final DateTime? physicalCheckDate;
  final DateTime? confirmationDate;
  final String? normalComment;
  final String? oaComment;
  final String? macAddress;
  final String? building1;
  final String? building;
  final String? floor;
  final String? ownerName;
  final String? ownerDepartment;
  final String? userName;
  final String? userDepartment;
  final String? adminName;
  final String? adminDepartment;
  final int? locationDrawingId;
  final int? locationRow;
  final int? locationCol;
  final String? locationDrawingFile;
  final int? userId;
  final Map<String, dynamic> specifications;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Asset({
    required this.id,
    required this.assetUid,
    this.name,
    this.assetsStatus = '가용',
    this.supplyType = '지급',
    this.supplyEndDate,
    required this.category,
    this.serialNumber,
    this.modelName,
    this.vendor,
    this.network,
    this.physicalCheckDate,
    this.confirmationDate,
    this.normalComment,
    this.oaComment,
    this.macAddress,
    this.building1,
    this.building,
    this.floor,
    this.ownerName,
    this.ownerDepartment,
    this.userName,
    this.userDepartment,
    this.adminName,
    this.adminDepartment,
    this.locationDrawingId,
    this.locationRow,
    this.locationCol,
    this.locationDrawingFile,
    this.userId,
    this.specifications = const {},
    this.createdAt,
    this.updatedAt,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as int,
      assetUid: json['asset_uid'] as String,
      name: json['name'] as String?,
      assetsStatus: json['assets_status'] as String? ?? '가용',
      supplyType: json['supply_type'] as String? ?? '지급',
      supplyEndDate: json['supply_end_date'] != null
          ? DateTime.parse(json['supply_end_date'] as String)
          : null,
      category: json['category'] as String,
      serialNumber: json['serial_number'] as String?,
      modelName: json['model_name'] as String?,
      vendor: json['vendor'] as String?,
      network: json['network'] as String?,
      physicalCheckDate: json['physical_check_date'] != null
          ? DateTime.parse(json['physical_check_date'] as String)
          : null,
      confirmationDate: json['confirmation_date'] != null
          ? DateTime.parse(json['confirmation_date'] as String)
          : null,
      normalComment: json['normal_comment'] as String?,
      oaComment: json['oa_comment'] as String?,
      macAddress: json['mac_address'] as String?,
      building1: json['building1'] as String?,
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerDepartment: json['owner_department'] as String?,
      userName: json['user_name'] as String?,
      userDepartment: json['user_department'] as String?,
      adminName: json['admin_name'] as String?,
      adminDepartment: json['admin_department'] as String?,
      locationDrawingId: json['location_drawing_id'] as int?,
      locationRow: json['location_row'] as int?,
      locationCol: json['location_col'] as int?,
      locationDrawingFile: json['location_drawing_file'] as String?,
      userId: json['user_id'] as int?,
      specifications:
          (json['specifications'] as Map<String, dynamic>?) ?? const {},
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
      'asset_uid': assetUid,
      'name': name,
      'assets_status': assetsStatus,
      'supply_type': supplyType,
      if (supplyEndDate != null)
        'supply_end_date': supplyEndDate!.toIso8601String(),
      'category': category,
      'serial_number': serialNumber,
      'model_name': modelName,
      'vendor': vendor,
      'network': network,
      if (physicalCheckDate != null)
        'physical_check_date': physicalCheckDate!.toIso8601String(),
      if (confirmationDate != null)
        'confirmation_date': confirmationDate!.toIso8601String(),
      'normal_comment': normalComment,
      'oa_comment': oaComment,
      'mac_address': macAddress,
      'building1': building1,
      'building': building,
      'floor': floor,
      'owner_name': ownerName,
      'owner_department': ownerDepartment,
      'user_name': userName,
      'user_department': userDepartment,
      'admin_name': adminName,
      'admin_department': adminDepartment,
      'location_drawing_id': locationDrawingId,
      'location_row': locationRow,
      'location_col': locationCol,
      'location_drawing_file': locationDrawingFile,
      'user_id': userId,
      'specifications': specifications,
    };
  }

  Asset copyWith({
    int? id,
    String? assetUid,
    String? name,
    String? assetsStatus,
    String? supplyType,
    DateTime? supplyEndDate,
    String? category,
    String? serialNumber,
    String? modelName,
    String? vendor,
    String? network,
    DateTime? physicalCheckDate,
    DateTime? confirmationDate,
    String? normalComment,
    String? oaComment,
    String? macAddress,
    String? building1,
    String? building,
    String? floor,
    String? ownerName,
    String? ownerDepartment,
    String? userName,
    String? userDepartment,
    String? adminName,
    String? adminDepartment,
    int? locationDrawingId,
    int? locationRow,
    int? locationCol,
    String? locationDrawingFile,
    int? userId,
    Map<String, dynamic>? specifications,
  }) {
    return Asset(
      id: id ?? this.id,
      assetUid: assetUid ?? this.assetUid,
      name: name ?? this.name,
      assetsStatus: assetsStatus ?? this.assetsStatus,
      supplyType: supplyType ?? this.supplyType,
      supplyEndDate: supplyEndDate ?? this.supplyEndDate,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      modelName: modelName ?? this.modelName,
      vendor: vendor ?? this.vendor,
      network: network ?? this.network,
      physicalCheckDate: physicalCheckDate ?? this.physicalCheckDate,
      confirmationDate: confirmationDate ?? this.confirmationDate,
      normalComment: normalComment ?? this.normalComment,
      oaComment: oaComment ?? this.oaComment,
      macAddress: macAddress ?? this.macAddress,
      building1: building1 ?? this.building1,
      building: building ?? this.building,
      floor: floor ?? this.floor,
      ownerName: ownerName ?? this.ownerName,
      ownerDepartment: ownerDepartment ?? this.ownerDepartment,
      userName: userName ?? this.userName,
      userDepartment: userDepartment ?? this.userDepartment,
      adminName: adminName ?? this.adminName,
      adminDepartment: adminDepartment ?? this.adminDepartment,
      locationDrawingId: locationDrawingId ?? this.locationDrawingId,
      locationRow: locationRow ?? this.locationRow,
      locationCol: locationCol ?? this.locationCol,
      locationDrawingFile: locationDrawingFile ?? this.locationDrawingFile,
      userId: userId ?? this.userId,
      specifications: specifications ?? this.specifications,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
