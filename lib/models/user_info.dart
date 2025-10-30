class UserInfo {
  const UserInfo({
    required this.id,
    required this.name,
    required this.department,
    this.employeeId,
    this.numericId,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      employeeId: json['employeeId']?.toString(),
      numericId: json['numericId']?.toString(),
    );
  }

  final String id;
  final String name;
  final String department;
  final String? employeeId;
  final String? numericId;
}
