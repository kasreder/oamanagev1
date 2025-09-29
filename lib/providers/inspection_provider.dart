// lib/providers/inspection_provider.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/inspection_repository.dart';
import '../models/inspection.dart';

/// 주요 기능:
/// - 실사 데이터 상태를 관리하고 필터링합니다.
/// - 더미 JSON 자산/사용자 참조 데이터를 로드합니다.
/// - 실사 내역의 추가, 수정, 삭제 이벤트를 전파합니다.
class InspectionProvider extends ChangeNotifier {
  InspectionProvider(this._repository);

  final InspectionRepository _repository;
  final Map<String, AssetInfo> _assetMap = {};
  final Map<String, UserInfo> _userMap = {};

  List<Inspection> _items = [];
  bool _onlyUnsynced = false;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  bool get onlyUnsynced => _onlyUnsynced;

  List<Inspection> get items {
    if (_onlyUnsynced) {
      return _items.where((item) => !item.synced).toList(growable: false);
    }
    return List.unmodifiable(_items);
  }

  int get unsyncedCount => _items.where((item) => !item.synced).length;

  List<Inspection> get unsyncedItems =>
      _items.where((item) => !item.synced).toList(growable: false);

  int get totalCount => _items.length;

  /// 최근 실사 정보를 최대 [limit]개 반환한다.
  List<Inspection> recent({int limit = 5}) {
    return _items.take(limit).toList(growable: false);
  }

  /// 날짜 포맷 헬퍼.
  String formatDateTime(DateTime time) {
    return DateFormat('yyyy-MM-dd HH:mm').format(time.toLocal());
  }

  AssetInfo? assetOf(String uid) => _assetMap[uid];

  UserInfo? userOf(String id) => _userMap[id];

  Future<void> initialize() async {
    await Future.wait([
      _loadReferenceData(),
      _repository.loadFromAssets(),
    ]);
    _items = _repository.getAll();
    _initialized = true;
    notifyListeners();
  }

  Inspection? findById(String id) {
    return _repository.findById(id);
  }

  Inspection? latestByAssetUid(String assetUid) {
    for (final item in _items) {
      if (item.assetUid == assetUid) {
        return item;
      }
    }
    return null;
  }

  void addOrUpdate(Inspection inspection) {
    _repository.upsert(inspection);
    _items = _repository.getAll();
    notifyListeners();
  }

  void remove(String id) {
    _repository.delete(id);
    _items = _repository.getAll();
    notifyListeners();
  }

  void setOnlyUnsynced(bool value) {
    if (_onlyUnsynced == value) return;
    _onlyUnsynced = value;
    notifyListeners();
  }

  Future<void> _loadReferenceData() async {
    await Future.wait([
      _loadAssets(),
      _loadUsers(),
    ]);
  }

  Future<void> _loadAssets() async {
    try {
      final raw = await _loadJsonWithFallback(
        'assets/dummy/mock/assets.json',
        'assets/mock/assets.json',
      );
      final decoded =
          (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      final entries = <MapEntry<String, AssetInfo>>[];
      for (final item in decoded) {
        final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
        if (uid == null) {
          continue;
        }
        entries.add(
          MapEntry(
            uid,
            AssetInfo(
              uid: uid,
              name: _stringOrNull(item['name']) ?? '',
              model: _stringOrNull(item['model_name']) ??
                  _stringOrNull(item['model']) ??
                  '',
              serial: _stringOrNull(item['serial_number']) ??
                  _stringOrNull(item['serial']) ??
                  '',
              vendor: _stringOrNull(item['vendor']) ?? '',
              location: _resolveLocation(item),
              status: _stringOrNull(item['assets_status']) ??
                  _stringOrNull(item['status']) ??
                  '',
              assets_types: _stringOrNull(item['assets_types']) ?? '',
              organization: _stringOrNull(item['organization']) ?? '',
            ),
          ),
        );
      }
      _assetMap
        ..clear()
        ..addEntries(entries);
    } on FlutterError {
      _assetMap.clear();
    } on FormatException {
      _assetMap.clear();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final raw = await _loadJsonWithFallback(
        'assets/dummy/mock/users.json',
        'assets/mock/users.json',
      );
      final decoded =
          (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
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
          _stringOrNull(item['organization_part']),
        ].whereType<String>().toList();
        final department = departmentParts.isEmpty
            ? (_stringOrNull(item['department']) ?? '')
            : departmentParts.join(' > ');
        entries.add(
          MapEntry(
            id,
            UserInfo(
              id: id,
              name: _stringOrNull(item['employee_name']) ??
                  _stringOrNull(item['name']) ??
                  '',
              department: department,
            ),
          ),
        );
      }
      _userMap
        ..clear()
        ..addEntries(entries);
    } on FlutterError {
      _userMap.clear();
    } on FormatException {
      _userMap.clear();
    }
  }

  Future<String> _loadJsonWithFallback(String primary, String fallback) async {
    try {
      return await rootBundle.loadString(primary);
    } on FlutterError {
      return rootBundle.loadString(fallback);
    }
  }

  String _resolveLocation(Map<String, dynamic> item) {
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
    return locationParts.isEmpty
        ? (_stringOrNull(item['location']) ??
            _stringOrNull(item['member_name']) ??
            '')
        : locationParts.join(' ');
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}

/// 자산 기본 정보를 표현하는 단순 DTO.
class AssetInfo {
  const AssetInfo({
    required this.uid,
    required this.name,
    required this.model,
    required this.serial,
    required this.vendor,
    required this.location,
    this.status = '',
    this.assets_types = '',
    this.organization = '',
  });

  final String uid;
  final String name;
  final String model;
  final String serial;
  final String vendor;
  final String location;
  final String status;
  final String assets_types;
  final String organization;
}

/// 사용자 참조 정보를 보관하는 DTO.
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
