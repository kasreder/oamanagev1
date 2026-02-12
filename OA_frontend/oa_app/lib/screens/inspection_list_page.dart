import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/asset_inspection.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.4 실사 목록 화면 (/inspections)
///
/// - 리스트: 자산번호, 담당자, 실사일, 완료여부
/// - 30건 페이지네이션
/// - 행 클릭 -> /inspection/:id
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

  // 필터
  String? _selectedStatus;
  String _searchQuery = '';

  int get _totalPages => (_totalCount / defaultPageSize).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _loadInspections();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '실사 목록',
      currentIndex: 3,
      body: Column(
        children: [
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
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 상태 필터
          SizedBox(
            width: 120,
            child: DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: '상태',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
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

          // 검색
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '자산번호/담당자',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () {
                    setState(() {
                      _searchQuery = _searchController.text;
                      _currentPage = 1;
                    });
                    _loadInspections();
                  },
                ),
              ),
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
              '${inspection.inspectorName ?? "-"}  |  ${inspection.inspectionDate != null ? _dateFmt.format(inspection.inspectionDate!) : "-"}',
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
}
