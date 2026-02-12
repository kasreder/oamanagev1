class User {
  final int id;
  final String? authUid;
  final String employeeId;
  final String employeeName;
  final String employmentType;
  final String? organizationHq;
  final String? organizationDept;
  final String? organizationTeam;
  final String? organizationPart;
  final String? organizationEtc;
  final String? workBuilding;
  final String? workFloor;
  final String? authProvider;
  final String? snsId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const User({
    required this.id,
    this.authUid,
    required this.employeeId,
    required this.employeeName,
    this.employmentType = '정규직',
    this.organizationHq,
    this.organizationDept,
    this.organizationTeam,
    this.organizationPart,
    this.organizationEtc,
    this.workBuilding,
    this.workFloor,
    this.authProvider,
    this.snsId,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      authUid: json['auth_uid'] as String?,
      employeeId: json['employee_id'] as String,
      employeeName: json['employee_name'] as String,
      employmentType: json['employment_type'] as String? ?? '정규직',
      organizationHq: json['organization_hq'] as String?,
      organizationDept: json['organization_dept'] as String?,
      organizationTeam: json['organization_team'] as String?,
      organizationPart: json['organization_part'] as String?,
      organizationEtc: json['organization_etc'] as String?,
      workBuilding: json['work_building'] as String?,
      workFloor: json['work_floor'] as String?,
      authProvider: json['auth_provider'] as String?,
      snsId: json['sns_id'] as String?,
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
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employment_type': employmentType,
      'organization_hq': organizationHq,
      'organization_dept': organizationDept,
      'organization_team': organizationTeam,
      'organization_part': organizationPart,
      'organization_etc': organizationEtc,
      'work_building': workBuilding,
      'work_floor': workFloor,
      'auth_provider': authProvider,
      'sns_id': snsId,
    };
  }

  User copyWith({
    int? id,
    String? authUid,
    String? employeeId,
    String? employeeName,
    String? employmentType,
    String? organizationHq,
    String? organizationDept,
    String? organizationTeam,
    String? organizationPart,
    String? organizationEtc,
    String? workBuilding,
    String? workFloor,
    String? authProvider,
    String? snsId,
  }) {
    return User(
      id: id ?? this.id,
      authUid: authUid ?? this.authUid,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      employmentType: employmentType ?? this.employmentType,
      organizationHq: organizationHq ?? this.organizationHq,
      organizationDept: organizationDept ?? this.organizationDept,
      organizationTeam: organizationTeam ?? this.organizationTeam,
      organizationPart: organizationPart ?? this.organizationPart,
      organizationEtc: organizationEtc ?? this.organizationEtc,
      workBuilding: workBuilding ?? this.workBuilding,
      workFloor: workFloor ?? this.workFloor,
      authProvider: authProvider ?? this.authProvider,
      snsId: snsId ?? this.snsId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
