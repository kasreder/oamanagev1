class AssetInspection {
  final int id;
  final int? assetId;
  final int? userId;
  final String? inspectorName;
  final String? userTeam;
  final String? assetCode;
  final String? assetType;
  final Map<String, dynamic> assetInfo;
  final int inspectionCount;
  final DateTime? inspectionDate;
  final String? maintenanceCompanyStaff;
  final String? departmentConfirm;
  final String? inspectionBuilding;
  final String? inspectionFloor;
  final String? inspectionPosition;
  final String? status;
  final String? memo;
  final String? inspectionPhoto;
  final String? signatureImage;
  final bool synced;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // 조인 필드 (실사 상세 조회 시)
  final String? assetUserName;
  final String? assetUserDepartment;

  const AssetInspection({
    required this.id,
    this.assetId,
    this.userId,
    this.inspectorName,
    this.userTeam,
    this.assetCode,
    this.assetType,
    this.assetInfo = const {},
    this.inspectionCount = 1,
    this.inspectionDate,
    this.maintenanceCompanyStaff,
    this.departmentConfirm,
    this.inspectionBuilding,
    this.inspectionFloor,
    this.inspectionPosition,
    this.status,
    this.memo,
    this.inspectionPhoto,
    this.signatureImage,
    this.synced = true,
    this.createdAt,
    this.updatedAt,
    this.assetUserName,
    this.assetUserDepartment,
  });

  /// 완료 판정: 5개 필드 모두 NOT NULL
  bool get completed =>
      inspectionBuilding != null &&
      inspectionFloor != null &&
      inspectionPosition != null &&
      inspectionPhoto != null &&
      signatureImage != null;

  factory AssetInspection.fromJson(Map<String, dynamic> json) {
    // 조인된 assets 정보 추출
    String? joinUserName;
    String? joinUserDept;
    if (json['assets'] is Map<String, dynamic>) {
      final assets = json['assets'] as Map<String, dynamic>;
      joinUserName = assets['user_name'] as String?;
      joinUserDept = assets['user_department'] as String?;
    }

    return AssetInspection(
      id: json['id'] as int,
      assetId: json['asset_id'] as int?,
      userId: json['user_id'] as int?,
      inspectorName: json['inspector_name'] as String?,
      userTeam: json['user_team'] as String?,
      assetCode: json['asset_code'] as String?,
      assetType: json['asset_type'] as String?,
      assetInfo:
          (json['asset_info'] as Map<String, dynamic>?) ?? const {},
      inspectionCount: json['inspection_count'] as int? ?? 1,
      inspectionDate: json['inspection_date'] != null
          ? DateTime.parse(json['inspection_date'] as String)
          : null,
      maintenanceCompanyStaff:
          json['maintenance_company_staff'] as String?,
      departmentConfirm: json['department_confirm'] as String?,
      inspectionBuilding: json['inspection_building'] as String?,
      inspectionFloor: json['inspection_floor'] as String?,
      inspectionPosition: json['inspection_position'] as String?,
      status: json['status'] as String?,
      memo: json['memo'] as String?,
      inspectionPhoto: json['inspection_photo'] as String?,
      signatureImage: json['signature_image'] as String?,
      synced: json['synced'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      assetUserName: joinUserName,
      assetUserDepartment: joinUserDept,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'asset_id': assetId,
      'user_id': userId,
      'inspector_name': inspectorName,
      'user_team': userTeam,
      'asset_code': assetCode,
      'asset_type': assetType,
      'asset_info': assetInfo,
      if (inspectionDate != null)
        'inspection_date': inspectionDate!.toIso8601String(),
      'maintenance_company_staff': maintenanceCompanyStaff,
      'department_confirm': departmentConfirm,
      'inspection_building': inspectionBuilding,
      'inspection_floor': inspectionFloor,
      'inspection_position': inspectionPosition,
      'status': status,
      'memo': memo,
      'inspection_photo': inspectionPhoto,
      'signature_image': signatureImage,
      'synced': synced,
    };
  }

  AssetInspection copyWith({
    int? id,
    int? assetId,
    int? userId,
    String? inspectorName,
    String? userTeam,
    String? assetCode,
    String? assetType,
    Map<String, dynamic>? assetInfo,
    int? inspectionCount,
    DateTime? inspectionDate,
    String? maintenanceCompanyStaff,
    String? departmentConfirm,
    String? inspectionBuilding,
    String? inspectionFloor,
    String? inspectionPosition,
    String? status,
    String? memo,
    String? inspectionPhoto,
    String? signatureImage,
    bool? synced,
  }) {
    return AssetInspection(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      userId: userId ?? this.userId,
      inspectorName: inspectorName ?? this.inspectorName,
      userTeam: userTeam ?? this.userTeam,
      assetCode: assetCode ?? this.assetCode,
      assetType: assetType ?? this.assetType,
      assetInfo: assetInfo ?? this.assetInfo,
      inspectionCount: inspectionCount ?? this.inspectionCount,
      inspectionDate: inspectionDate ?? this.inspectionDate,
      maintenanceCompanyStaff:
          maintenanceCompanyStaff ?? this.maintenanceCompanyStaff,
      departmentConfirm: departmentConfirm ?? this.departmentConfirm,
      inspectionBuilding: inspectionBuilding ?? this.inspectionBuilding,
      inspectionFloor: inspectionFloor ?? this.inspectionFloor,
      inspectionPosition: inspectionPosition ?? this.inspectionPosition,
      status: status ?? this.status,
      memo: memo ?? this.memo,
      inspectionPhoto: inspectionPhoto ?? this.inspectionPhoto,
      signatureImage: signatureImage ?? this.signatureImage,
      synced: synced ?? this.synced,
      createdAt: createdAt,
      updatedAt: updatedAt,
      assetUserName: assetUserName,
      assetUserDepartment: assetUserDepartment,
    );
  }
}
