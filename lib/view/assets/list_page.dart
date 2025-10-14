// lib/view/assets/list.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

// 자산 목록 화면을 정의하는 StatefulWidget입니다.
class AssetsListPage extends StatefulWidget {
  const AssetsListPage({super.key});

  @override
  State<AssetsListPage> createState() => _AssetsListPageState();
}

enum _AssetSearchField { assetUid, name, assets_types, modelName, organizationTeam }

extension on _AssetSearchField {
  String get label {
    switch (this) {
      case _AssetSearchField.assetUid:
        return '자산번호';
      case _AssetSearchField.name:
        return '사용자';
      case _AssetSearchField.assets_types:
        return '장비종류';
      case _AssetSearchField.modelName:
        return '모델명';
      case _AssetSearchField.organizationTeam:
        return '소속팀';
    }
  }
}

// 자산 목록 화면의 상태를 관리합니다.
class _AssetsListPageState extends State<AssetsListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  static const double _tableMinWidth = 1200; // 테이블이 답답해 보이지 않도록 최소 너비를 지정합니다.
  static const EdgeInsets _cellPadding = EdgeInsets.symmetric(horizontal: 1, vertical: 1);
  static const double _defaultColumnWidth = 60;
  static const double _70ColumnWidth = 70;
  static const double _80ColumnWidth = 80;
  static const double _120ColumnWidth = 120 ;
  static const double _200ColumnWidth = 200;
  _AssetSearchField _searchField = _AssetSearchField.name;
  int _currentPage = 0;

  @override
  void dispose() {
    // 컨트롤러 사용이 끝나면 메모리 누수를 막기 위해 정리합니다.
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 실시간으로 Provider 데이터를 구독하며 화면을 갱신합니다.
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final filteredRows = _filterRows(provider);
        const pageSize = 20;
        final totalPages = filteredRows.isEmpty ? 0 : (filteredRows.length / pageSize).ceil();
        final currentPage = totalPages == 0 ? 0 : (_currentPage.clamp(0, totalPages - 1)).toInt();
        final pageRows = filteredRows.isEmpty
            ? const <_AssetRowData>[]
            : filteredRows.sublist(
                currentPage * pageSize,
                math.min((currentPage + 1) * pageSize, filteredRows.length),
              );
        final totalCount = provider.onlyUnsynced ? provider.unsyncedCount : provider.totalCount;
        return AppScaffold(
          title: '자산 목록',
          selectedIndex: 1,
          body: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
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
                const SizedBox(height: 1),
                Expanded(
                  child: filteredRows.isEmpty
                      ? const Center(child: Text('표시할 실사 내역이 없습니다.'))
                      : Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: LayoutBuilder(
                              builder: (context, constraints) {
                                final tableWidth = math.max(
                                  constraints.maxWidth,
                                  _tableMinWidth,
                                );
                                final columns = _buildColumns(context);
                                return Scrollbar(
                                  controller: _horizontalScrollController,
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
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
                                            headingRowColor: WidgetStateProperty.resolveWith(
                                              (states) => Theme.of(context).colorScheme.surfaceContainerHighest,),
                                            columnSpacing: 0,
                                            horizontalMargin: 0,
                                            headingRowHeight: 40,
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
                                                  showCheckboxColumn: false,
                                                  // ✅ 기본 체크박스 삭제
                                                  headingRowHeight: 0,
                                                  columnSpacing: 0,
                                                  // 컬럼 간 간격을 제거합니다.
                                                  horizontalMargin: 0,
                                                  dataRowMinHeight: 0,
                                                  dataRowMaxHeight: 40,
                                                  columns: columns,
                                                  rows: pageRows
                                                      .map(
                                                        (row) => DataRow(
                                                          onSelectChanged: (_) => context.go('/assets/${row.inspection.id}'),
                                                          cells: [
                                                            DataCell(Padding(
                                                              padding: const EdgeInsets.all(8.0),
                                                              child: _cellText(row.inspection.assetUid),
                                                            )),
                                                            DataCell(_cellText(row.asset?.name ?? '-')),
                                                            DataCell(_cellText(row.asset?.assets_types ?? '-')),
                                                            DataCell(_cellText120(row.asset?.model ?? '-')),
                                                            DataCell(_cellText(row.inspection.status)),
                                                            DataCell(_cellText(_resolveOrganization(row.asset, row.inspection))),
                                                            DataCell(_cellText200(row.asset?.location ?? '-')),
                                                            DataCell(
                                                              _cellText200(
                                                                _formattedMemo(row.inspection.memo),
                                                                maxLines: 2,
                                                              ),
                                                            ),
                                                            // DataCell(
                                                            //   Padding(
                                                            //     padding: _cellPadding,
                                                            //     child: SizedBox(
                                                            //       width: _actionColumnWidth,
                                                            //       child: Align(
                                                            //         alignment:
                                                            //         Alignment.centerLeft,
                                                            //         child: IconButton(
                                                            //           tooltip: '삭제',
                                                            //           icon: const Icon(
                                                            //             Icons
                                                            //                 .delete_outline,
                                                            //           ),
                                                            //           color: Theme.of(context)
                                                            //               .colorScheme
                                                            //               .error,
                                                            //           onPressed: () async {
                                                            //             final confirmed =
                                                            //             await _confirmDelete(
                                                            //                 context);
                                                            //             if (!mounted ||
                                                            //                 !confirmed) {
                                                            //               return;
                                                            //             }
                                                            //             provider.remove(
                                                            //                 row.inspection.id);
                                                            //             if (!mounted) {
                                                            //               return;
                                                            //             }
                                                            //             ScaffoldMessenger
                                                            //                 .of(context)
                                                            //                 .showSnackBar(
                                                            //               SnackBar(
                                                            //                 content: Text(
                                                            //                   '${row.inspection.assetUid} 삭제됨',
                                                            //                 ),
                                                            //               ),
                                                            //             );
                                                            //           },
                                                            //         ),
                                                            //       ),
                                                            //     ),
                                                            //   ),
                                                            // ),
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
                      ),
                ),
                if (totalPages > 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
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
          ),
        );
      },
    );
  }

  // 검색어와 필터 조건을 반영해 표시할 행 데이터를 만듭니다.
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

  // 데이터 테이블에 사용할 컬럼 정의를 생성합니다.
  List<DataColumn> _buildColumns(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge; // 헤더는 기본 크기를 유지해 가독성을 확보합니다.
    return [
      DataColumn(
        label: Padding(
          padding: const EdgeInsets.all(8.0),
          child: _headerCell('자산번호', headerStyle),
        ),
      ),
      DataColumn(label: _headerCell('사용자', headerStyle),),
      DataColumn(label: _headerCell('장비종류', headerStyle),),
      DataColumn(label: _headerCel120('모델명', headerStyle),),
      DataColumn(label: _headerCell('상태', headerStyle),),
      DataColumn(label: _headerCell('소속팀', headerStyle),),
      DataColumn(label: _headerCell200('위치', headerStyle),),
      DataColumn(label: _headerCell200('메모', headerStyle),),
      // DataColumn(
      //   label: _headerCell(
      //     '작업',
      //     headerStyle,
      //     width: _actionColumnWidth,
      //   ),
      // ),
    ];
  }

  // 일반 텍스트 헤더 셀을 생성합니다.
  TextStyle _resolveHeaderStyle(TextStyle? baseStyle) {
    return baseStyle == null
        ? const TextStyle(fontWeight: FontWeight.w600)
        : baseStyle.copyWith(fontWeight: FontWeight.w600);
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
            style: _resolveHeaderStyle(style),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _headerCel120(
      String label,
      TextStyle? style, {
        double width = _120ColumnWidth,
      }) {
    return Padding(
      padding: _cellPadding,
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: _resolveHeaderStyle(style),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // 메모 전용으로 넓이를 확장한 헤더 셀입니다.
  Widget _headerCell200(
    //메모
    String label,
    TextStyle? style, {
    double width = _200ColumnWidth,
  }) {
    return Padding(
      padding: _cellPadding,
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: _resolveHeaderStyle(style),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  // 자산 또는 실사 정보에서 소속팀 정보를 우선순위에 맞춰 결정합니다.
  String _resolveOrganization(AssetInfo? asset, Inspection inspection) {
    final assetOrganization = asset?.organization;
    if (assetOrganization != null && assetOrganization.trim().isNotEmpty) {
      return assetOrganization;
    }

    final inspectionTeam = inspection.userTeam;
    if (inspectionTeam != null && inspectionTeam.trim().isNotEmpty) {
      return inspectionTeam;
    }

    return '-';
  }

  // 선택된 검색 필드에 맞춰 검색어 일치 여부를 판단합니다.
  bool _matchesQuery(Inspection inspection, AssetInfo? asset, String query) {
    switch (_searchField) {
      case _AssetSearchField.assetUid:
        final target = inspection.assetUid;
        return target.toLowerCase().contains(query);
      case _AssetSearchField.name:
        final target = asset?.name ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.assets_types:
        final target = asset?.assets_types ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.modelName:
        final target = asset?.model ?? '';
        return target.toLowerCase().contains(query);
      case _AssetSearchField.organizationTeam:
        final organization = _resolveOrganization(asset, inspection);
        return organization.toLowerCase().contains(query);
    }
  }

  // 기본 폭의 셀 텍스트 위젯을 생성합니다.
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

  Widget _cellText120(
      String value, {
        int maxLines = 1,
        double width = _120ColumnWidth,
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

  // 메모 표시를 위해 폭을 넓힌 셀 텍스트 위젯입니다.
  Widget _cellText200(
    //메모
    String value, {
    int maxLines = 1,
    double width = _200ColumnWidth,
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

  // 메모 텍스트에서 줄바꿈을 정리하고 비어있을 때 대시로 표시합니다.
  String _formattedMemo(String? memo) {
    final normalized = memo?.replaceAll('\n', ' ').trim() ?? '';
    if (normalized.isEmpty) {
      return '-';
    }
    return normalized;
  }

  // 행 삭제 시 사용자에게 확인을 요청하는 다이얼로그를 띄웁니다.
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
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
                      labelText: '구분',
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
                Text('검색 결과: '),

                Text(
                  filteredCount == totalCount ? '$filteredCount건' : '$filteredCount건 / 총 ${totalCount}건',
                ),
                const Spacer(),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: SizedBox(
                        width: 60,
                        child: Center(child: Text('전체')),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: SizedBox(
                        width: 60,
                        child: Center(child: Text('미동기화')),
                      ),
                    ),
                  ],
                  selected: <bool>{provider.onlyUnsynced},
                  onSelectionChanged: (value) {
                    onFilterReset();
                    provider.setOnlyUnsynced(value.first);
                  },
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetRowData {
  const _AssetRowData({required this.inspection, required this.asset});

  final Inspection inspection;
  final AssetInfo? asset;
}

// 페이지네이션 버튼 UI를 담당하는 위젯입니다.
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
    // 이전/다음 버튼과 페이지 숫자를 배열합니다.
    final buttons = <Widget>[
      IconButton(
        padding: EdgeInsets.zero, // 내부 여백 제거
        constraints: const BoxConstraints(), // 최소 크기 제약 제거
        icon: const Icon(Icons.chevron_left),
        onPressed: currentPage > 0 ? () => onPageSelected(currentPage - 1) : null,
      ),
      ..._pageNumberWidgets(context),
      IconButton(
        padding: EdgeInsets.zero, // 내부 여백 제거
        constraints: const BoxConstraints(), // 최소 크기 제약 제거
        icon: const Icon(Icons.chevron_right),
        onPressed: currentPage < totalPages - 1 ? () => onPageSelected(currentPage + 1) : null,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: buttons,
    );
  }

  // 현재 페이지를 기준으로 표시할 페이지 버튼 목록을 만듭니다.
  List<Widget> _pageNumberWidgets(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pages = _visiblePageNumbers();

    return pages
        .map(
          (page) => page == null
              ? const Padding(
                  padding: EdgeInsets.zero, // 내부 여백 제거,
                  child: Text('...'),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10), // 페이지 번호 사이 여백을 최소로 유지해 버튼 간격을 조절합니다.
                  // padding: EdgeInsets.zero, // 내부 여백 제거
                  child: TextButton(
                    onPressed: page == currentPage ? null : () => onPageSelected(page),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), // 살짝만 여유
                      minimumSize: const Size(0, 0), // 기본 88x36 제약 해제
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap, // 터치 영역을 버튼 크기만큼만
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

  // 페이지 수가 많을 때 가독성을 위한 범위를 계산합니다.
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
