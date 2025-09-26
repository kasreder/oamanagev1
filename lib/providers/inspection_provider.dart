import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/inspection_repository.dart';
import '../data/reference_repository.dart';
import '../models/inspection.dart';

/// ChangeNotifier 기반의 실사 상태 제공자.
class InspectionProvider extends ChangeNotifier {
  InspectionProvider(this._repository, this._referenceRepository);

  final InspectionRepository _repository;
  final ReferenceDataRepository _referenceRepository;
  // TODO: 미동기화 전송 큐와 POST /inspections/sync 연동 구현

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

  AssetInfo? assetOf(String uid) => _referenceRepository.findAsset(uid);

  Future<void> initialize() async {
    await _referenceRepository.loadFromAssets();
    await _repository.loadFromAssets();
    _items = _repository.getAll();
    _initialized = true;
    notifyListeners();
  }

  Inspection? findById(String id) {
    return _repository.findById(id);
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
}
