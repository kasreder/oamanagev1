import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../constants.dart';
import '../main.dart';
import '../models/asset.dart';
import '../theme.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.10 미검증 자산 화면 (/unverified)
///
/// - 실사 완료건이 없는 자산 목록
/// - 필터/검색 지원
/// - 행 클릭 -> /asset/:id
class UnverifiedPage extends ConsumerStatefulWidget {
  const UnverifiedPage({super.key});

  @override
  ConsumerState<UnverifiedPage> createState() => _UnverifiedPageState();
}

class _UnverifiedPageState extends ConsumerState<UnverifiedPage> {
  final TextEditingController _searchController = TextEditingController();

  List<Asset> _assets = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _error;

  // 필터 상태
  String? _selectedCategory;
  String _searchQuery = '';

  int get _totalPages => (_totalCount / defaultPageSize).ceil().clamp(1, 9999);

  @override
  void initState() {
    super.initState();
    _loadUnverifiedAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 미검증 자산 조회
  ///
  /// 실사 완료 건이 없는 자산 = asset_inspections 테이블에 해당 asset_id의
  /// completed 레코드가 없는 자산. Supabase에서는 NOT IN 서브쿼리 대신
  /// RPC 혹은 LEFT JOIN + filter를 사용. 여기서는 직접 쿼리로 구현.
  Future<void> _loadUnverifiedAssets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final from = (_currentPage - 1) * defaultPageSize;
      final to = from + defaultPageSize - 1;

      // 실사 완료된 asset_id 목록을 먼저 조회
      // completed = 5개 필드 모두 NOT NULL인 건
      final completedResult = await supabase
          .from('asset_inspections')
          .select('asset_id')
          .not('inspection_building', 'is', null)
          .not('inspection_floor', 'is', null)
          .not('inspection_position', 'is', null)
          .not('inspection_photo', 'is', null)
          .not('signature_image', 'is', null);

      final completedAssetIds = (completedResult as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['asset_id'] as int?)
          .where((id) => id != null)
          .toSet();

      // 전체 자산 조회 (필터 적용)
      var query = supabase.from('assets').select();

      if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
        query = query.eq('category', _selectedCategory!);
      }
      if (_searchQuery.isNotEmpty) {
        query = query.or(
          'asset_uid.ilike.%$_searchQuery%,'
          'name.ilike.%$_searchQuery%,'
          'user_name.ilike.%$_searchQuery%',
        );
      }

      final response = await query
          .order('id', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final total = response.count;
      final allAssets = response.data
          .map((e) => Asset.fromJson(e))
          .toList();

      // 클라이언트 사이드에서 완료된 자산 필터링
      final unverified = allAssets
          .where((a) => !completedAssetIds.contains(a.id))
          .toList();

      setState(() {
        _assets = unverified;
        // 미검증 자산의 정확한 총 수는 서버 사이드에서 계산이 이상적이지만
        // 클라이언트 필터링이므로 현재 페이지 결과 수를 기준으로 함
        _totalCount = total;
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
    _loadUnverifiedAssets();
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _currentPage = 1;
    });
    _loadUnverifiedAssets();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _loadUnverifiedAssets();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '미검증 자산',
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(child: _buildBody(context)),
          if (!_isLoading && _error == null && _assets.isNotEmpty)
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

          // 검색
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

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '미검증 자산을 조회하는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadUnverifiedAssets);
    }
    if (_assets.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.check_circle_outline,
        message: '미검증 자산이 없습니다.',
        subMessage: '모든 자산의 실사가 완료되었습니다.',
      );
    }

    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadUnverifiedAssets,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _assets.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final asset = _assets[index];
          final statusColor =
              getStatusColor(asset.assetsStatus, brightness);

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            leading: CircleAvatar(
              backgroundColor: Colors.orange.withOpacity(0.15),
              radius: 18,
              child: const Icon(
                Icons.warning_amber,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: Text(
              asset.name ?? asset.assetUid,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${asset.assetUid}  |  ${asset.category}  |  ${asset.userName ?? "-"}',
              style: theme.textTheme.bodySmall,
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
