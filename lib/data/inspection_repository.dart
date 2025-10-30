import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../models/inspection.dart';
import 'api_client.dart';
import 'mock_data_loader.dart';

/// Repository responsible for synchronizing inspection data with the backend
/// API while providing a local mock fallback defined in /docs.
class InspectionRepository {
  InspectionRepository(this._apiClient, this._mockDataLoader);

  final ApiClient _apiClient;
  final MockDataLoader _mockDataLoader;
  final List<Inspection> _items = [];
  bool _usingMockData = false;

  bool get usingMockData => _usingMockData;

  Future<void> synchronize({int pageSize = 500}) async {
    try {
      final fetched = await _apiClient.fetchInspections(pageSize: pageSize);
      _items
        ..clear()
        ..addAll(fetched);
      _sortItems();
      _usingMockData = false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Falling back to mock inspections: $error');
      }
      await loadMockData();
    }
  }

  Future<void> loadMockData() async {
    final fallback = await _mockDataLoader.loadInspections();
    _items
      ..clear()
      ..addAll(fallback);
    _sortItems();
    _usingMockData = true;
  }

  List<Inspection> getAll() => List.unmodifiable(_items);

  Inspection? findById(String id) {
    return _items.firstWhereOrNull((item) => item.id == id);
  }

  Future<Inspection> upsert(Inspection inspection) async {
    if (_usingMockData) {
      final updated = inspection.copyWith(synced: false);
      final index = _items.indexWhere((item) => item.id == updated.id);
      if (index >= 0) {
        _items[index] = updated;
      } else {
        _items.add(updated);
      }
      _sortItems();
      return updated;
    }

    final existingIndex = _items.indexWhere((item) => item.id == inspection.id);
    Inspection updated;
    if (existingIndex >= 0) {
      updated = await _apiClient.updateInspection(inspection);
      _items[existingIndex] = updated;
    } else {
      updated = await _apiClient.createInspection(inspection);
      _items.add(updated);
    }
    _sortItems();
    return updated;
  }

  Future<void> delete(String id) async {
    if (_usingMockData) {
      _items.removeWhere((item) => item.id == id);
      return;
    }
    await _apiClient.deleteInspection(id);
    _items.removeWhere((item) => item.id == id);
  }

  void _sortItems() {
    _items.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }
}
