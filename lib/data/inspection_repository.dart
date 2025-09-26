import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:collection/collection.dart';

import '../models/inspection.dart';

/// 메모리 기반 실사 저장소.
class InspectionRepository {
  final List<Inspection> _items = [];
  // TODO: Hive/Sqflite 등 영속 저장소 교체 포인트 고려

  /// 에셋 JSON으로부터 초기 데이터를 로드한다.
  Future<void> loadFromAssets() async {
    try {
      final raw = await _loadInspectionRaw();
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      final statusMap = await _loadAssetStatuses();
      final items = <Inspection>[];
      for (final item in decoded) {
        final assetUid =
            _stringOrNull(item['asset_code']) ?? _stringOrNull(item['assetUid']);
        if (assetUid == null) {
          continue;
        }
        final rawId = item['id'];
        final id = rawId == null
            ? 'ins_$assetUid'
            : rawId is String
                ? rawId
                : 'ins_${rawId.toString()}';
        final parsedDate = DateTime.tryParse(
              _stringOrNull(item['inspection_date']) ??
                  _stringOrNull(item['scannedAt']) ??
                  '',
            ) ??
            DateTime.now();
        final memo = _buildMemo(item) ?? _stringOrNull(item['memo']);
        items.add(
          Inspection(
            id: id,
            assetUid: assetUid,
            status: statusMap[assetUid] ?? _stringOrNull(item['status']) ?? '사용',
            memo: memo,
            scannedAt: parsedDate,
            synced: item['synced'] as bool? ?? ((item['inspection_count'] as int? ?? 0) % 2 == 0),
          ),
        );
      }
      _items
        ..clear()
        ..addAll(items);
      _sortItems();
    } on FlutterError {
      _items.clear();
    }
  }

  /// 현재 보유 중인 실사 리스트를 반환한다.
  List<Inspection> getAll() => List.unmodifiable(_items);

  /// 실사 내역을 추가하거나 갱신한다.
  void upsert(Inspection inspection) {
    final index = _items.indexWhere((item) => item.id == inspection.id);
    if (index >= 0) {
      _items[index] = inspection;
    } else {
      _items.add(inspection);
    }
    _sortItems();
  }

  /// 식별자로 실사를 삭제한다.
  void delete(String id) {
    _items.removeWhere((item) => item.id == id);
  }

  Inspection? findById(String id) {
    return _items.firstWhereOrNull((item) => item.id == id);
  }

  void _sortItems() {
    _items.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }

  Future<String> _loadInspectionRaw() async {
    try {
      return await rootBundle.loadString('assets/dummy/mock/asset_inspections.json');
    } on FlutterError {
      return rootBundle.loadString('assets/mock/asset_inspections.json');
    }
  }

  Future<Map<String, String>> _loadAssetStatuses() async {
    Future<String> load(String path) => rootBundle.loadString(path);
    try {
      final raw = await load('assets/dummy/mock/assets.json');
      return _parseAssetStatuses(raw);
    } on FlutterError {
      try {
        final raw = await load('assets/mock/assets.json');
        return _parseAssetStatuses(raw);
      } on FlutterError {
        return {};
      }
    }
  }

  Map<String, String> _parseAssetStatuses(String raw) {
    final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
    final map = <String, String>{};
    for (final item in decoded) {
      final uid = _stringOrNull(item['asset_uid']) ?? _stringOrNull(item['uid']);
      final status =
          _stringOrNull(item['assets_status']) ?? _stringOrNull(item['status']);
      if (uid != null && status != null) {
        map[uid] = status;
      }
    }
    return map;
  }

  String? _stringOrNull(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }

  String? _buildMemo(Map<String, dynamic> item) {
    final lines = <String>[];
    final inspector = _stringOrNull(item['inspector_name']);
    final team = _stringOrNull(item['user_team']);
    final maintenance = _stringOrNull(item['maintenance_company_staff']);
    final confirm = _stringOrNull(item['department_confirm']);
    final assetInfo = item['asset_info'];
    if (inspector != null) {
      lines.add('점검자: $inspector');
    }
    if (team != null) {
      lines.add('소속: $team');
    }
    if (assetInfo is Map<String, dynamic>) {
      final usage = _stringOrNull(assetInfo['usage']);
      final model = _stringOrNull(assetInfo['model_name']);
      final serial = _stringOrNull(assetInfo['serial_number']);
      if (usage != null) {
        lines.add('용도: $usage');
      }
      if (model != null) {
        lines.add('모델: $model');
      }
      if (serial != null) {
        lines.add('시리얼: $serial');
      }
    }
    if (maintenance != null) {
      lines.add('유지보수: $maintenance');
    }
    if (confirm != null) {
      lines.add('확인부서: $confirm');
    }
    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }
}
