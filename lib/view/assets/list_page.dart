// lib/view/assets/list.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetsListPage extends StatefulWidget {
  const AssetsListPage({super.key});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

enum _AssetSearchField { name, category, modelName, organizationTeam }

extension on _AssetSearchField {
  String get label {
    switch (this) {
      case _AssetSearchField.name:
        return '자산명';
      case _AssetSearchField.category:
        return '카테고리';
      case _AssetSearchField.modelName:
        return '모델명';
      case _AssetSearchField.organizationTeam:
        return '소속팀';
    }
  }
}

class _AssetsListPageState extends State<AssetsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  static const double _tableMinWidth =
  1100; // 테이블이 답답해 보이지 않도록 최소 너비를 지정합니다.
  static const EdgeInsets _cellPadding =
  EdgeInsets.symmetric(horizontal: 12, vertical: 10);
  static const double _defaultColumnWidth = 200;
  static const double _iconColumnWidth = 88;
  static const double _actionColumnWidth = 104;
  _AssetSearchField _searchField = _AssetSearchField.name;
  int _currentPage = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final filteredRows = _filterRows(provider);
        const pageSize = 20;
        final totalPages =
        filteredRows.isEmpty ? 0 : (filteredRows.length / pageSize).ceil();
        final currentPage = totalPages == 0
            ? 0
            : (_currentPage.clamp(0, totalPages - 1)).toInt();
        final pageRows = filteredRows.isEmpty
            ? const <_AssetRowData>[]
            : filteredRows.sublist(
          currentPage * pageSize,
          math.min((currentPage + 1) * pageSize, filteredRows.length),
        );
        final totalCount = provider.onlyUnsynced
            ? provider.unsyncedCount
            : provider.totalCount;
        return AppScaffold(
          title: '실사 목록',
          selectedIndex: 1,
          body: Column(
            children: [
              _FilterSection(
                searchController: _searchController,
                searchField: _searchField,
                onSearchFieldChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _searchField = value;
                    _currentPage = 0;
                  });
                },
                onQueryChanged: (_) => setState(() {
                  _currentPage = 0;
                }),
                provider: provider,
                filteredCount: filteredRows.length,
                totalCount: totalCount,
                onFilterReset: () {
                  setState(() {
                    _currentPage = 0;
                  });
                },
              ),
              Expanded(
                child: filteredRows.isEmpty
                    ? const Center(child: Text('표시할 실사 내역이 없습니다.'))
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final tableWidth = math.max(
                      constraints.maxWidth,
                      _tableMinWidth,
                    );
                    final columns = _buildColumns(context);
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
                              DataTable(
                                headingRowColor:
                                WidgetStateProperty.resolveWith(
                                      (states) => Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                columnSpacing: 0,
                                horizontalMargin: 0,
                                headingRowHeight: 48,
                                dataRowMinHeight: 0,
                                dataRowMaxHeight: 0,
                                columns: columns,
                                rows: const [],
                              ),
                              const Divider(height: 0),
                              Expanded(
                                child: Scrollbar(
                                  controller: _verticalScrollController,
                                  thumbVisibility: true,
                                  child: SingleChildScrollView(
                                    controller: _verticalScrollController,
                                    child: DataTable(
                                      showCheckboxColumn: false, // ✅ 기본 체크박스 삭제
                                      headingRowHeight: 0,
                                      columnSpacing: 0, // 컬럼 간 간격을 제거합니다.
                                      horizontalMargin: 0,
                                      columns: columns,
                                      rows: pageRows
                                          .map(
                                            (row) => DataRow(
                                          onSelectChanged: (_) =>
                                              context.go(
                                                  '/assets/${row.inspection.id}'),
                                          cells: [
                                            DataCell(_cellText(
                                                row.inspection.assetUid)),
                                            DataCell(_cellText(
                                                row.asset?.name ?? '-')),
                                            DataCell(_cellText(
                                                row.asset?.category ?? '-')),
                                            DataCell(_cellText(
                                                row.asset?.model ?? '-')),
                                            DataCell(_cellText(
                                                row.inspection.status)),
                                            DataCell(_cellText(
                                                row.inspection.userTeam ?? '-')),
                                            DataCell(_cellText(
                                                row.asset?.location ?? '-')),
                                            DataCell(
                                              _cellText(
                                                provider.formatDateTime(
                                                  row.inspection.scannedAt,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: _cellPadding,
                                                child: SizedBox(
                                                  width: _iconColumnWidth,
                                                  child: Align(
                                                    alignment:
                                                    Alignment.centerLeft,
                                                    child: Icon(
                                                      row.inspection.synced
                                                          ? Icons.cloud_done
                                                          : Icons.cloud_off,
                                                      size: 18,
                                                      color: row.inspection.synced
                                                          ? Colors.green
                                                          : Colors.orange,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              _cellText(
                                                _formattedMemo(
                                                    row.inspection.memo),
                                                maxLines: 2,
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: _cellPadding,
                                                child: SizedBox(
                                                  width: _actionColumnWidth,
                                                  child: Align(
                                                    alignment:
                                                    Alignment.centerLeft,
                                                    child: IconButton(
                                                      tooltip: '삭제',
                                                      icon: const Icon(
                                                        Icons
                                                            .delete_outline,
                                                      ),
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .error,
                                                      onPressed: () async {
                                                        final confirmed =
                                                        await _confirmDelete(
                                                            context);
                                                        if (!mounted ||
                                                            !confirmed) {
                                                          return;
                                                        }
                                                        provider.remove(
                                                            row.inspection.id);
                                                        if (!mounted) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger
                                                            .of(context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              '${row.inspection.assetUid} 삭제됨',
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                          .toList(),
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
              if (totalPages > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _PaginationControls(
                    totalPages: totalPages,
                    currentPage: currentPage,
                    onPageSelected: (page) {
                      setState(() {
                        _currentPage = page;
                      });
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<_AssetRowData> _filterRows(InspectionProvider provider) {
    final query = _searchController.text.trim().toLowerCase();
    final items = provider.items;
    if (query.isEmpty) {
      return items
          .map(
            (inspection) => _AssetRowData(
          inspection: inspection,
          asset: provider.assetOf(inspection.assetUid),
        ),
      )
          .toList(growable: false);
    }

    final matches = <_AssetRowData>[];
    for (final inspection in items) {
      final asset = provider.assetOf(inspection.assetUid);
      if (_matchesQuery(inspection, asset, query)) {
        matches.add(_AssetRowData(inspection: inspection, asset: asset));
      }
    }
    return matches;
  }

  List<DataColumn> _buildColumns(BuildContext context) {
    final headerStyle = Theme.of(context)
        .textTheme
        .labelLarge; // 헤더는 기본 크기를 유지해 가독성을 확보합니다.
    return [
      DataColumn(
        label: _headerCell('자산번호', headerStyle),
      ),
      DataColumn(
        label: _headerCell('자산명', headerStyle),
      ),
      DataColumn(
        label: _headerCell('카테고리', headerStyle),
      ),
      DataColumn(
        label: _headerCell('모델명', headerStyle),
      ),
      DataColumn(
        label: _headerCell('상태', headerStyle),
      ),
      DataColumn(
        label: _headerCell('소속팀', headerStyle),
      ),
      DataColumn(
        label: _headerCell('위치', headerStyle),
      ),
      DataColumn(
        label: _headerCell('스캔일시', headerStyle),
      ),
      DataColumn(
        label: _headerCell(
          '동기화',
          headerStyle,
          width: _iconColumnWidth,
        ),
      ),
      DataColumn(
        label: _headerCell('메모', headerStyle),
      ),
      DataColumn(
        label: _headerCell(
          '작업',
          headerStyle,
          width: _actionColumnWidth,
        ),
      ),
    ];
  }

  Widget _headerCell(
      String label,
      TextStyle? style, {
        double width = _defaultColumnWidth,
      }) {
    return Padding(
      padding: _cellPadding,
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  bool _matchesQuery(Inspection inspection, AssetInfo? asset, String query) {
    switch (_searchField) {
      case _AssetSearchField.name:
        final target = asset?.name ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.category:
        final target = asset?.category ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.modelName:
        final target = asset?.model ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.organizationTeam:
        final target = inspection.userTeam ?? '';
        return target.toLowerCase().contains(query);
    }
  }

  Widget _cellText(
      String value, {
        int maxLines = 1,
        double width = _defaultColumnWidth,
      }) {
    final textStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 13,
    ); // 본문 글꼴 크기를 살짝 줄여 테이블을 더 촘촘하게 보여줍니다.
    return Padding(
      padding: _cellPadding,
      child: SizedBox(
        width: width,
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        ),
      ),
    );
  }

  String _formattedMemo(String? memo) {
    final normalized = memo?.replaceAll('\n', ' ').trim() ?? '';
    if (normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('선택한 실사를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    ) ??
        false;
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.searchController,
    required this.searchField,
    required this.onSearchFieldChanged,
    required this.onQueryChanged,
    required this.provider,
    required this.filteredCount,
    required this.totalCount,
    required this.onFilterReset,
  });

  final TextEditingController searchController;
  final _AssetSearchField searchField;
  final ValueChanged<_AssetSearchField?> onSearchFieldChanged;
  final ValueChanged<String> onQueryChanged;
  final InspectionProvider provider;
  final int filteredCount;
  final int totalCount;
  final VoidCallback onFilterReset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: '검색어',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: onQueryChanged,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<_AssetSearchField>(
                  value: searchField,
                  decoration: const InputDecoration(
                    labelText: '검색 종류',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _AssetSearchField.values
                      .map(
                        (field) => DropdownMenuItem<_AssetSearchField>(
                      value: field,
                      child: Text(field.label),
                    ),
                  )
                      .toList(),
                  onChanged: onSearchFieldChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('전체')),
                  ButtonSegment<bool>(value: true, label: Text('미동기화')),
                ],
                selected: <bool>{provider.onlyUnsynced},
                onSelectionChanged: (value) {
                  onFilterReset();
                  provider.setOnlyUnsynced(value.first);
                },
              ),
              const Spacer(),
              Text(
                filteredCount == totalCount
                    ? '$filteredCount건'
                    : '$filteredCount건 / 총 ${totalCount}건',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AssetRowData {
  const _AssetRowData({required this.inspection, required this.asset});

  final Inspection inspection;
  final AssetInfo? asset;
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
        icon: const Icon(Icons.chevron_left),
        onPressed:
        currentPage > 0 ? () => onPageSelected(currentPage - 1) : null,
      ),
      ..._pageNumberWidgets(context),
      IconButton(
        icon: const Icon(Icons.chevron_right),
        onPressed: currentPage < totalPages - 1
            ? () => onPageSelected(currentPage + 1)
            : null,
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
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: Text('...'),
      )
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: TextButton(
          onPressed: page == currentPage
              ? null
              : () => onPageSelected(page),
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
    const maxDisplay = 7;
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