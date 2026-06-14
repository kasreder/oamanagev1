import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/asset_inspection.dart';
import '../models/inspection_round.dart';
import '../models/search_condition.dart';
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../widgets/asset_search_dialog.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.4 실사 목록 화면 (/inspections)
class InspectionListPage extends ConsumerStatefulWidget {
  const InspectionListPage({super.key});

  @override
  ConsumerState<InspectionListPage> createState() =>
      _InspectionListPageState();
}

class _InspectionListPageState extends ConsumerState<InspectionListPage> {
  final ApiService _api = ApiService();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  final DateFormat _completeDateFmt = DateFormat('yyyy-MM-dd HH:mm');
  final TextEditingController _searchController = TextEditingController();

  List<AssetInspection> _inspections = [];
  int _totalCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _loadedPage = 0;
  static const int _pageSize = 100; // 자산 목록과 동일
  String? _error;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalBarController = ScrollController();
  bool _syncingScroll = false;

  // 라운드
  InspectionRound? _activeRound;
  List<InspectionRound> _allRounds = [];

  // 필터
  String? _selectedStatus;
  String _searchQuery = '';
  List<SearchCondition> _searchConditions = [];

  // 정렬: null/asc/desc 3단계 cycle
  String? _sortColumnLabel;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _orderedColumns = List<_ColumnSpec>.from(_allColumnSpecs);
    _columnVisibility = {for (final c in _allColumnSpecs) c.label: true};
    _columnWidths = {for (final c in _allColumnSpecs) c.label: c.width};
    _loadColumnConfig();
    _loadRounds();
    _loadInspections();

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
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    _verticalBarController.dispose();
    super.dispose();
  }

  Future<void> _loadRounds() async {
    try {
      final rounds = await _api.fetchRounds();
      final active = await _api.fetchActiveRound();
      if (mounted) {
        setState(() {
          _allRounds = rounds;
          _activeRound = active;
        });
      }
    } catch (_) {}
  }

  /// 처음 로드 또는 필터 변경 시 — 누적 리셋 후 첫 페이지 fetch
  Future<void> _loadInspections() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _inspections = [];
      _loadedPage = 0;
      _hasMore = true;
    });
    await _loadNextPage();
  }

  /// 무한 스크롤로 다음 페이지 누적 fetch
  Future<void> _loadNextPage() async {
    if (!_hasMore || _isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _loadedPage++;

    try {
      // 정렬 — 라벨로 컬럼 찾고 DB 키 매핑
      _ColumnSpec? sortSpec;
      if (_sortColumnLabel != null) {
        sortSpec = _columnSpecs.firstWhere(
          (c) => c.label == _sortColumnLabel,
          orElse: () => _columnSpecs.first,
        );
      }
      final result = await _api.fetchInspections(
        page: _loadedPage,
        pageSize: _pageSize,
        status: _selectedStatus,
        search: _searchConditions.isEmpty && _searchQuery.isNotEmpty
            ? _searchQuery
            : null,
        conditions: _searchConditions,
        roundId: _activeRound?.id,
        onlyUnlocked: _activeRound != null ? true : null,
        orderBy: sortSpec?.dbKey,
        ascending: _sortAscending,
        orderInAssets: sortSpec?.inAssets ?? false,
      );

      setState(() {
        _inspections.addAll(result.data);
        _totalCount = result.total;
        _hasMore = _inspections.length < result.total;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = _inspections.isEmpty ? e.toString() : null;
      });
    }
  }

  bool get _isAdminGroup {
    final authState = ref.read(authNotifierProvider);
    return authState.valueOrNull?.user?.isAdminGroup ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '실사 목록',
      currentIndex: 3,
      actions: _isAdminGroup
          ? [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: '차수 관리',
                onPressed: () => _showRoundManageDialog(context),
              ),
            ]
          : null,
      body: Column(
        children: [
          // ── 활성 라운드 배너 ──
          _buildRoundBanner(context),
          // ── 필터 바 ──
          _buildFilterBar(context),
          _buildAppliedConditionsBar(context),
          // ── 툴바 (열 표시 설정 + 카운터) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openColumnConfigDialog(context),
                  icon: const Icon(Icons.view_column, size: 16),
                  label: const Text('열 표시 설정'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 0),
                    textStyle: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const Spacer(),
                if (!_isLoading)
                  Text(
                    '${_inspections.length} / 총 ${_totalCount}건',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          // ── 본문 (무한 스크롤) ──
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  /// 활성 라운드 배너
  Widget _buildRoundBanner(BuildContext context) {
    final theme = Theme.of(context);

    if (_activeRound != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: Colors.green.withOpacity(0.1),
        child: Row(
          children: [
            const Icon(Icons.play_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_activeRound!.title} (진행중)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_activeRound!.year}년 ${_activeRound!.round}차',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            '진행 중인 실사가 없습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    final theme = Theme.of(context);
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
          // 상태 필터 — Container + DropdownButton (32px 정확)
          Container(
            width: 90,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedStatus,
                hint: Text('상태', style: theme.textTheme.bodySmall),
                isExpanded: true,
                isDense: true,
                icon: const Icon(Icons.arrow_drop_down, size: 16),
                style: theme.textTheme.bodySmall,
                items: const [
                  DropdownMenuItem(value: null, child: Text('전체')),
                  DropdownMenuItem(value: '완료', child: Text('완료')),
                  DropdownMenuItem(value: '미완료', child: Text('미완료')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedStatus = value;
                    _loadedPage = 0;
                  });
                  _loadInspections();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),

          // 검색
          Expanded(
            child: SizedBox(
              height: 32,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '자산번호/담당자',
                  hintStyle: theme.textTheme.bodySmall,
                  isDense: true,
                  contentPadding: dense,
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(maxWidth: 28),
                    onPressed: () {
                      setState(() {
                        _searchQuery = _searchController.text;
                        _loadedPage = 0;
                      });
                      _loadInspections();
                    },
                  ),
                ),
                style: theme.textTheme.bodySmall,
                textInputAction: TextInputAction.search,
                onSubmitted: (query) {
                  setState(() {
                    _searchQuery = query;
                    _loadedPage = 0;
                  });
                  _loadInspections();
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 32,
            child: OutlinedButton.icon(
              onPressed: _openSearchDialog,
              icon: Icon(
                _searchConditions.isEmpty ? Icons.tune : Icons.filter_alt,
                size: 16,
                color: _searchConditions.isEmpty
                    ? null
                    : theme.colorScheme.primary,
              ),
              label: Text(
                _searchConditions.isEmpty
                    ? '고급1검색'
                    : '조건 ${_searchConditions.length}',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: theme.textTheme.labelSmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSearchDialog() async {
    final result = await AssetSearchDialog.show(
      context,
      initial: _searchConditions,
    );
    if (result == null) return;
    setState(() {
      _searchConditions = result;
      _searchQuery = '';
      _searchController.clear();
      _loadedPage = 0;
    });
    _loadInspections();
  }

  void _clearSearchConditions() {
    if (_searchConditions.isEmpty) return;
    setState(() {
      _searchConditions = [];
      _loadedPage = 0;
    });
    _loadInspections();
  }

  /// 적용된 검색 조건 chip 영역
  Widget _buildAppliedConditionsBar(BuildContext context) {
    if (_searchConditions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: theme.colorScheme.surfaceContainerLow,
      child: Row(
        children: [
          Icon(Icons.filter_alt, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _searchConditions.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(width: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: _searchConditions[i].joiner == Joiner.or
                              ? Colors.deepOrange.shade100
                              : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          _searchConditions[i].joiner == Joiner.or
                              ? 'OR'
                              : 'AND',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Chip(
                      label: Text(
                        '${_searchConditions[i].column.label} '
                        '${_searchConditions[i].op == SearchOp.eq ? '=' : '~'} '
                        '"${_searchConditions[i].value}"',
                        style: const TextStyle(fontSize: 11),
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
          TextButton.icon(
            onPressed: _clearSearchConditions,
            icon: const Icon(Icons.close, size: 14),
            label: const Text('초기화'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '실사 목록을 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadInspections);
    }
    if (_inspections.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.fact_check,
        message: '실사 기록이 없습니다.',
      );
    }

    final theme = Theme.of(context);

    final totalWidth =
        _visibleColumns.fold(0.0, (a, b) => a + _getColWidth(b.label));

    return RefreshIndicator(
      onRefresh: _loadInspections,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
        child: Row(
          children: [
            // 메인 — 가로 스크롤
            Expanded(
              child: Scrollbar(
                controller: _horizontalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
                    child: Column(
                      children: [
                        _buildHeaderRow(theme),
                        Expanded(
                          child: ListView.builder(
                            controller: _verticalScrollController,
                            itemCount:
                                _inspections.length + (_isLoadingMore ? 1 : 0),
                            itemExtent: 42,
                            itemBuilder: (context, index) {
                              if (index >= _inspections.length) {
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              }
                              return _buildInspectionRow(
                                  context, _inspections[index]);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 화면 우측 고정 세로 스크롤바
            SizedBox(
              width: 14,
              child: Scrollbar(
                controller: _verticalBarController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalBarController,
                  child: SizedBox(
                    height: _inspections.length * 42.0 + 44,
                    width: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// 컬럼 정의 (헤더와 row가 공유). dbKey=null이면 정렬 비활성.
  static final List<_ColumnSpec> _allColumnSpecs = [
    _ColumnSpec('실사여부', 80,
        builder: (s, ins) =>
            s._statusBadge(Theme.of(s.context), ins.locked)),
    _ColumnSpec('실사완료일', 130, dbKey: 'inspection_date',
        builder: (s, ins) => s._txt(
              Theme.of(s.context),
              ins.inspectionDate != null
                  ? s._completeDateFmt.format(ins.inspectionDate!)
                  : null,
            )),
    _ColumnSpec('사진', 50,
        builder: (s, ins) =>
            s._boolMark(Theme.of(s.context), ins.inspectionPhoto != null)),
    _ColumnSpec('사인', 50,
        builder: (s, ins) =>
            s._boolMark(Theme.of(s.context), ins.signatureImage != null)),
    _ColumnSpec('자산번호', 140, dbKey: 'asset_uid', inAssets: true,
        builder: (s, ins) => Text(
              ins.assetAssetUid ?? ins.assetCode ?? 'ID: ${ins.id}',
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            )),
    _ColumnSpec('실사용자', 100, dbKey: 'user_name', inAssets: true,
        builder: (s, ins) => s._txt(Theme.of(s.context), ins.assetUserName)),
    _ColumnSpec('실사용자사번', 110, dbKey: 'user_employee_id', inAssets: true,
        builder: (s, ins) =>
            s._txt(Theme.of(s.context), ins.assetUserEmployeeId)),
    _ColumnSpec('실사용자부서', 130, dbKey: 'user_department', inAssets: true,
        builder: (s, ins) =>
            s._txt(Theme.of(s.context), ins.assetUserDepartment)),
    _ColumnSpec('관리자', 90, dbKey: 'admin_name', inAssets: true,
        builder: (s, ins) => s._txt(Theme.of(s.context), ins.assetAdminName)),
    _ColumnSpec('관리자부서', 130, dbKey: 'admin_department', inAssets: true,
        builder: (s, ins) =>
            s._txt(Theme.of(s.context), ins.assetAdminDepartment)),
    _ColumnSpec('자산종류', 90, dbKey: 'category', inAssets: true,
        builder: (s, ins) => s._txt(Theme.of(s.context), ins.assetCategory)),
    _ColumnSpec('네트워크', 100, dbKey: 'network', inAssets: true,
        builder: (s, ins) => s._txt(Theme.of(s.context), ins.assetNetwork)),
    _ColumnSpec('일반비고', 160, dbKey: 'normal_comment', inAssets: true,
        builder: (s, ins) =>
            s._txt(Theme.of(s.context), ins.assetNormalComment)),
    _ColumnSpec('OA비고', 160, dbKey: 'oa_comment', inAssets: true,
        builder: (s, ins) => s._txt(Theme.of(s.context), ins.assetOaComment)),
  ];

  // 열표시 상태
  late List<_ColumnSpec> _orderedColumns;
  late Map<String, bool> _columnVisibility;
  late Map<String, double> _columnWidths;
  static const String _columnConfigPrefsKey =
      'inspection_list_column_config_v1';

  List<_ColumnSpec> get _visibleColumns => _orderedColumns
      .where((c) => _columnVisibility[c.label] ?? false)
      .toList();
  double _getColWidth(String label) =>
      _columnWidths[label] ??
      _allColumnSpecs.firstWhere((c) => c.label == label).width;

  /// 기존 코드 호환용 — _visibleColumns alias
  List<_ColumnSpec> get _columnSpecs => _visibleColumns;

  /// 헤더 클릭 — 같은 라벨 누르면 asc → desc → 해제(null) 순환
  void _onSortColumn(_ColumnSpec spec) {
    if (spec.dbKey == null) return;
    setState(() {
      if (_sortColumnLabel == spec.label) {
        if (_sortAscending) {
          _sortAscending = false;            // asc → desc
        } else {
          _sortColumnLabel = null;           // desc → 해제
          _sortAscending = true;
        }
      } else {
        _sortColumnLabel = spec.label;       // 새 컬럼 — asc
        _sortAscending = true;
      }
    });
    _loadInspections();
  }

  // ── 컬럼 설정 저장/로드 ──────────────────────────────────────────────────
  Future<void> _loadColumnConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_columnConfigPrefsKey);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final byLabel = {for (final c in _allColumnSpecs) c.label: c};
      final savedOrder = (json['order'] as List?)?.cast<String>() ?? [];
      final newOrder = <_ColumnSpec>[];
      final seen = <String>{};
      for (final label in savedOrder) {
        final c = byLabel[label];
        if (c != null && !seen.contains(label)) {
          newOrder.add(c);
          seen.add(label);
        }
      }
      for (final c in _allColumnSpecs) {
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
    } catch (_) {/* 기본값 */}
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
    } catch (_) {}
  }

  Future<void> _resetColumnConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_columnConfigPrefsKey);
    } catch (_) {}
    setState(() {
      _orderedColumns = List<_ColumnSpec>.from(_allColumnSpecs);
      _columnVisibility = {for (final c in _allColumnSpecs) c.label: true};
      _columnWidths = {for (final c in _allColumnSpecs) c.label: c.width};
    });
  }

  Future<void> _openColumnConfigDialog(BuildContext context) async {
    final tempOrder = List<_ColumnSpec>.from(_orderedColumns);
    final tempVisibility = Map<String, bool>.from(_columnVisibility);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final visibleCount =
                tempVisibility.values.where((v) => v).length;
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
                    final col = tempOrder[index];
                    final isVisible = tempVisibility[col.label] ?? false;
                    final allowHide = visibleCount > 1 || !isVisible;
                    return ListTile(
                      key: ValueKey(col.label),
                      leading: const Icon(Icons.drag_handle),
                      title: Text(col.label),
                      trailing: Checkbox(
                        value: isVisible,
                        onChanged: allowHide
                            ? (v) {
                                if (v == null) return;
                                setDialogState(() {
                                  tempVisibility[col.label] = v;
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
                          _saveColumnConfig();
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

  Widget _buildHeaderRow(ThemeData theme) {
    final cols = _visibleColumns;
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Row(
        children: cols.map((c) {
          final isActive = _sortColumnLabel == c.label;
          final sortable = c.dbKey != null;
          final isLast = c == cols.last;
          return SizedBox(
            width: _getColWidth(c.label),
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: InkWell(
                    onTap: sortable ? () => _onSortColumn(c) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
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
                              c.label,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color:
                                    isActive ? theme.colorScheme.primary : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sortable) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isActive
                                  ? (_sortAscending
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward)
                                  : Icons.unfold_more,
                              size: 14,
                              color: isActive
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outline,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // 드래그 핸들 (오른쪽 경계) — 마지막 컬럼은 제외
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
                            final cur = _getColWidth(c.label);
                            _columnWidths[c.label] =
                                (cur + details.delta.dx).clamp(50.0, 600.0);
                          });
                        },
                        onHorizontalDragEnd: (_) => _saveColumnConfig(),
                        child: Container(color: Colors.transparent),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 1줄 row — _visibleColumns 순회 + builder 호출
  Widget _buildInspectionRow(BuildContext context, AssetInspection ins) {
    final theme = Theme.of(context);
    final cols = _visibleColumns;
    return InkWell(
      onTap: () => context.go('/inspection/${ins.id}'),
      child: Row(
        children: [
          for (var i = 0; i < cols.length; i++)
            SizedBox(
              width: _getColWidth(cols[i].label),
              height: 42,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: i == cols.length - 1
                        ? BorderSide.none
                        : BorderSide(color: theme.dividerColor),
                    bottom: BorderSide(
                        color: theme.dividerColor.withValues(alpha: 0.55)),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: cols[i].builder != null
                      ? cols[i].builder!(this, ins)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _txt(ThemeData theme, String? value) {
    return Text(
      value ?? '',
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodyMedium,
    );
  }

  Widget _boolMark(ThemeData theme, bool ok) {
    return Text(
      ok ? '○' : 'X',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: ok ? Colors.green : theme.colorScheme.outline,
      ),
    );
  }

  /// 실사여부 뱃지 — 등록(locked=true)이면 "등록완료", 아니면 "미등록"
  Widget _statusBadge(ThemeData theme, bool isRegistered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRegistered
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isRegistered ? '등록완료' : '미등록',
        style: TextStyle(
          color: isRegistered ? Colors.green : Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // _buildPagination 제거: 무한 스크롤로 대체

  // ═══════════════════════════════════════════════════════════════════════
  // 차수 관리 다이얼로그 (관리자 그룹 전용)
  // ═══════════════════════════════════════════════════════════════════════
  Future<void> _showRoundManageDialog(BuildContext context) async {
    await _loadRounds();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (ctx) => _RoundManageDialog(
        rounds: _allRounds,
        activeRound: _activeRound,
        api: _api,
        onChanged: () {
          _loadRounds();
          _loadInspections();
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 차수 관리 다이얼로그
// ═══════════════════════════════════════════════════════════════════════════
class _RoundManageDialog extends StatefulWidget {
  final List<InspectionRound> rounds;
  final InspectionRound? activeRound;
  final ApiService api;
  final VoidCallback onChanged;

  const _RoundManageDialog({
    required this.rounds,
    required this.activeRound,
    required this.api,
    required this.onChanged,
  });

  @override
  State<_RoundManageDialog> createState() => _RoundManageDialogState();
}

class _RoundManageDialogState extends State<_RoundManageDialog> {
  late List<InspectionRound> _rounds;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _rounds = List.from(widget.rounds);
  }

  Future<void> _createRound() async {
    final yearCtrl = TextEditingController(text: '${DateTime.now().year}');
    final roundCtrl = TextEditingController();
    final titleCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 실사 차수 생성'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: yearCtrl,
                    decoration: const InputDecoration(
                      labelText: '년도',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: roundCtrl,
                    decoration: const InputDecoration(
                      labelText: '차수',
                      hintText: '1, 2, 3...',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: '제목',
                hintText: '예: 2026년 1차 실사',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('생성'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final year = int.tryParse(yearCtrl.text);
    final round = int.tryParse(roundCtrl.text);
    final title = titleCtrl.text.trim();

    if (year == null || round == null || title.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('년도, 차수, 제목을 모두 입력하세요.')),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final created = await widget.api.createRound({
        'year': year,
        'round': round,
        'title': title,
      });
      setState(() {
        _rounds.insert(0, created);
      });
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('생성 실패: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _startRound(InspectionRound round) async {
    setState(() => _isProcessing = true);
    try {
      await widget.api.startRound(round.id);
      widget.onChanged();
      // 목록 새로고침
      final rounds = await widget.api.fetchRounds();
      setState(() => _rounds = rounds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('시작 실패: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _closeRound(InspectionRound round) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('실사 종료'),
        content: Text('"${round.title}"을 종료하시겠습니까?\n종료 후 일반 사용자는 실사 수정이 불가합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('종료')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      await widget.api.closeRound(round.id);
      widget.onChanged();
      final rounds = await widget.api.fetchRounds();
      setState(() => _rounds = rounds);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('종료 실패: ${e.toString()}')),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('차수 관리')),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '새 차수 생성',
            onPressed: _isProcessing ? null : _createRound,
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 400,
        child: _rounds.isEmpty
            ? const Center(child: Text('등록된 차수가 없습니다.'))
            : ListView.separated(
                itemCount: _rounds.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final round = _rounds[index];
                  Color statusColor;
                  String statusLabel;
                  switch (round.status) {
                    case 'active':
                      statusColor = Colors.green;
                      statusLabel = '진행중';
                      break;
                    case 'closed':
                      statusColor = Colors.grey;
                      statusLabel = '종료';
                      break;
                    default:
                      statusColor = Colors.blue;
                      statusLabel = '대기';
                  }

                  return ListTile(
                    dense: true,
                    title: Text(round.title),
                    subtitle: Text('${round.year}년 ${round.round}차',
                        style: theme.textTheme.bodySmall),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (round.isDraft)
                          IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Colors.green, size: 20),
                            tooltip: '시작',
                            onPressed:
                                _isProcessing ? null : () => _startRound(round),
                          ),
                        if (round.isActive)
                          IconButton(
                            icon: const Icon(Icons.stop,
                                color: Colors.red, size: 20),
                            tooltip: '종료',
                            onPressed:
                                _isProcessing ? null : () => _closeRound(round),
                          ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

class _ColumnSpec {
  final String label;
  final double width;
  /// DB 컬럼 키 (null이면 정렬 불가)
  final String? dbKey;
  /// true면 assets join 컬럼 (PostgREST embedded order 적용)
  final bool inAssets;
  /// 셀 위젯 빌더 — null이면 row 빌더에서 라벨 매칭으로 처리
  final Widget Function(_InspectionListPageState, AssetInspection)? builder;
  const _ColumnSpec(this.label, this.width,
      {this.dbKey, this.inAssets = false, this.builder});
}
