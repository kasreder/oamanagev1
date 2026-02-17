import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../constants.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.3 자산 목록 화면 (/assets)
///
/// - 상단: FilterBar (카테고리, 상태, 검색)
/// - 컬럼을 선택/순서 변경 가능한 표 형태 자산 목록
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
  final ScrollController _horizontalScrollController = ScrollController();
  final DateFormat _dateTimeFmt = DateFormat('yyyy-MM-dd HH:mm');

  List<Asset> _assets = [];
  int _totalCount = 0;
  int _currentPage = 1;
  bool _isLoading = true;
  String? _error;

  // 필터 상태
  String? _selectedCategory;
  String? _selectedStatus;
  String _searchQuery = '';

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
    _AssetColumnMeta(label: '소유자', width: _colOwnerName, value: _assetOwnerName),
    _AssetColumnMeta(label: '소유부서', width: _colOwnerDept, value: _assetOwnerDepartment),
    _AssetColumnMeta(label: '사용자', width: _colUserName, value: _assetUserName),
    _AssetColumnMeta(label: '접속현황', width: _colAccessStatus, value: _assetAccessStatusText, widgetBuilder: _accessStatusWidget),
    _AssetColumnMeta(label: '사용부서', width: _colUserDept, value: _assetUserDepartment),
    _AssetColumnMeta(label: '관리자', width: _colAdminName, value: _assetAdminName),
    _AssetColumnMeta(label: '관리부서', width: _colAdminDept, value: _assetAdminDepartment),
    _AssetColumnMeta(label: '도면ID', width: _colLocationDrawingId, value: _assetLocationDrawingId),
    _AssetColumnMeta(label: '위치(행)', width: _colLocationRow, value: _assetLocationRow),
    _AssetColumnMeta(label: '위치(열)', width: _colLocationCol, value: _assetLocationCol),
    _AssetColumnMeta(label: '도면파일', width: _colLocationFile, value: _assetLocationDrawingFile),
    _AssetColumnMeta(label: '등록자ID', width: _colUserId, value: _assetUserId),
    _AssetColumnMeta(label: '등록일', width: _colCreatedAt, value: _assetCreatedAt),
    _AssetColumnMeta(label: '수정일', width: _colUpdatedAt, value: _assetUpdatedAt),
  ];

  late List<_AssetColumnMeta> _orderedColumns;
  late Map<String, bool> _columnVisibility;

  int get _totalPages => (_totalCount / defaultPageSize).ceil().clamp(1, 9999);

  List<_AssetColumnMeta> get _visibleColumns => _orderedColumns
      .where((column) => _columnVisibility[column.label] ?? false)
      .toList();

  double get _tableWidth =>
      _visibleColumns.fold(0.0, (sum, column) => sum + column.width);

  @override
  void initState() {
    super.initState();
    _orderedColumns = List<_AssetColumnMeta>.from(_allColumns);
    _columnVisibility = {for (final column in _allColumns) column.label: true};
    _loadAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
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
          _buildFilterBar(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openColumnConfigDialog(context),
                icon: const Icon(Icons.view_column, size: 18),
                label: const Text('열 표시 설정'),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
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

          // 검색 입력 필드
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
        subMessage: '우측 하단 버튼으로 새 자산을 등록하세요.',
      );
    }

    final theme = Theme.of(context);

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Scrollbar(
            controller: _horizontalScrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: _tableWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      children: [
                        // ── 헤더 (고정) ──
                        _buildTableHeader(context),
                        // ── 본문 행 (세로 스크롤) ──
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _loadAssets,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 80),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < _assets.length; i++)
                                    _buildTableRow(
                                      context: context,
                                      asset: _assets[i],
                                      rowIndex: i,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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

  Widget _buildTableHeader(BuildContext context) {
    final theme = Theme.of(context);
    final columns = _visibleColumns;

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++)
            _buildHeaderCell(
              columns[i].label,
              columns[i].width,
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
                  columns[i].width,
                  context,
                  isLast: i == columns.length - 1,
                )
              else
                _buildBodyCell(
                  columns[i].value(asset, _dateTimeFmt),
                  columns[i].width,
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
                ElevatedButton(
                  onPressed: visibleCount > 0
                      ? () {
                          setState(() {
                            _orderedColumns = tempOrder;
                            _columnVisibility = tempVisibility;
                          });
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

  Widget _buildHeaderCell(
    String label,
    double width,
    BuildContext context, {
    bool isLast = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          right:
              isLast ? BorderSide.none : BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
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

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right:
              isLast ? BorderSide.none : BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
        ),
      ),
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyMedium,
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

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          right:
              isLast ? BorderSide.none : BorderSide(color: theme.dividerColor),
          bottom: BorderSide(color: theme.dividerColor.withOpacity(0.55)),
        ),
      ),
      child: Center(child: child),
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

  // ── 접속현황 (Access Status Indicator) ──────────────────────────────────

  static String _assetAccessStatusText(Asset asset, DateFormat _) {
    final lastActive = asset.lastActiveAt;
    if (lastActive == null) return '미접속';
    final diff = DateTime.now().difference(lastActive);
    if (diff.inMinutes <= 60) return '접속중';
    if (diff.inDays <= 31) return '${diff.inDays}일전';
    return '장기미접속';
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
                color: Colors.white,
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

  static String _formatStaticDate(DateTime? value, DateFormat dateFormat) {
    if (value == null) return '[NULL]';
    return dateFormat.format(value);
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
