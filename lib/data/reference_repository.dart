import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 단순 자산/사용자 참조 데이터.
class ReferenceDataRepository {
  final Map<String, AssetInfo> _assets = {};
  final Map<String, UserInfo> _users = {};

  Future<void> loadFromAssets() async {
    await Future.wait<void>([
      _loadAssets(),
      _loadUsers(),
    ]);
  }

  AssetInfo? findAsset(String uid) => _assets[uid];

  UserInfo? findUser(String id) => _users[id];

  Future<void> _loadAssets() async {
    try {
      final raw = await rootBundle.loadString('assets/dummy/mock/assets.json');
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      final entries = <MapEntry<String, AssetInfo>>[];
      for (final item in decoded) {
        final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
        if (uid == null) {
          continue;
        }
        final locationParts = <String>[];
        final building1 = _stringOrNull(item['building1']);
        final building = _stringOrNull(item['building']);
        final floor = _stringOrNull(item['floor']);
        final locationRow = item['location_row'];
        final locationCol = item['location_col'];
        if (building1 != null) locationParts.add(building1);
        if (building != null) locationParts.add(building);
        if (floor != null) locationParts.add(floor);
        if (locationRow != null) {
          locationParts.add('R${locationRow.toString()}');
        }
        if (locationCol != null) {
          locationParts.add('C${locationCol.toString()}');
        }
        final location = locationParts.isEmpty
            ? (_stringOrNull(item['location']) ?? _stringOrNull(item['member_name']) ?? '')
            : locationParts.join(' ');
        entries.add(
          MapEntry(
            uid,
            AssetInfo(
              uid: uid,
              name: _stringOrNull(item['name']) ?? '',
              model: _stringOrNull(item['model_name']) ?? _stringOrNull(item['model']) ?? '',
              serial: _stringOrNull(item['serial_number']) ?? _stringOrNull(item['serial']) ?? '',
              vendor: _stringOrNull(item['vendor']) ?? '',
              location: location,
              status: _stringOrNull(item['assets_status']) ?? '',
            ),
          ),
        );
      }
      _assets
        ..clear()
        ..addEntries(entries);
    } on FlutterError {
      _assets.clear();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final raw = await rootBundle.loadString('assets/dummy/mock/users.json');
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      final entries = <MapEntry<String, UserInfo>>[];
      for (final item in decoded) {
        final id = _stringOrNull(item['employee_id']) ?? _stringOrNull(item['id']);
        if (id == null) {
          continue;
        }
        final departmentParts = [
          _stringOrNull(item['organization_hq']),
          _stringOrNull(item['organization_dept']),
          _stringOrNull(item['organization_team']),
        ].whereType<String>().toList();
        final department = departmentParts.isEmpty
            ? (_stringOrNull(item['department']) ?? '')
            : departmentParts.join(' > ');
        entries.add(
          MapEntry(
            id,
            UserInfo(
              id: id,
              name: _stringOrNull(item['employee_name']) ?? _stringOrNull(item['name']) ?? '',
              department: department,
            ),
          ),
        );
      }
      _users
        ..clear()
        ..addEntries(entries);
    } on FlutterError {
      _users.clear();
    }
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}

class AssetInfo {
  const AssetInfo({
    required this.uid,
    required this.name,
    required this.model,
    required this.serial,
    required this.vendor,
    required this.location,
    this.status = '',
  });

  final String uid;
  final String name;
  final String model;
  final String serial;
  final String vendor;
  final String location;
  final String status;
}

class UserInfo {
  const UserInfo({
    required this.id,
    required this.name,
    required this.department,
  });

  final String id;
  final String name;
  final String department;
}
