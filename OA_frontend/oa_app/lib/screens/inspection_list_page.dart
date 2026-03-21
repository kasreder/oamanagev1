import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/asset_inspection.dart';
import '../models/inspection_round.dart';
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
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
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            width: 100,
            height: 36,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: '상태',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
          const SizedBox(width: 8),

          // 검색
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '자산번호/담당자',
                  hintStyle: theme.textTheme.bodySmall,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(maxWidth: 32),
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

    return RefreshIndicator(
      onRefresh: _loadInspections,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _inspections.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final inspection = _inspections[index];
          final isCompleted = inspection.completed;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            leading: CircleAvatar(
              backgroundColor: isCompleted
                  ? Colors.green.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              radius: 18,
              child: Icon(
                isCompleted ? Icons.check_circle : Icons.pending,
                color: isCompleted ? Colors.green : Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              inspection.assetCode ?? 'ID: ${inspection.id}',
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${inspection.inspectorName ?? "-"}  |  ${inspection.inspectionDate != null ? _dateFmt.format(inspection.inspectionDate!) : "-"}  |  ${inspection.inspectionCount}회차',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted
                    ? Colors.green.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCompleted ? '완료' : '미완료',
                style: TextStyle(
                  color: isCompleted ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            onTap: () => context.go('/inspection/${inspection.id}'),
          );
        },
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
