import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../data/api_client.dart';
import '../data/inspection_repository.dart';
import '../models/asset_info.dart';
import '../models/inspection.dart';
import '../models/user_info.dart';

/// Provider responsible for bridging the UI with repositories and the backend API.
class InspectionProvider extends ChangeNotifier {
  InspectionProvider(this._repository, this._apiClient);

  final InspectionRepository _repository;
  final ApiClient _apiClient;

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

  bool assetExists(String uid) => _assetMap.containsKey(uid);

  UserInfo? userOf(String id) => _userMap[id];

  Future<void> initialize() async {
    await _apiClient.ensureAuthenticated();
    final assetsFuture = _apiClient.fetchAssets();
    final usersFuture = _apiClient.fetchUsers();
    await _repository.synchronize();
    final assets = await assetsFuture;
    final users = await usersFuture;
    _assetMap
      ..clear()
      ..addEntries(assets.map((asset) => MapEntry(asset.uid, asset)));
    _userMap.clear();
    for (final user in users) {
      _userMap[user.id] = user;
      final employeeId = user.employeeId;
      if (employeeId != null && employeeId.isNotEmpty) {
        _userMap[employeeId] = user;
      }
      final numericId = user.numericId;
      if (numericId != null && numericId.isNotEmpty) {
        _userMap[numericId] = user;
      }
    }
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

  Future<void> addOrUpdate(Inspection inspection) async {
    final updated = await _repository.upsert(inspection);
    final index = _items.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      _items[index] = updated;
    } else {
      _items.add(updated);
    }
    _items.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    _items = _repository.getAll();
    notifyListeners();
  }

  Future<void> upsertAssetInfo(AssetInfo asset) async {
    await _apiClient.upsertAsset(asset);
    _assetMap[asset.uid] = asset;
    notifyListeners();
  }

  void setOnlyUnsynced(bool value) {
    if (_onlyUnsynced == value) return;
    _onlyUnsynced = value;
    notifyListeners();
  }
}
