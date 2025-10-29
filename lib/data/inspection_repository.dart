import 'package:collection/collection.dart';

import '../models/inspection.dart';
import 'api_client.dart';

/// Repository responsible for synchronizing inspection data with the backend API.
class InspectionRepository {
  InspectionRepository(this._apiClient);

  final ApiClient _apiClient;
  final List<Inspection> _items = [];

  Future<void> synchronize() async {
    final fetched = await _apiClient.fetchInspections(pageSize: 500);
    _items
      ..clear()
      ..addAll(fetched);
    _sortItems();
  }

  List<Inspection> getAll() => List.unmodifiable(_items);

  Inspection? findById(String id) {
    return _items.firstWhereOrNull((item) => item.id == id);
  }

  Future<Inspection> upsert(Inspection inspection) async {
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
    await _apiClient.deleteInspection(id);
    _items.removeWhere((item) => item.id == id);
  }

  void _sortItems() {
    _items.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
  }
}
