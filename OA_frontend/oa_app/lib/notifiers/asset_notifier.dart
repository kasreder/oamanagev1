import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../services/api_service.dart';
import '../constants.dart';

/// 자산 목록 상태
class AssetListState {
  final List<Asset> assets;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;

  const AssetListState({
    this.assets = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.isLoading = false,
  });

  AssetListState copyWith({
    List<Asset>? assets,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
  }) {
    return AssetListState(
      assets: assets ?? this.assets,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 자산 목록 관리 Notifier
class AssetNotifier extends Notifier<AssetListState> {
  late final ApiService _apiService;

  @override
  AssetListState build() {
    _apiService = ApiService();
    return const AssetListState();
  }

  /// 자산 목록 조회
  Future<void> fetchAssets({
    int page = 1,
    int pageSize = defaultPageSize,
    String? category,
    String? status,
    String? search,
    String? building,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await _apiService.fetchAssets(
        page: page,
        pageSize: pageSize,
        category: category,
        status: status,
        search: search,
        building: building,
      );

      final totalPages = (result.total / pageSize).ceil();

      state = state.copyWith(
        assets: result.data,
        total: result.total,
        page: page,
        totalPages: totalPages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// 자산 등록 후 목록 새로고침
  Future<Asset> createAsset(Map<String, dynamic> data) async {
    final created = await _apiService.createAsset(data);
    await fetchAssets(page: state.page);
    return created;
  }

  /// 자산 수정 후 목록 새로고침
  Future<Asset> updateAsset(int id, Map<String, dynamic> data) async {
    final updated = await _apiService.updateAsset(id, data);
    await fetchAssets(page: state.page);
    return updated;
  }

  /// 자산 삭제 후 목록 새로고침
  Future<void> deleteAsset(int id) async {
    await _apiService.deleteAsset(id);
    await fetchAssets(page: state.page);
  }
}

/// 자산 목록 Provider
final assetNotifierProvider =
    NotifierProvider<AssetNotifier, AssetListState>(AssetNotifier.new);
