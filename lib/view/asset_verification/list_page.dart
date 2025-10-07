// lib/view/asset_verification/list_page.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';
import 'verification_utils.dart';

class AssetVerificationListPage extends StatefulWidget {
  const AssetVerificationListPage({super.key});

  @override
  State<AssetVerificationListPage> createState() => _AssetVerificationListPageState();
}

class _AssetVerificationListPageState extends State<AssetVerificationListPage> {
  static const Map<_TableColumn, double> _columnWidths = {
    _TableColumn.team: 100,
    _TableColumn.user: 100,
    _TableColumn.asset: 160,
    _TableColumn.assetCode: 160,
    _TableColumn.manager: 140,
    _TableColumn.location: 180,
    _TableColumn.verificationStatus: 120,
    _TableColumn.barcodePhoto: 140,
  };
  static const Map<_TableColumn, double> _columnSpacing = {
    _TableColumn.team: 1,
    _TableColumn.user: 1,
    _TableColumn.asset: 1,
    _TableColumn.assetCode: 1,
    _TableColumn.manager: 1,
    _TableColumn.location: 1,
    _TableColumn.verificationStatus: 1,
    _TableColumn.barcodePhoto: 1,
  };
  static const double _tableMinWidth = 1160;
  static const double _headerHeight = 48;
  static const double _checkboxHorizontalMargin = 16;
  static const double _checkboxColumnWidth =
      _checkboxHorizontalMargin * 2 + Checkbox.width;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  Set<String> _barcodePhotoAssetCodes = const <String>{};
  Set<String> _selectedAssetCodes = <String>{};

  _TableColumn _selectedSearchColumn = _TableColumn.team;
  String _searchKeyword = '';
  _TableColumn _appliedSearchColumn = _TableColumn.team;
  String _appliedSearchKeyword = '';
  late final TextEditingController _searchController;
  int _currentPage = 0;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _searchKeyword);
    _loadBarcodePhotoAssets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadBarcodePhotoAssets() async {
    final codes = await BarcodePhotoRegistry.loadCodes();
    if (!mounted) return;
    setState(() {
      _barcodePhotoAssetCodes = codes;
    });
  }

  void _onSearchColumnChanged(_TableColumn? value) {
    if (value == null) return;
    setState(() {
      _selectedSearchColumn = value;
    });
  }

  void _onSearchKeywordChanged(String value) {
    setState(() {
      _searchKeyword = value;
    });
  }

  void _onSearch() {
    final keyword = _searchController.text;
    setState(() {
      _searchKeyword = keyword;
      _appliedSearchColumn = _selectedSearchColumn;
      _appliedSearchKeyword = keyword.trim();

      _currentPage = 0;
    });
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedSearchColumn = _TableColumn.team;
      _appliedSearchColumn = _TableColumn.team;
      _searchKeyword = '';
      _appliedSearchKeyword = '';
      _searchController.text = '';

      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final rows = _rowsFromProvider(provider);
        final filteredRows = _applyFilters(rows);
        final visibleAssetCodes = filteredRows.map((row) => row.assetCode).toSet();
        if (_selectedAssetCodes.difference(visibleAssetCodes).isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedAssetCodes = _selectedAssetCodes
                  .where((code) => visibleAssetCodes.contains(code))
                  .toSet();
            });
          });
        }
        final totalPages = filteredRows.isEmpty ? 0 : (filteredRows.length / _pageSize).ceil();
        final currentPage = totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1).toInt();
        final pageRows = filteredRows.isEmpty
            ? const <_RowData>[]
            : filteredRows.sublist(
                currentPage * _pageSize,
                math.min((currentPage + 1) * _pageSize, filteredRows.length),
              );
        final selectedCount = _selectedAssetCodes.length;

        return AppScaffold(
          title: '팀별 자산 인증 현황',
          selectedIndex: 2,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FilterSection(
                  selectedColumn: _selectedSearchColumn,
                  onColumnChanged: _onSearchColumnChanged,
                  searchController: _searchController,
                  onKeywordChanged: _onSearchKeywordChanged,
                  onSearch: _onSearch,
                  onFilterReset: _resetFilters,
                  resultCount: filteredRows.length,
                  selectedCount: selectedCount,
                  onVerifySelected: () => _onVerifySelected(context, filteredRows),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredRows.isEmpty
                      ? const Center(child: Text('표시할 자산 실사 이력이 없습니다.'))
                      : Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = math.max(
                                  constraints.maxWidth,
                                  _tableMinWidth,
                                );
                                final columns = _buildColumns();
                                final rows = _buildRows(context, pageRows);

                                return Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) =>
                                      notification.metrics.axis == Axis.horizontal,
                                  child: SingleChildScrollView(
                                    controller: _horizontalScrollController,
                                    scrollDirection: Axis.horizontal,
                                    child: SizedBox(
                                      width: tableWidth,
                                      height: constraints.maxHeight,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildTableHeader(pageRows),

                                          const Divider(height: 0),
                                          Expanded(
                                            child: Scrollbar(
                                              controller: _verticalScrollController,
                                              thumbVisibility: true,
                                              child: SingleChildScrollView(
                                                controller: _verticalScrollController,
                                                child: DataTable(
                                                  columnSpacing: 0,
                                                  horizontalMargin: 0,
                                                  checkboxHorizontalMargin: 16,
                                                  headingRowHeight: 0,
                                                  dataRowMinHeight: 20,
                                                  dataRowMaxHeight: 40,
                                                  showCheckboxColumn: true,
                                                  columns: columns,
                                                  rows: rows,

                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ),
                                ),
                                );
                              },
                            ),
                          ),
                        ),
                ),
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _PaginationControls(
                      totalPages: totalPages,
                      currentPage: currentPage,
                      onPageSelected: _onPageChanged,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _toggleSelection(String assetCode, bool isSelected) {
    setState(() {
      final updated = _selectedAssetCodes.toSet();
      if (isSelected) {
        updated.add(assetCode);
      } else {
        updated.remove(assetCode);
      }
      _selectedAssetCodes = updated;
    });
  }

  void _onVerifySelected(BuildContext context, List<_RowData> filteredRows) {
    final availableCodes = filteredRows.map((row) => row.assetCode).toSet();
    final selected = _selectedAssetCodes.where(availableCodes.contains).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선택된 자산이 없습니다.')),
      );
      return;
    }

    if (selected.length == 1) {
      final assetCode = selected.first;
      context.push('/asset_verification/${Uri.encodeComponent(assetCode)}');
      return;
    }

    final joined = selected.map(Uri.encodeComponent).join(',');
    context.push('/asset_verification_group?assetUids=$joined');
  }

  List<_RowData> _rowsFromProvider(InspectionProvider provider) {
    final rows = provider.items
        .map(
          (inspection) => _RowData.fromInspection(
            inspection,
            provider,
            _barcodePhotoAssetCodes,
          ),
        )
        .toList(growable: false);

    rows.sort((a, b) {
      final teamComparison = a.teamName.compareTo(b.teamName);
      if (teamComparison != 0) {
        if (a.teamName == '미지정 팀') {
          return 1;
        }
        if (b.teamName == '미지정 팀') {
          return -1;
        }
        return teamComparison;
      }
      return a.assetCode.compareTo(b.assetCode);
    });

    return rows;
  }

  List<_RowData> _applyFilters(List<_RowData> rows) {
    final keyword = _appliedSearchKeyword.trim().toLowerCase();
    if (keyword.isEmpty) {
      return rows;
    }

    return rows
        .where((row) {
          final value = _valueForColumn(row, _appliedSearchColumn).toLowerCase();
          return value.contains(keyword);
        })
        .toList(growable: false);
  }

  String _valueForColumn(_RowData row, _TableColumn column) {
    switch (column) {
      case _TableColumn.team:
        return row.teamName;
      case _TableColumn.user:
        return row.userName;
      case _TableColumn.asset:
        return row.assetType;
      case _TableColumn.assetCode:
        return row.assetCode;
      case _TableColumn.manager:
        return row.manager;
      case _TableColumn.location:
        return row.location;
      case _TableColumn.verificationStatus:
        return row.isVerified ? '완료' : '미인증';
      case _TableColumn.barcodePhoto:
        return row.hasPhoto ? '사진 있음' : '사진 없음';
    }
  }

  Widget _buildTableText(String text, _TableColumn column) {
    return _buildCellContainer(
      column,
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildVerificationCell(bool isVerified) {
    return _buildCellContainer(
      _TableColumn.verificationStatus,
      child: _VerificationCell(isVerified: isVerified),
    );
  }

  Widget _buildCellContainer(
    _TableColumn column, {
    required Widget child,
  }) {
    final spacing = _columnSpacing[column] ?? 0;
    final width = _columnWidths[column];
    return Padding(
      padding: EdgeInsets.only(right: spacing),
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerLeft,
          child: child,
        ),
      ),
    );
  }

  Widget _headerCell(
    String label,
    _TableColumn column,
    TextStyle? style,
  ) {
    final effectiveStyle = style == null
        ? const TextStyle(fontWeight: FontWeight.w600)
        : style.copyWith(fontWeight: FontWeight.w600);
    return _buildCellContainer(
      column,
      child: Text(
        label,
        style: effectiveStyle,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _teamHeaderCell(TextStyle? style) =>
      _headerCell('팀', _TableColumn.team, style);

  Widget _userHeaderCell(TextStyle? style) =>
      _headerCell('사용자', _TableColumn.user, style);

  Widget _assetHeaderCell(TextStyle? style) =>
      _headerCell('장비', _TableColumn.asset, style);

  Widget _assetCodeHeaderCell(TextStyle? style) =>
      _headerCell('자산번호', _TableColumn.assetCode, style);

  Widget _managerHeaderCell(TextStyle? style) =>
      _headerCell('관리자', _TableColumn.manager, style);

  Widget _locationHeaderCell(TextStyle? style) =>
      _headerCell('위치', _TableColumn.location, style);

  Widget _verificationHeaderCell(TextStyle? style) =>
      _headerCell('인증여부', _TableColumn.verificationStatus, style);

  Widget _barcodePhotoHeaderCell(TextStyle? style) =>
      _headerCell('바코드사진', _TableColumn.barcodePhoto, style);

  Widget _buildTableHeader(List<_RowData> pageRows) {
    final theme = Theme.of(context);
    final dataTableTheme = DataTableTheme.of(context);
    final headerColor =
        dataTableTheme.headingRowColor?.resolve(const <MaterialState>{}) ??
            theme.colorScheme.surface;
    final headerHeight =
        dataTableTheme.headingRowHeight ?? _headerHeight;
    final headerStyle =
        dataTableTheme.headingTextStyle ?? theme.textTheme.labelLarge;

    final headerCells = <Widget>[
      _teamHeaderCell(headerStyle),
      _userHeaderCell(headerStyle),
      _assetHeaderCell(headerStyle),
      _assetCodeHeaderCell(headerStyle),
      _managerHeaderCell(headerStyle),
      _locationHeaderCell(headerStyle),
      _verificationHeaderCell(headerStyle),
      _barcodePhotoHeaderCell(headerStyle),
    ];

    final selectedOnPage = pageRows
        .where((row) => _selectedAssetCodes.contains(row.assetCode))
        .length;
    final hasRows = pageRows.isNotEmpty;
    final allSelected = hasRows && selectedOnPage == pageRows.length;
    final anySelected = selectedOnPage > 0;
    final bool? checkboxValue = !hasRows
        ? false
        : allSelected
            ? true
            : anySelected
                ? null
                : false;

    return Material(
      color: headerColor,
      child: SizedBox(
        height: headerHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _checkboxColumnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _checkboxHorizontalMargin,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Checkbox(
                    value: checkboxValue,

                    tristate: hasRows,
                    onChanged: hasRows
                        ? (value) =>
                            _onHeaderCheckboxChanged(pageRows, value ?? false)
                        : null,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ),
            ...headerCells,
          ],
        ),
      ),
    );
  }

  void _onHeaderCheckboxChanged(List<_RowData> pageRows, bool shouldSelectAll) {
    setState(() {
      if (shouldSelectAll) {
        _selectedAssetCodes = pageRows.map((r) => r.assetCode).toSet();
      } else {
        _selectedAssetCodes.clear();
      }
    });
  }

  List<DataColumn> _buildColumns() {
    final theme = Theme.of(context);
    final headerStyle =
        DataTableTheme.of(context).headingTextStyle ?? theme.textTheme.labelLarge;
    return [
      DataColumn(
        label: _teamHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _userHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _assetHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _assetCodeHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _managerHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _locationHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _verificationHeaderCell(headerStyle),
      ),
      DataColumn(
        label: _barcodePhotoHeaderCell(headerStyle),
      ),
    ];
  }

  List<DataRow> _buildRows(BuildContext context, List<_RowData> pageRows) {
    return [
      for (final row in pageRows)
        DataRow(
          selected: _selectedAssetCodes.contains(row.assetCode),
          onSelectChanged: (selected) {
            _toggleSelection(row.assetCode, selected ?? false);
          },
          cells: [
            DataCell(
              _buildTableText(
                row.teamName,
                _TableColumn.team,
              ),
            ),
            DataCell(
              _buildTableText(
                row.userName,
                _TableColumn.user,
              ),
            ),
            DataCell(
              _buildTableText(
                row.assetType,
                _TableColumn.asset,
              ),
            ),
            DataCell(
              _buildAssetCodeCell(context, row.assetCode),
            ),
            DataCell(
              _buildTableText(
                row.manager,
                _TableColumn.manager,
              ),
            ),
            DataCell(
              _buildTableText(
                row.location,
                _TableColumn.location,
              ),
            ),
            DataCell(
              _buildVerificationCell(row.isVerified),
            ),
            DataCell(
              _buildTableText(
                row.hasPhoto ? '사진 있음' : '사진 없음',
                _TableColumn.barcodePhoto,
              ),
            ),
          ],
        ),
    ];
  }

  Widget _buildAssetCodeCell(BuildContext context, String assetCode) {
    return InkWell(
      onTap: () {
        context.push('/asset_verification/${Uri.encodeComponent(assetCode)}');
      },
      child: _buildTableText(
        assetCode,
        _TableColumn.assetCode,
      ),
    );
  }
}

enum _TableColumn {
  team,
  user,
  asset,
  assetCode,
  manager,
  location,
  verificationStatus,
  barcodePhoto,
}

extension on _TableColumn {
  String get label {
    switch (this) {
      case _TableColumn.team:
        return '팀';
      case _TableColumn.user:
        return '사용자';
      case _TableColumn.asset:
        return '장비';
      case _TableColumn.assetCode:
        return '자산번호';
      case _TableColumn.manager:
        return '관리자';
      case _TableColumn.location:
        return '위치';
      case _TableColumn.verificationStatus:
        return '인증여부';
      case _TableColumn.barcodePhoto:
        return '바코드사진';
    }
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.selectedColumn,
    required this.onColumnChanged,
    required this.searchController,
    required this.onKeywordChanged,
    required this.onSearch,
    required this.onFilterReset,
    required this.resultCount,
    required this.selectedCount,
    required this.onVerifySelected,
  });

  final _TableColumn selectedColumn;
  final ValueChanged<_TableColumn?> onColumnChanged;
  final TextEditingController searchController;
  final ValueChanged<String> onKeywordChanged;
  final VoidCallback onSearch;
  final VoidCallback onFilterReset;
  final int resultCount;
  final int selectedCount;
  final VoidCallback onVerifySelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: DropdownButtonFormField<_TableColumn>(
                    value: selectedColumn,
                    items: _TableColumn.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onColumnChanged,
                    decoration: const InputDecoration(
                      labelText: '항목',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.zero,
                    ),
                    isDense: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: onKeywordChanged,
                    onSubmitted: (_) => onSearch(),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      labelText: '검색명',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: onFilterReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('초기화'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('검색 결과: ${resultCount}건'),
                const SizedBox(width: 16),
                Text('선택: ${selectedCount}건'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: selectedCount > 0 ? onVerifySelected : null,
                  icon: const Icon(Icons.verified),
                  label: const Text('인증하기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationCell extends StatelessWidget {
  const _VerificationCell({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    if (isVerified) {
      return const Text(
        '완료',
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
      );
    }
    return TextButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('인증 기능이 준비 중입니다.'),
          ),
        );
      },
      child: const Text('인증하기'),
    );
  }
}

class _PaginationControls extends StatelessWidget {
  const _PaginationControls({
    required this.totalPages,
    required this.currentPage,
    required this.onPageSelected,
  });

  final int totalPages;
  final int currentPage;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.chevron_left),
        onPressed: currentPage > 0 ? () => onPageSelected(currentPage - 1) : null,
      ),
      ..._pageNumberWidgets(context),
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.chevron_right),
        onPressed: currentPage < totalPages - 1 ? () => onPageSelected(currentPage + 1) : null,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons,
    );
  }

  List<Widget> _pageNumberWidgets(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pages = _visiblePageNumbers();

    return pages
        .map(
          (page) => page == null
              ? const Padding(
                  padding: EdgeInsets.zero,
                  child: Text('...'),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextButton(
                    onPressed: page == currentPage ? null : () => onPageSelected(page),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '${page + 1}',
                      style: page == currentPage
                          ? textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )
                          : null,
                    ),
                  ),
                ),
        )
        .toList(growable: false);
  }

  List<int?> _visiblePageNumbers() {
    const maxDisplay = 3;
    if (totalPages <= maxDisplay) {
      return List<int>.generate(totalPages, (index) => index);
    }

    final pages = <int?>[];
    pages.add(0);

    if (currentPage > 3) {
      pages.add(null);
    }

    final start = currentPage <= 3 ? 1 : currentPage - 1;
    final end = currentPage >= totalPages - 4 ? totalPages - 2 : currentPage + 1;

    for (var page = start; page <= end; page++) {
      if (page > 0 && page < totalPages - 1) {
        pages.add(page);
      }
    }

    if (currentPage < totalPages - 4) {
      pages.add(null);
    }

    pages.add(totalPages - 1);

    return pages;
  }
}

class _RowData {
  _RowData({
    required this.teamName,
    required this.assetCode,
    required this.userName,
    required this.assetType,
    required this.manager,
    required this.location,
    required this.isVerified,
    required this.hasPhoto,
  });

  final String teamName;
  final String assetCode;
  final String userName;
  final String assetType;
  final String manager;
  final String location;
  final bool isVerified;
  final bool hasPhoto;

  factory _RowData.fromInspection(
    Inspection inspection,
    InspectionProvider provider,
    Set<String> availableBarcodePhotos,
  ) {
    final asset = provider.assetOf(inspection.assetUid);
    final user = resolveUser(provider, inspection, asset);
    final assetType = resolveAssetType(inspection, asset);
    final manager = resolveManager(asset);
    final location = resolveLocation(asset);
    final normalizedCode = inspection.assetUid.trim().toLowerCase();
    final hasPhoto = normalizedCode.isNotEmpty && availableBarcodePhotos.contains(normalizedCode);

    return _RowData(
      teamName: normalizeTeamName(inspection.userTeam),
      assetCode: inspection.assetUid,
      userName: user?.name ?? '정보 없음',
      assetType: assetType.isNotEmpty ? assetType : '정보 없음',
      manager: manager.isNotEmpty ? manager : '정보 없음',
      location: location.isNotEmpty ? location : '정보 없음',
      isVerified: inspection.isVerified,
      hasPhoto: hasPhoto,
    );
  }
}
