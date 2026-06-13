import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController _searchController = TextEditingController();

  List<AssetInspection> _inspections = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _error;

  // 라운드
  InspectionRound? _activeRound;
  List<InspectionRound> _allRounds = [];

  // 필터
  String? _selectedStatus;
  String _searchQuery = '';
  List<SearchCondition> _searchConditions = [];

  int get _totalPages => (_totalCount / defaultPageSize).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _loadRounds();
    _loadInspections();
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  Future<void> _loadInspections() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.fetchInspections(
        page: _currentPage,
        pageSize: defaultPageSize,
        status: _selectedStatus,
        search: _searchConditions.isEmpty && _searchQuery.isNotEmpty
            ? _searchQuery
            : null,
        conditions: _searchConditions,
        // 활성 라운드의 미등록(locked=false) 실사만 표시.
        // 활성 라운드가 없으면 일반 동작 (전체 조회).
        roundId: _activeRound?.id,
        onlyUnlocked: _activeRound != null ? true : null,
      );

      setState(() {
        _inspections = result.data;
        _totalCount = result.total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _loadInspections();
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
          // ── 카운터 ──
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 2),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_inspections.length} / 총 ${_totalCount}건',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          // ── 본문 ──
          Expanded(child: _buildBody(context)),
          // ── 페이지네이션 ──
          if (!_isLoading && _error == null && _inspections.isNotEmpty)
            _buildPagination(context),
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
          // 상태 필터
          SizedBox(
            width: 90,
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
              items: const [
                DropdownMenuItem(value: null, child: Text('전체')),
                DropdownMenuItem(value: '완료', child: Text('완료')),
                DropdownMenuItem(value: '미완료', child: Text('미완료')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                  _currentPage = 1;
                });
                _loadInspections();
              },
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
                        _currentPage = 1;
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
                    _currentPage = 1;
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
      _currentPage = 1;
    });
    _loadInspections();
  }

  void _clearSearchConditions() {
    if (_searchConditions.isEmpty) return;
    setState(() {
      _searchConditions = [];
      _currentPage = 1;
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

    final totalWidth = _columnSpecs.fold(0.0, (a, b) => a + b.width);

    return RefreshIndicator(
      onRefresh: _loadInspections,
      child: Scrollbar(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: totalWidth < MediaQuery.of(context).size.width
                ? MediaQuery.of(context).size.width
                : totalWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(theme),
                Divider(
                    height: 1,
                    thickness: 1,
                    color: theme.dividerColor),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    itemCount: _inspections.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.dividerColor.withValues(alpha: 0.4)),
                    itemBuilder: (context, index) =>
                        _buildInspectionRow(context, _inspections[index]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 컬럼 정의 (헤더와 row가 공유)
  static const List<_ColumnSpec> _columnSpecs = [
    _ColumnSpec('상태', 70),
    _ColumnSpec('자산번호', 140),
    _ColumnSpec('실사용자', 100),
    _ColumnSpec('실사용자사번', 110),
    _ColumnSpec('실사용자부서', 130),
    _ColumnSpec('관리자', 90),
    _ColumnSpec('관리자부서', 130),
    _ColumnSpec('유형', 90),
    _ColumnSpec('네트워크', 100),
    _ColumnSpec('일반비고', 160),
    _ColumnSpec('OA비고', 160),
  ];

  Widget _buildHeaderRow(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: _columnSpecs.map((c) {
          return SizedBox(
            width: c.width,
            child: Text(
              c.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 1줄 row — 컬럼: 상태/자산번호/실사용자/실사용자사번/실사용자부서/관리자/관리자부서/유형/네트워크/일반비고/OA비고
  Widget _buildInspectionRow(BuildContext context, AssetInspection ins) {
    final theme = Theme.of(context);
    final isCompleted = ins.completed;
    final widgets = <Widget>[
      _statusBadge(theme, isCompleted),
      Text(
        ins.assetCode ?? 'ID: ${ins.id}',
        style: const TextStyle(fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
      _txt(theme, ins.assetUserName),
      _txt(theme, ins.assetUserEmployeeId),
      _txt(theme, ins.assetUserDepartment),
      _txt(theme, ins.assetAdminName),
      _txt(theme, ins.assetAdminDepartment),
      _txt(theme, ins.assetCategory),
      _txt(theme, ins.assetNetwork),
      _txt(theme, ins.assetNormalComment),
      _txt(theme, ins.assetOaComment),
    ];

    return InkWell(
      onTap: () => context.go('/inspection/${ins.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < _columnSpecs.length; i++)
              SizedBox(width: _columnSpecs[i].width, child: widgets[i]),
          ],
        ),
      ),
    );
  }

  Widget _txt(ThemeData theme, String? value) {
    return Text(
      value?.isNotEmpty == true ? value! : '-',
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall,
    );
  }

  Widget _statusBadge(ThemeData theme, bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isCompleted ? '완료' : '미완료',
        style: TextStyle(
          color: isCompleted ? Colors.green : Colors.orange,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _currentPage > 1
                ? () => _onPageChanged(_currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            '$_currentPage / $_totalPages',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(width: 4),
          Text(
            '(총 $_totalCount건)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _totalPages
                ? () => _onPageChanged(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

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
  const _ColumnSpec(this.label, this.width);
}
