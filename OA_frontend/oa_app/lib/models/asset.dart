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
  final String? ownerEmployeeId;
  final String? userName;
  final String? userDepartment;
  final String? userEmployeeId;
  final String? adminName;
  final String? adminDepartment;
  final String? adminEmployeeId;
  final int? locationDrawingId;
  final int? locationRow;
  final int? locationCol;
  final String? locationDrawingFile;
  final int? userId;
  final Map<String, dynamic> specifications;
  final DateTime? lastActiveAt;
  final DateTime? lastVerifiedAt;
  final String? verificationStatus;
  final int inspectionRoundNo; // 자산의 마지막 등록 실사 회차 (기본 0)
  final String? assignmentStatus;
  final DateTime? assignmentConfirmedAt;
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
    this.ownerEmployeeId,
    this.userName,
    this.userDepartment,
    this.userEmployeeId,
    this.adminName,
    this.adminDepartment,
    this.adminEmployeeId,
    this.locationDrawingId,
    this.locationRow,
    this.locationCol,
    this.locationDrawingFile,
    this.userId,
    this.specifications = const {},
    this.lastActiveAt,
    this.lastVerifiedAt,
    this.verificationStatus,
    this.inspectionRoundNo = 0,
    this.assignmentStatus,
    this.assignmentConfirmedAt,
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
          ? DateTime.parse(json['supply_end_date'] as String).toLocal()
          : null,
      category: json['category'] as String,
      serialNumber: json['serial_number'] as String?,
      modelName: json['model_name'] as String?,
      vendor: json['vendor'] as String?,
      network: json['network'] as String?,
      physicalCheckDate: json['physical_check_date'] != null
          ? DateTime.parse(json['physical_check_date'] as String).toLocal()
          : null,
      confirmationDate: json['confirmation_date'] != null
          ? DateTime.parse(json['confirmation_date'] as String).toLocal()
          : null,
      normalComment: json['normal_comment'] as String?,
      oaComment: json['oa_comment'] as String?,
      macAddress: json['mac_address'] as String?,
      building1: json['building1'] as String?,
      building: json['building'] as String?,
      floor: json['floor'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerDepartment: json['owner_department'] as String?,
      ownerEmployeeId: json['owner_employee_id'] as String?,
      userName: json['user_name'] as String?,
      userDepartment: json['user_department'] as String?,
      userEmployeeId: json['user_employee_id'] as String?,
      adminName: json['admin_name'] as String?,
      adminDepartment: json['admin_department'] as String?,
      adminEmployeeId: json['admin_employee_id'] as String?,
      locationDrawingId: json['location_drawing_id'] as int?,
      locationRow: json['location_row'] as int?,
      locationCol: json['location_col'] as int?,
      locationDrawingFile: json['location_drawing_file'] as String?,
      userId: json['user_id'] as int?,
      specifications:
          (json['specifications'] as Map<String, dynamic>?) ?? const {},
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.parse(json['last_active_at'] as String).toLocal()
          : null,
      lastVerifiedAt: json['last_verified_at'] != null
          ? DateTime.parse(json['last_verified_at'] as String).toLocal()
          : null,
      verificationStatus: json['verification_status'] as String?,
      inspectionRoundNo: (json['inspection_round_no'] as int?) ?? 0,
      assignmentStatus: json['assignment_status'] as String?,
      assignmentConfirmedAt: json['assignment_confirmed_at'] != null
          ? DateTime.parse(json['assignment_confirmed_at'] as String).toLocal()
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
      'owner_employee_id': ownerEmployeeId,
      'user_name': userName,
      'user_department': userDepartment,
      'user_employee_id': userEmployeeId,
      'admin_name': adminName,
      'admin_department': adminDepartment,
      'admin_employee_id': adminEmployeeId,
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
    String? ownerEmployeeId,
    String? userName,
    String? userDepartment,
    String? userEmployeeId,
    String? adminName,
    String? adminDepartment,
    String? adminEmployeeId,
    int? locationDrawingId,
    int? locationRow,
    int? locationCol,
    String? locationDrawingFile,
    int? userId,
    Map<String, dynamic>? specifications,
    DateTime? lastActiveAt,
    DateTime? lastVerifiedAt,
    String? verificationStatus,
    int? inspectionRoundNo,
    String? assignmentStatus,
    DateTime? assignmentConfirmedAt,
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
      ownerEmployeeId: ownerEmployeeId ?? this.ownerEmployeeId,
      userName: userName ?? this.userName,
      userDepartment: userDepartment ?? this.userDepartment,
      userEmployeeId: userEmployeeId ?? this.userEmployeeId,
      adminName: adminName ?? this.adminName,
      adminDepartment: adminDepartment ?? this.adminDepartment,
      adminEmployeeId: adminEmployeeId ?? this.adminEmployeeId,
      locationDrawingId: locationDrawingId ?? this.locationDrawingId,
      locationRow: locationRow ?? this.locationRow,
      locationCol: locationCol ?? this.locationCol,
      locationDrawingFile: locationDrawingFile ?? this.locationDrawingFile,
      userId: userId ?? this.userId,
      specifications: specifications ?? this.specifications,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      inspectionRoundNo: inspectionRoundNo ?? this.inspectionRoundNo,
      assignmentStatus: assignmentStatus ?? this.assignmentStatus,
      assignmentConfirmedAt: assignmentConfirmedAt ?? this.assignmentConfirmedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
