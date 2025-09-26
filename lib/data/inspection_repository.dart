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
      final raw = await rootBundle.loadString('assets/mock/asset_inspections.json');
      final decoded = (jsonDecode(raw) as List<dynamic>).cast<Map<String, dynamic>>();
      _items
        ..clear()
        ..addAll(decoded.map(Inspection.fromJson));
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
}
