import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/csv_downloader_stub.dart'
    if (dart.library.html) '../utils/csv_downloader_web.dart';

import '../constants.dart';
import '../models/asset.dart';
import '../models/search_condition.dart';
import '../services/api_service.dart';
import '../notifiers/agent_presence_notifier.dart';
import '../widgets/asset_search_dialog.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.3 자산 목록 화면 (/assets)
///
/// - 상단: FilterBar (카테고리, 상태, 검색, 자산등록) 한 줄
/// - 컬럼을 선택/순서 변경 가능한 표 형태 자산 목록
/// - 30건 페이지네이션
/// - 행 클릭 -> /asset/:id
/// - 앱바 ? 아이콘 -> 자산번호 부여 기준 안내
class AssetListPage extends ConsumerStatefulWidget {
  const AssetListPage({super.key});

  @override
  ConsumerState<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends ConsumerState<AssetListPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _verticalBarController = ScrollController();
  bool _syncingScroll = false;
  final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  List<Asset> _assets = [];
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isExporting = false;  // CSV 전체 export 진행 중
  bool _hasMore = true;
  int _loadedPage = 0;
  static const int _pageSize = 100;  // 500→100, 무한스크롤로 추가 로드
  String? _error;

  // 필터 상태
  String? _selectedCategory;
  String? _selectedStatus;
  String _searchQuery = '';
  List<SearchCondition> _searchConditions = [];

  // 정렬 상태 — 컬럼 라벨 + DB 컬럼 키. 서버 정렬에 사용.
  String? _sortColumnLabel;
  bool _sortAscending = true;

  // 서버 정렬 가능 컬럼 화이트리스트 (라벨 → DB 컬럼)
  static const Map<String, String> _serverSortKeys = {
    'ID': 'id',
    '자산번호': 'asset_uid',
    '자산명': 'name',
    '상태': 'assets_status',
    '유형': 'category',
    '지급형태': 'supply_type',
    '시리얼': 'serial_number',
    '모델명': 'model_name',
    '제조사': 'vendor',
    '건물': 'building',
    '층': 'floor',
    '실사용자': 'user_name',
    '소유자': 'owner_name',
    '관리자': 'admin_name',
    '등록일': 'created_at',
    '수정일': 'updated_at',
    '마지막 접속': 'last_active_at',
  };

  static const double _colId = 80;
  static const double _colAssetUid = 170;
  static const double _colName = 230;
  static const double _colStatus = 130;
  static const double _colSupplyType = 130;
  static const double _colSupplyEndDate = 170;
  static const double _colCategory = 130;
  static const double _colSerial = 180;
  static const double _colModelName = 170;
  static const double _colVendor = 140;
  static const double _colNetwork = 130;
  static const double _colPhysicalDate = 170;
  static const double _colConfirmDate = 170;
  static const double _colNormalComment = 220;
  static const double _colOaComment = 220;
  static const double _colMacAddress = 150;
  static const double _colBuilding1 = 140;
  static const double _colBuilding = 130;
  static const double _colFloor = 110;
  static const double _colOwnerName = 140;
  static const double _colOwnerDept = 150;
  static const double _colUserName = 140;
  static const double _colUserDept = 150;
  static const double _colAdminName = 140;
  static const double _colAdminDept = 150;
  static const double _colLocationDrawingId = 150;
  static const double _colLocationRow = 90;
  static const double _colLocationCol = 90;
  static const double _colLocationFile = 250;
  static const double _colUserId = 80;
  static const double _colCreatedAt = 170;
  static const double _colUpdatedAt = 170;
  static const double _colAccessStatus = 60;
  static const double _colOsType = 130;
  static const double _colOsVersion = 180;
  static const double _colOsDetail = 280;
  static const double _colVerificationStatus = 80;
  static const double _colAssignmentStatus = 100;

  static const List<_AssetColumnMeta> _allColumns = [
    _AssetColumnMeta(label: 'ID', width: _colId, value: _assetId),
    _AssetColumnMeta(label: '자산번호', width: _colAssetUid, value: _assetUid),
    _AssetColumnMeta(label: '자산명', width: _colName, value: _assetName),
    _AssetColumnMeta(label: '상태', width: _colStatus, value: _assetStatus),
    _AssetColumnMeta(label: '지급형태', width: _colSupplyType, value: _assetSupplyType),
    _AssetColumnMeta(label: '지급만료일', width: _colSupplyEndDate, value: _assetSupplyEndDate),
    _AssetColumnMeta(label: '유형', width: _colCategory, value: _assetCategory),
    _AssetColumnMeta(label: '시리얼번호', width: _colSerial, value: _assetSerialNumber),
    _AssetColumnMeta(label: '모델명', width: _colModelName, value: _assetModelName),
    _AssetColumnMeta(label: '제조사', width: _colVendor, value: _assetVendor),
    _AssetColumnMeta(label: '네트워크', width: _colNetwork, value: _assetNetwork),
    _AssetColumnMeta(label: '실사일', width: _colPhysicalDate, value: _assetPhysicalCheckDate),
    _AssetColumnMeta(label: '확인일', width: _colConfirmDate, value: _assetConfirmationDate),
    _AssetColumnMeta(label: '일반비고', width: _colNormalComment, value: _assetNormalComment),
    _AssetColumnMeta(label: 'OA비고', width: _colOaComment, value: _assetOaComment),
    _AssetColumnMeta(label: 'MAC주소', width: _colMacAddress, value: _assetMacAddress),
    _AssetColumnMeta(label: '건물(대)', width: _colBuilding1, value: _assetBuilding1),
    _AssetColumnMeta(label: '건물', width: _colBuilding, value: _assetBuilding),
    _AssetColumnMeta(label: '층', width: _colFloor, value: _assetFloor),
    _AssetColumnMeta(label: '실사용자', width: _colUserName, value: _assetUserName),
    _AssetColumnMeta(label: '실사용부서', width: _colUserDept, value: _assetUserDepartment),
    _AssetColumnMeta(label: '실사용자사번', width: 120, value: _assetUserEmployeeId),
    _AssetColumnMeta(label: '소유자', width: _colOwnerName, value: _assetOwnerName),
    _AssetColumnMeta(label: '소유부서', width: _colOwnerDept, value: _assetOwnerDepartment),
    _AssetColumnMeta(label: '소유자사번', width: 120, value: _assetOwnerEmployeeId),
    _AssetColumnMeta(label: '관리자', width: _colAdminName, value: _assetAdminName),
    _AssetColumnMeta(label: '관리부서', width: _colAdminDept, value: _assetAdminDepartment),
    _AssetColumnMeta(label: '관리자사번', width: 120, value: _assetAdminEmployeeId),
    _AssetColumnMeta(label: '접속현황', width: _colAccessStatus, value: _assetAccessStatusText, widgetBuilder: _accessStatusWidget),
    _AssetColumnMeta(label: 'OS종류', width: _colOsType, value: _assetOsType),
    _AssetColumnMeta(label: 'OS버전', width: _colOsVersion, value: _assetOsVersion),
    _AssetColumnMeta(label: 'OS상세', width: _colOsDetail, value: _assetOsDetail),
    _AssetColumnMeta(label: '도면ID', width: _colLocationDrawingId, value: _assetLocationDrawingId),
    _AssetColumnMeta(label: '위치(행)', width: _colLocationRow, value: _assetLocationRow),
    _AssetColumnMeta(label: '위치(열)', width: _colLocationCol, value: _assetLocationCol),
    _AssetColumnMeta(label: '도면파일', width: _colLocationFile, value: _assetLocationDrawingFile),
    _AssetColumnMeta(label: '등록자ID', width: _colUserId, value: _assetUserId),
    _AssetColumnMeta(label: '등록일', width: _colCreatedAt, value: _assetCreatedAt),
    _AssetColumnMeta(label: '수정일', width: _colUpdatedAt, value: _assetUpdatedAt),
    _AssetColumnMeta(label: '사용자확인', width: _colVerificationStatus, value: _assetVerificationStatusText, widgetBuilder: _verificationStatusWidget),
    _AssetColumnMeta(label: '배정상태', width: _colAssignmentStatus, value: _assetAssignmentStatusText, widgetBuilder: _assignmentStatusWidget),
    _AssetColumnMeta(label: '실사회차', width: 80, value: _assetInspectionRoundNo),
  ];

  static String _assetInspectionRoundNo(Asset asset, DateFormat _) =>
      '${asset.inspectionRoundNo}차';

  late List<_AssetColumnMeta> _orderedColumns;
  late Map<String, bool> _columnVisibility;
  late Map<String, double> _columnWidths;

  // 컬럼 설정 저장 키 (localStorage on web)
  static const String _columnConfigPrefsKey = 'asset_list_column_config_v1';


  List<_AssetColumnMeta> get _visibleColumns => _orderedColumns
      .where((column) => _columnVisibility[column.label] ?? false)
      .toList();

  double _getColWidth(String label) => _columnWidths[label] ?? 100;

  double get _tableWidth =>
      _visibleColumns.fold(0.0, (sum, col) => sum + _getColWidth(col.label));

  @override
  void initState() {
    super.initState();
    _orderedColumns = List<_AssetColumnMeta>.from(_allColumns);
    _columnVisibility = {for (final column in _allColumns) column.label: true};
    _columnWidths = {for (final column in _allColumns) column.label: column.width};
    _loadColumnConfig(); // 저장된 컬럼 설정 복원 (async, 즉시 반환)
    _loadAssets();

    // 세로 스크롤 동기화 + 무한스크롤 (끝 200px 도달 시 다음 페이지)
    _verticalScrollController.addListener(() {
      if (!_syncingScroll) {
        _syncingScroll = true;
        if (_verticalBarController.hasClients) {
          _verticalBarController.jumpTo(_verticalScrollController.offset);
        }
        _syncingScroll = false;
      }
      final pos = _verticalScrollController.position;
      if (_hasMore &&
          !_isLoadingMore &&
          pos.pixels >= pos.maxScrollExtent - 200) {
        _loadNextPage();
      }
    });
    _verticalBarController.addListener(() {
      if (_syncingScroll) return;
      _syncingScroll = true;
      if (_verticalScrollController.hasClients) {
        _verticalScrollController.jumpTo(_verticalBarController.offset);
      }
      _syncingScroll = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _verticalBarController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _assets = [];
      _loadedPage = 0;
      _hasMore = true;
    });

    await _loadNextPage();
    // 백그라운드 전수 로딩 제거 — 무한 스크롤로 필요할 때만 추가 fetch
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    _loadedPage++;

    try {
      final orderBy = _sortColumnLabel != null
          ? (_serverSortKeys[_sortColumnLabel!] ?? 'id')
          : 'id';
      final ascending = _sortColumnLabel != null ? _sortAscending : false;

      final result = await _api.fetchAssets(
        page: _loadedPage,
        pageSize: _pageSize,
        category: _selectedCategory,
        status: _selectedStatus,
        search: _searchConditions.isEmpty && _searchQuery.isNotEmpty
            ? _searchQuery
            : null,
        conditions: _searchConditions,
        orderBy: orderBy,
        ascending: ascending,
      );

      setState(() {
        _assets.addAll(result.data);
        _totalCount = result.total;
        _hasMore = _assets.length < result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = _assets.isEmpty ? e.toString() : null;
      });
    }
  }

  /// CSV export용 — 현재 필터로 전체 로드 (정렬 적용)
  Future<void> _loadAllForExport() async {
    while (_hasMore && mounted) {
      await _loadNextPage();
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void _onSortColumn(String label) {
    if (!_serverSortKeys.containsKey(label)) return; // 서버 정렬 미지원 컬럼은 무시
    setState(() {
      if (_sortColumnLabel == label) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnLabel = label;
        _sortAscending = true;
      }
    });
    _loadAssets(); // 서버 정렬로 재fetch
  }

  void _onCategoryChanged(String? category) {
    _selectedCategory = category;
    _loadAssets();
  }

  void _onStatusChanged(String? status) {
    _selectedStatus = status;
    _loadAssets();
  }

  void _onSearch(String query) {
    _searchQuery = query;
    _loadAssets();
  }

  /// 적용된 검색 조건을 chip으로 표시 (조건 비면 hide).
  Widget _buildAppliedConditionsBar(BuildContext context) {
    if (_searchConditions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _searchConditions.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _searchConditions[i].joiner == Joiner.or
                              ? Colors.deepOrange.shade100
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _searchConditions[i].joiner == Joiner.or
                              ? 'OR'
                              : 'AND',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _searchConditions[i].joiner == Joiner.or
                                ? Colors.deepOrange.shade900
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Chip(
                      label: Text(
                        '${_searchConditions[i].column.label} '
                        '${_searchConditions[i].op == SearchOp.eq ? '=' : 'like'} '
                        '"${_searchConditions[i].value}"',
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _clearSearchConditions,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('초기화'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearchDialog() async {
    final result = await AssetSearchDialog.show(context, initial: _searchConditions);
    if (result == null) return;
    setState(() {
      _searchConditions = result;
      _searchQuery = '';
      _searchController.clear();
    });
    _loadAssets();
  }

  void _clearSearchConditions() {
    if (_searchConditions.isEmpty) return;
    setState(() => _searchConditions = []);
    _loadAssets();
  }

  // ── 컬럼 설정 저장/로드 ──────────────────────────────────────────────────
  Future<void> _loadColumnConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_columnConfigPrefsKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      // 저장된 순서 + 새로 추가된 컬럼은 끝에 append (호환성)
      final byLabel = {for (final c in _allColumns) c.label: c};
      final savedOrder = (json['order'] as List?)?.cast<String>() ?? [];
      final newOrder = <_AssetColumnMeta>[];
      final seen = <String>{};
      for (final label in savedOrder) {
        final c = byLabel[label];
        if (c != null && !seen.contains(label)) {
          newOrder.add(c);
          seen.add(label);
        }
      }
      for (final c in _allColumns) {
        if (!seen.contains(c.label)) newOrder.add(c);
      }

      final visibility = (json['visibility'] as Map?) ?? {};
      final widths = (json['widths'] as Map?) ?? {};

      if (!mounted) return;
      setState(() {
        _orderedColumns = newOrder;
        for (final entry in visibility.entries) {
          final key = entry.key.toString();
          if (_columnVisibility.containsKey(key)) {
            _columnVisibility[key] = entry.value == true;
          }
        }
        for (final entry in widths.entries) {
          final key = entry.key.toString();
          if (_columnWidths.containsKey(key) && entry.value is num) {
            _columnWidths[key] = (entry.value as num).toDouble();
          }
        }
      });
    } catch (_) {
      // 저장 형식 불일치 등은 무시 (기본값 사용)
    }
  }

  Future<void> _saveColumnConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'order': _orderedColumns.map((c) => c.label).toList(),
        'visibility': _columnVisibility,
        'widths': _columnWidths,
      };
      await prefs.setString(_columnConfigPrefsKey, jsonEncode(payload));
    } catch (_) {
      // 저장 실패는 silently 무시 (다음 변경 시 재시도)
    }
  }

  Future<void> _resetColumnConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_columnConfigPrefsKey);
    } catch (_) {}
    setState(() {
      _orderedColumns = List<_AssetColumnMeta>.from(_allColumns);
      _columnVisibility = {for (final c in _allColumns) c.label: true};
      _columnWidths = {for (final c in _allColumns) c.label: c.width};
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '자산 목록',
      currentIndex: 2,
      body: Column(
        children: [
          _buildFilterBar(context),
          _buildAppliedConditionsBar(context),
          _buildToolbar(context),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// 모바일 너비 판단 (작은 화면이면 버튼 라벨 숨기고 아이콘만)
  bool _isCompactWidth(BuildContext ctx) =>
      MediaQuery.of(ctx).size.width < 720;

  /// 컬럼설정/엑셀 + 카운터 한 줄 툴바
  Widget _buildToolbar(BuildContext context) {
    final compact = _isCompactWidth(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            _CompactButton(
              compact: compact,
              icon: Icons.view_column,
              label: '열 표시 설정',
              tooltip: '열 표시 설정',
              onPressed: () => _openColumnConfigDialog(context),
            ),
            const SizedBox(width: 4),
            _CompactButton(
              compact: compact,
              icon: Icons.download,
              label: '엑셀 다운로드',
              tooltip: '엑셀 다운로드',
              onPressed:
                  (_assets.isEmpty || _isExporting) ? null : _downloadCsvAll,
            ),
            const Spacer(),
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!_isLoading)
              Text(
                _isExporting
                    ? '전체 데이터 로딩 중...'
                    : '${_assets.length} / 총 ${_totalCount}건',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  /// 필터 바 (카테고리, 상태, 검색, 고급검색, 등록) - 한 줄 컴팩트
  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
    final compact = _isCompactWidth(context);
    const dense = EdgeInsets.symmetric(horizontal: 6, vertical: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // 카테고리 드롭다운
          SizedBox(
            width: compact ? 90 : 110,
            height: 32,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                hintText: '카테고리',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
                contentPadding: dense,
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodySmall,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('전체')),
                ...assetCategories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ),
              ],
              onChanged: _onCategoryChanged,
            ),
          ),
          const SizedBox(width: 4),

          // 상태 드롭다운
          SizedBox(
            width: compact ? 70 : 90,
            height: 32,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                hintText: '상태',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                isDense: true,
                contentPadding: dense,
                border: OutlineInputBorder(),
              ),
              style: theme.textTheme.bodySmall,
              isExpanded: true,
              items: [
                const DropdownMenuItem(value: null, child: Text('전체')),
                ...assetStatuses.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: _onStatusChanged,
            ),
          ),
          const SizedBox(width: 4),

          // 검색 입력 필드 (간단 검색)
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: compact ? '검색' : '자산번호/자산명/사용자',
                  hintStyle: theme.textTheme.bodySmall,
                  isDense: true,
                  contentPadding: dense,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(maxWidth: 28),
                    onPressed: () => _onSearch(_searchController.text),
                  ),
                ),
                style: theme.textTheme.bodySmall,
                textInputAction: TextInputAction.search,
                onSubmitted: _onSearch,
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 고급 검색 버튼
          _CompactButton(
            compact: compact,
            icon: _searchConditions.isEmpty ? Icons.tune : Icons.filter_alt,
            iconColor: _searchConditions.isEmpty
                ? null
                : theme.colorScheme.primary,
            label: _searchConditions.isEmpty
                ? '고급 검색'
                : '조건 ${_searchConditions.length}',
            tooltip: _searchConditions.isEmpty
                ? '고급 검색'
                : '조건 ${_searchConditions.length}개 적용 중',
            onPressed: _openSearchDialog,
          ),
          const SizedBox(width: 4),

          // 자산등록 버튼 (FilledButton)
          _CompactButton(
            compact: compact,
            filled: true,
            icon: Icons.add,
            label: '등록',
            tooltip: '자산 등록',
            onPressed: () => context.go('/asset/new'),
          ),
        ],
      ),
    );
  }

  /// 본문 (로딩/에러/빈 상태/목록)
  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '자산 목록을 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadAssets);
    }
    if (_assets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.inventory_2,
        message: '자산이 없습니다.',
        subMessage: '상단 등록 버튼으로 새 자산을 등록하세요.',
      );
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
      child: Row(
        children: [
          // ── 메인 테이블 영역 ──
          Expanded(
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _horizontalScrollController,
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _tableWidth,
                  child: Column(
                    children: [
                      _buildTableHeader(context),
                      Expanded(
                        child: ListView.builder(
                          controller: _verticalScrollController,
                          itemCount: _assets.length,
                          itemExtent: 42,
                          itemBuilder: (context, i) => _buildTableRow(
                            context: context,
                            asset: _assets[i],
                            rowIndex: i,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── 세로 스크롤바 (화면 오른쪽 고정) ──
          SizedBox(
            width: 14,
            child: Scrollbar(
              controller: _verticalBarController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _verticalBarController,
                child: SizedBox(
                  height: _assets.length * 42.0 + 44,
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _visibleColumns;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            _buildResizableHeaderCell(
              columns[i].label,
              _getColWidth(columns[i].label),
              context,
              isLast: i == columns.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required BuildContext context,
    required Asset asset,
    required int rowIndex,
  }) {
    final theme = Theme.of(context);
    final columns = _visibleColumns;
    final rowColor = rowIndex.isEven
        ? theme.colorScheme.surface
        : theme.colorScheme.surfaceContainerLowest;

    return InkWell(
      onTap: () => context.go('/asset/${asset.id}'),
      child: Container(
        color: rowColor,
        child: Row(
          children: [
            for (int i = 0; i < columns.length; i++)
              if (columns[i].widgetBuilder != null)
                _buildWidgetCell(
                  columns[i].widgetBuilder!(asset, context),
                  _getColWidth(columns[i].label),
                  context,
                  isLast: i == columns.length - 1,
                )
              else
                _buildBodyCell(
                  columns[i].value(asset, _dateTimeFmt),
                  _getColWidth(columns[i].label),
                  context,
                  isLast: i == columns.length - 1,
                ),
          ],
        ),
      ),
    );
  }

  Future<void> _openColumnConfigDialog(BuildContext context) async {
    final tempOrder = List<_AssetColumnMeta>.from(_orderedColumns);
    final tempVisibility = Map<String, bool>.from(_columnVisibility);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final visibleCount =
                tempVisibility.values.where((visible) => visible).length;

            return AlertDialog(
              title: const Text('열 표시 설정'),
              content: SizedBox(
                width: 420,
                height: 480,
                child: ReorderableListView.builder(
                  itemCount: tempOrder.length,
                  onReorder: (oldIndex, newIndex) {
                    if (newIndex > oldIndex) newIndex -= 1;

                    final item = tempOrder.removeAt(oldIndex);
                    tempOrder.insert(newIndex, item);
                    setDialogState(() {});
                  },
                  itemBuilder: (context, index) {
                    final column = tempOrder[index];
                    final isVisible = tempVisibility[column.label] ?? false;
                    final allowHide = visibleCount > 1 || !isVisible;

                    return ListTile(
                      key: ValueKey(column.label),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(column.label),
                      trailing: Checkbox(
                        value: isVisible,
                        onChanged: allowHide
                            ? (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  tempVisibility[column.label] = value;
                                });
                              }
                            : null,
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _resetColumnConfig();
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.restore, size: 16),
                  label: const Text('기본값'),
                ),
                ElevatedButton(
                  onPressed: visibleCount > 0
                      ? () {
                          setState(() {
                            _orderedColumns = tempOrder;
                            _columnVisibility = tempVisibility;
                          });
                          _saveColumnConfig(); // 컬럼 순서/표시 변경 저장
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResizableHeaderCell(
    String label,
    double width,
    BuildContext context, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 배경 + 텍스트 + 테두리 + 정렬 클릭
          Positioned.fill(
            child: InkWell(
              onTap: () => _onSortColumn(label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    right: isLast
                        ? BorderSide.none
                        : BorderSide(color: theme.dividerColor),
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_sortColumnLabel == label) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 드래그 핸들 (오른쪽 경계)
          if (!isLast)
            Positioned(
              right: -3,
              top: 0,
              bottom: 0,
              width: 6,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      final newWidth =
                          (_columnWidths[label] ?? 100) + details.delta.dx;
                      _columnWidths[label] = newWidth.clamp(50, 600);
                    });
                  },
                  // drag 종료 시점에 한 번만 저장 (Update마다 저장하면 부하)
                  onHorizontalDragEnd: (_) => _saveColumnConfig(),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBodyCell(
    String value,
    double width,
    BuildContext context, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: isLast
                ? BorderSide.none
                : BorderSide(color: theme.dividerColor),
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
          ),
        ),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }

  Widget _buildWidgetCell(
    Widget child,
    double width,
    BuildContext context, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            right: isLast
                ? BorderSide.none
                : BorderSide(color: theme.dividerColor),
            bottom: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  static String _assetId(Asset asset, DateFormat _) => asset.id.toString();

  static String _assetUid(Asset asset, DateFormat _) => asset.assetUid;

  static String _assetName(Asset asset, DateFormat _) => asset.name ?? '[NULL]';

  static String _assetStatus(Asset asset, DateFormat _) => asset.assetsStatus;

  static String _assetSupplyType(Asset asset, DateFormat _) => asset.supplyType;

  static String _assetSupplyEndDate(Asset asset, DateFormat dateFormat) =>
      _formatStaticDate(asset.supplyEndDate, dateFormat);

  static String _assetCategory(Asset asset, DateFormat _) => asset.category;

  static String _assetSerialNumber(Asset asset, DateFormat _) =>
      asset.serialNumber ?? '[NULL]';

  static String _assetModelName(Asset asset, DateFormat _) =>
      asset.modelName ?? '[NULL]';

  static String _assetVendor(Asset asset, DateFormat _) =>
      asset.vendor ?? '[NULL]';

  static String _assetNetwork(Asset asset, DateFormat _) =>
      asset.network ?? '[NULL]';

  static String _assetPhysicalCheckDate(Asset asset, DateFormat dateFormat) =>
      _formatStaticDate(asset.physicalCheckDate, dateFormat);

  static String _assetConfirmationDate(Asset asset, DateFormat dateFormat) =>
      _formatStaticDate(asset.confirmationDate, dateFormat);

  static String _assetNormalComment(Asset asset, DateFormat _) =>
      asset.normalComment ?? '[NULL]';

  static String _assetOaComment(Asset asset, DateFormat _) =>
      asset.oaComment ?? '[NULL]';

  static String _assetMacAddress(Asset asset, DateFormat _) =>
      asset.macAddress ?? '[NULL]';

  static String _assetBuilding1(Asset asset, DateFormat _) =>
      asset.building1 ?? '[NULL]';

  static String _assetBuilding(Asset asset, DateFormat _) =>
      asset.building ?? '[NULL]';

  static String _assetFloor(Asset asset, DateFormat _) =>
      asset.floor ?? '[NULL]';

  static String _assetOwnerName(Asset asset, DateFormat _) =>
      asset.ownerName ?? '[NULL]';

  static String _assetOwnerDepartment(Asset asset, DateFormat _) =>
      asset.ownerDepartment ?? '[NULL]';

  static String _assetUserName(Asset asset, DateFormat _) =>
      asset.userName ?? '[NULL]';

  static String _assetUserDepartment(Asset asset, DateFormat _) =>
      asset.userDepartment ?? '[NULL]';

  static String _assetAdminName(Asset asset, DateFormat _) =>
      asset.adminName ?? '[NULL]';

  static String _assetAdminDepartment(Asset asset, DateFormat _) =>
      asset.adminDepartment ?? '[NULL]';

  static String _assetLocationDrawingId(Asset asset, DateFormat _) =>
      asset.locationDrawingId?.toString() ?? '[NULL]';

  static String _assetLocationRow(Asset asset, DateFormat _) =>
      asset.locationRow?.toString() ?? '[NULL]';

  static String _assetLocationCol(Asset asset, DateFormat _) =>
      asset.locationCol?.toString() ?? '[NULL]';

  static String _assetLocationDrawingFile(Asset asset, DateFormat _) =>
      asset.locationDrawingFile ?? '[NULL]';

  static String _assetUserId(Asset asset, DateFormat _) =>
      asset.userId?.toString() ?? '[NULL]';

  static String _assetCreatedAt(Asset asset, DateFormat dateFormat) =>
      _formatStaticDate(asset.createdAt, dateFormat);

  static String _assetUpdatedAt(Asset asset, DateFormat dateFormat) =>
      _formatStaticDate(asset.updatedAt, dateFormat);

  static String _assetUserEmployeeId(Asset asset, DateFormat _) =>
      asset.userEmployeeId ?? '[NULL]';

  static String _assetOwnerEmployeeId(Asset asset, DateFormat _) =>
      asset.ownerEmployeeId ?? '[NULL]';

  static String _assetAdminEmployeeId(Asset asset, DateFormat _) =>
      asset.adminEmployeeId ?? '[NULL]';

  // ── OS 정보 (에이전트 전송 데이터) ──────────────────────────────────────

  static String _assetOsType(Asset asset, DateFormat _) {
    final ds = asset.specifications['device_status'] as Map<String, dynamic>?;
    if (ds == null) return '[NULL]';
    final osVer = ds['os_version'] as String?;
    if (osVer == null || osVer.isEmpty) return '[NULL]';
    // "Android 16 (API 36)" → "Android"
    return osVer.split(' ').first;
  }

  static String _assetOsVersion(Asset asset, DateFormat _) {
    final ds = asset.specifications['device_status'] as Map<String, dynamic>?;
    if (ds == null) return '[NULL]';
    return (ds['os_version'] as String?) ?? '[NULL]';
  }

  static String _assetOsDetail(Asset asset, DateFormat _) {
    final ds = asset.specifications['device_status'] as Map<String, dynamic>?;
    if (ds == null) return '[NULL]';
    return (ds['os_detail_version'] as String?) ?? '[NULL]';
  }

  // ── 접속현황 (Access Status Indicator) ──────────────────────────────────

  static String _assetAccessStatusText(Asset asset, DateFormat _) {
    final lastActive = asset.lastActiveAt;
    if (lastActive == null) return '미접속';
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes <= 60) return '접속중';
    if (diff.inDays <= 31) return '${diff.inDays}일전';
    return '장기미접속';
  }

  /// 접속현황 인디케이터 (Presence 우선 → Heartbeat 기반)
  Widget _accessStatusWidgetWithPresence(Asset asset, BuildContext context) {
    final presenceState = ref.watch(agentPresenceNotifierProvider);
    final isPresenceConnected = presenceState.containsKey(asset.assetUid);

    final lastActive = asset.lastActiveAt;
    Color color;
    String? dayText;

    if (isPresenceConnected) {
      color = Colors.blue;
    } else if (lastActive == null) {
      color = Colors.grey;
    } else {
      final diff = DateTime.now().difference(lastActive);
      if (diff.inMinutes <= 60) {
        color = Colors.green;
      } else if (diff.inDays <= 31) {
        color = Colors.lightGreen;
        dayText = '${diff.inDays}';
      } else {
        color = Colors.red;
      }
    }

    const double size = 16;

    if (dayText != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              dayText,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  static Widget _accessStatusWidget(Asset asset, BuildContext context) {
    final lastActive = asset.lastActiveAt;
    Color color;
    String? dayText;

    if (lastActive == null) {
      color = Colors.grey;
    } else {
      final diff = DateTime.now().difference(lastActive);
      if (diff.inMinutes <= 60) {
        color = Colors.green;
      } else if (diff.inDays <= 31) {
        color = Colors.lightGreen;
        dayText = '${diff.inDays}';
      } else {
        color = Colors.red;
      }
    }

    const double size = 16;

    if (dayText != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            Text(dayText, style: const TextStyle(color: Colors.black, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  // ── 사용자 확인 상태 (Verification Status) ──────────────────────────────

  static String _assetVerificationStatusText(Asset asset, DateFormat _) {
    switch (asset.verificationStatus) {
      case 'verified':
        return '확인완료';
      case 'mismatch':
        return '불일치';
      default:
        return '미확인';
    }
  }

  static Widget _verificationStatusWidget(Asset asset, BuildContext context) {
    final status = asset.verificationStatus;
    if (status == 'verified') {
      return const Icon(Icons.check_circle, color: Colors.green, size: 16);
    } else if (status == 'mismatch') {
      return const Icon(Icons.warning, color: Colors.red, size: 16);
    }
    return const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 16);
  }

  // ── 배정 수령 상태 (Assignment Status) ──────────────────────────────────

  static String _assetAssignmentStatusText(Asset asset, DateFormat _) {
    switch (asset.assignmentStatus) {
      case 'pending':
        return '수령 대기';
      case 'confirmed':
        return '수령 완료';
      default:
        return '';
    }
  }

  static Widget _assignmentStatusWidget(Asset asset, BuildContext context) {
    final status = asset.assignmentStatus;
    if (status == 'pending') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('수령 대기', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    } else if (status == 'confirmed') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text('수령 완료', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
      );
    }
    return const SizedBox.shrink();
  }

  static String _formatStaticDate(DateTime? value, DateFormat dateFormat) {
    if (value == null) return '[NULL]';
    return dateFormat.format(value);
  }

  /// 검색된 전체를 끝까지 fetch한 뒤 CSV로 다운로드.
  Future<void> _downloadCsvAll() async {
    if (!kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV 내보내기는 웹에서만 지원됩니다.')),
        );
      }
      return;
    }
    setState(() => _isExporting = true);
    try {
      while (_hasMore && mounted) {
        await _loadNextPage();
        await Future.delayed(const Duration(milliseconds: 30));
      }
      if (!mounted) return;
      _downloadCsv();
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// 현재 로드된 자산 _assets 기반 CSV 다운로드
  void _downloadCsv() {
    final columns = _visibleColumns;
    final buf = StringBuffer();

    // BOM (엑셀 한글 인코딩)
    buf.write('\uFEFF');

    // 헤더
    buf.writeln(columns.map((c) => _csvEscape(c.label)).join(','));

    // 데이터
    for (final asset in _assets) {
      buf.writeln(
        columns.map((c) => _csvEscape(c.value(asset, _dateTimeFmt))).join(','),
      );
    }

    final now = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'assets_$now.csv';
    if (!kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV 내보내기는 웹에서만 지원됩니다.')),
        );
      }
      return;
    }
    downloadCsv(buf.toString(), filename);
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Widget _buildPagination(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Text(
        '총 ${_assets.length}건',
        style: theme.textTheme.bodyMedium,
      ),
    );
  }
}

class _AssetColumnMeta {
  const _AssetColumnMeta({
    required this.label,
    required this.width,
    required this.value,
    this.widgetBuilder,
  });

  final String label;
  final double width;
  final String Function(Asset asset, DateFormat formatter) value;
  final Widget Function(Asset asset, BuildContext context)? widgetBuilder;
}

// _AssetUidGuideDialog는 widgets/common/asset_uid_guide_dialog.dart로 이동됨

/// 컴팩트 모드에서는 IconButton + Tooltip, 그 외엔 OutlinedButton.icon (또는 filled)로 라벨까지 표시.
class _CompactButton extends StatelessWidget {
  final bool compact;
  final bool filled;
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  const _CompactButton({
    required this.compact,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final btn = IconButton.outlined(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: iconColor),
        tooltip: tooltip,
        style: IconButton.styleFrom(
          minimumSize: const Size(32, 32),
          padding: const EdgeInsets.all(4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
      if (filled) {
        return IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          tooltip: tooltip,
          style: IconButton.styleFrom(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.all(4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
      }
      return btn;
    }
    final style = ButtonStyle(
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      ),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: WidgetStateProperty.all(
        Theme.of(context).textTheme.labelSmall,
      ),
    );
    final iconWidget = Icon(icon, size: 16, color: iconColor);
    final text = Text(label);
    if (filled) {
      return SizedBox(
        height: 32,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: iconWidget,
          label: text,
          style: style,
        ),
      );
    }
    return SizedBox(
      height: 32,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconWidget,
        label: text,
        style: style,
      ),
    );
  }
}

