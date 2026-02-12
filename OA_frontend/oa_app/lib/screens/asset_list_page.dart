import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../constants.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.3 자산 목록 화면 (/assets)
///
/// - 상단: FilterBar (카테고리, 상태, 검색)
/// - 리스트: 자산번호, 자산명, 카테고리, 상태뱃지
/// - 30건 페이지네이션
/// - 행 클릭 -> /asset/:id
/// - FAB -> /asset/new
class AssetListPage extends ConsumerStatefulWidget {
  const AssetListPage({super.key});

  @override
  ConsumerState<AssetListPage> createState() => _AssetListPageState();
}

class _AssetListPageState extends ConsumerState<AssetListPage> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<Asset> _assets = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _error;

  // 필터 상태
  String? _selectedCategory;
  String? _selectedStatus;
  String _searchQuery = '';

  int get _totalPages => (_totalCount / defaultPageSize).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _api.fetchAssets(
        page: _currentPage,
        pageSize: defaultPageSize,
        category: _selectedCategory,
        status: _selectedStatus,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      setState(() {
        _assets = result.data;
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

  void _onCategoryChanged(String? category) {
    setState(() {
      _selectedCategory = category;
      _currentPage = 1;
    });
    _loadAssets();
  }

  void _onStatusChanged(String? status) {
    setState(() {
      _selectedStatus = status;
      _currentPage = 1;
    });
    _loadAssets();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _loadAssets();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _loadAssets();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '자산 목록',
      currentIndex: 2,
      body: Column(
        children: [
          // ── 필터 바 ──
          _buildFilterBar(context),
          // ── 본문 ──
          Expanded(child: _buildBody(context)),
          // ── 페이지네이션 ──
          if (!_isLoading && _error == null && _assets.isNotEmpty)
            _buildPagination(context),
        ],
      ),
    );
  }

  /// 필터 바 (카테고리, 상태, 검색)
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
          // 카테고리 드롭다운
          SizedBox(
            width: 140,
            child: DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: '카테고리',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(),
              ),
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

          // 상태 드롭다운
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
              items: [
                const DropdownMenuItem(value: null, child: Text('전체')),
                ...assetStatuses.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
              ],
              onChanged: _onStatusChanged,
            ),
          ),

          // 검색 필드
          SizedBox(
            width: 200,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '자산번호/자산명/사용자',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search, size: 20),
                  onPressed: () => _onSearch(_searchController.text),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearch,
            ),
          ),
        ],
      ),
    );
  }

  /// 본문 (로딩/에러/빈상태/목록)
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
        subMessage: '우측 하단 버튼으로 새 자산을 등록하세요.',
      );
    }

    final brightness = Theme.of(context).brightness;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadAssets,
          child: ListView.separated(
            padding: const EdgeInsets.only(
                top: 8, left: 16, right: 16, bottom: 80),
            itemCount: _assets.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final asset = _assets[index];
              final statusColor =
                  getStatusColor(asset.assetsStatus, brightness);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 2),
                title: Text(
                  asset.name ?? asset.assetUid,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${asset.assetUid}  |  ${asset.category}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    asset.assetsStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                onTap: () => context.go('/asset/${asset.id}'),
              );
            },
          ),
        ),

        // ── FAB: 새 자산 등록 ──
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'asset_new',
            onPressed: () => context.go('/asset/new'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  /// 페이지네이션
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
            onPressed:
                _currentPage > 1 ? () => _onPageChanged(_currentPage - 1) : null,
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
