import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset_inspection.dart';
import '../services/api_service.dart';
import '../constants.dart';

/// 실사 목록 상태
class InspectionListState {
  final List<AssetInspection> inspections;
  final int total;
  final int page;
  final int totalPages;
  final bool isLoading;

  const InspectionListState({
    this.inspections = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.isLoading = false,
  });

  InspectionListState copyWith({
    List<AssetInspection>? inspections,
    int? total,
    int? page,
    int? totalPages,
    bool? isLoading,
  }) {
    return InspectionListState(
      inspections: inspections ?? this.inspections,
      total: total ?? this.total,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 실사 목록 관리 Notifier
class InspectionNotifier extends Notifier<InspectionListState> {
  late final ApiService _apiService;

  @override
  InspectionListState build() {
    _apiService = ApiService();
    return const InspectionListState();
  }

  /// 실사 목록 조회
  Future<void> fetchInspections({
    int page = 1,
    int pageSize = defaultPageSize,
    String? status,
    String? search,
    String? building,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final result = await _apiService.fetchInspections(
        page: page,
        pageSize: pageSize,
        status: status,
        search: search,
        building: building,
      );

      final totalPages = (result.total / pageSize).ceil();

      state = state.copyWith(
        inspections: result.data,
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

  /// 실사 등록 후 목록 새로고침
  Future<AssetInspection> createInspection(Map<String, dynamic> data) async {
    final created = await _apiService.createInspection(data);
    await fetchInspections(page: state.page);
    return created;
  }

  /// 실사 수정 후 목록 새로고침
  Future<AssetInspection> updateInspection(
    int id,
    Map<String, dynamic> data,
  ) async {
    final updated = await _apiService.updateInspection(id, data);
    await fetchInspections(page: state.page);
    return updated;
  }

  /// 실사 초기화 (RPC) 후 목록 새로고침
  Future<void> resetInspection(int id, String reason) async {
    await _apiService.resetInspection(inspectionId: id, reason: reason);
    await fetchInspections(page: state.page);
  }
}

/// 실사 목록 Provider
final inspectionNotifierProvider =
    NotifierProvider<InspectionNotifier, InspectionListState>(
        InspectionNotifier.new);
