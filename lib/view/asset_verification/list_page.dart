// lib/view/asset_verification/list_page.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetVerificationListPage extends StatefulWidget {
  const AssetVerificationListPage({super.key});

  @override
  State<AssetVerificationListPage> createState() => _AssetVerificationListPageState();
}

class _AssetVerificationListPageState extends State<AssetVerificationListPage> {
  static const _allLabel = '전체';
  static const Map<_TableColumn, double> _columnWidths = {
    _TableColumn.team: 120,
    _TableColumn.user: 140,
    _TableColumn.asset: 160,
    _TableColumn.assetCode: 160,
    _TableColumn.manager: 140,
    _TableColumn.location: 180,
    _TableColumn.verificationStatus: 120,
    _TableColumn.barcodePhoto: 140,
  };
  static const double _tableMinWidth = 1160;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();


  _PrimaryFilterField _selectedPrimaryField = _PrimaryFilterField.team;
  String _selectedPrimaryValue = _allLabel;
  _PrimaryFilterField _appliedPrimaryField = _PrimaryFilterField.team;
  String _appliedPrimaryValue = _allLabel;

  _SecondaryFilterField _selectedSecondaryField = _SecondaryFilterField.verificationStatus;
  _VerificationStatusFilter _selectedVerificationValue = _VerificationStatusFilter.all;
  _BarcodePhotoFilter _selectedBarcodeValue = _BarcodePhotoFilter.all;
  _SecondaryFilterField _appliedSecondaryField = _SecondaryFilterField.verificationStatus;
  _VerificationStatusFilter _appliedVerificationValue = _VerificationStatusFilter.all;
  _BarcodePhotoFilter _appliedBarcodeValue = _BarcodePhotoFilter.all;
  int _currentPage = 0;

  static const _pageSize = 20;

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _onPrimaryFieldChanged(_PrimaryFilterField? value) {
    if (value == null) return;
    setState(() {
      _selectedPrimaryField = value;
      _selectedPrimaryValue = _allLabel;
    });
  }

  void _onPrimaryValueChanged(String? value) {
    if (value == null) return;
    setState(() {
      _selectedPrimaryValue = value;
    });
  }

  void _onSecondaryFieldChanged(_SecondaryFilterField? value) {
    if (value == null) return;
    setState(() {
      _selectedSecondaryField = value;
      if (value == _SecondaryFilterField.verificationStatus) {
        _selectedVerificationValue = _VerificationStatusFilter.all;
      } else {
        _selectedBarcodeValue = _BarcodePhotoFilter.all;
      }
    });
  }

  void _onVerificationValueChanged(_VerificationStatusFilter? value) {
    if (value == null) return;
    setState(() {
      _selectedVerificationValue = value;
    });
  }

  void _onBarcodeValueChanged(_BarcodePhotoFilter? value) {
    if (value == null) return;
    setState(() {
      _selectedBarcodeValue = value;
    });
  }

  void _onSearch() {
    setState(() {
      _appliedPrimaryField = _selectedPrimaryField;
      _appliedPrimaryValue = _selectedPrimaryValue;
      _appliedSecondaryField = _selectedSecondaryField;
      _appliedVerificationValue = _selectedVerificationValue;
      _appliedBarcodeValue = _selectedBarcodeValue;

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
      _selectedPrimaryField = _PrimaryFilterField.team;
      _selectedPrimaryValue = _allLabel;
      _appliedPrimaryField = _PrimaryFilterField.team;
      _appliedPrimaryValue = _allLabel;
      _selectedSecondaryField = _SecondaryFilterField.verificationStatus;
      _selectedVerificationValue = _VerificationStatusFilter.all;
      _selectedBarcodeValue = _BarcodePhotoFilter.all;
      _appliedSecondaryField = _SecondaryFilterField.verificationStatus;
      _appliedVerificationValue = _VerificationStatusFilter.all;
      _appliedBarcodeValue = _BarcodePhotoFilter.all;

      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final rows = _rowsFromProvider(provider);
        final primaryOptions = _primaryOptionsByField(rows);
        final primaryValuesForSelectedField =
            primaryOptions[_selectedPrimaryField] ?? const [_allLabel];
        if (!primaryValuesForSelectedField.contains(_selectedPrimaryValue)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedPrimaryValue = _allLabel;
            });
          });
        }
        final filteredRows = _applyFilters(rows);
        final totalPages = filteredRows.isEmpty ? 0 : (filteredRows.length / _pageSize).ceil();
        final currentPage = totalPages == 0 ? 0 : _currentPage.clamp(0, totalPages - 1).toInt();
        final pageRows = filteredRows.isEmpty
            ? const <_RowData>[]
            : filteredRows.sublist(
                currentPage * _pageSize,
                math.min((currentPage + 1) * _pageSize, filteredRows.length),
              );

        return AppScaffold(
          title: '팀별 자산 인증 현황',
          selectedIndex: 2,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _FilterSection(
                  primaryField: _selectedPrimaryField,
                  primaryValue: _selectedPrimaryValue,
                  primaryValueOptions: primaryOptions,
                  onPrimaryFieldChanged: _onPrimaryFieldChanged,
                  onPrimaryValueChanged: _onPrimaryValueChanged,
                  secondaryField: _selectedSecondaryField,
                  selectedVerificationValue: _selectedVerificationValue,
                  selectedBarcodeValue: _selectedBarcodeValue,
                  onSecondaryFieldChanged: _onSecondaryFieldChanged,
                  onVerificationValueChanged: _onVerificationValueChanged,
                  onBarcodeValueChanged: _onBarcodeValueChanged,
                  onSearch: _onSearch,
                  onFilterReset: _resetFilters,
                  resultCount: filteredRows.length,
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
                                final rows = _buildRows(pageRows);

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
                                            columnSpacing: 32,
                                            horizontalMargin: 0,
                                            headingRowHeight: 44,
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
                                                  columnSpacing: 32,
                                                  horizontalMargin: 0,
                                                  headingRowHeight: 0,
                                                  dataRowMinHeight: 44,
                                                  dataRowMaxHeight: 72,
                                                  showCheckboxColumn: false,
                                                  columns: columns,
                                                  rows: rows,

                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
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

  List<_RowData> _rowsFromProvider(InspectionProvider provider) {
    final rows = provider.items
        .map((inspection) => _RowData.fromInspection(inspection, provider))
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

  Map<_PrimaryFilterField, List<String>> _primaryOptionsByField(List<_RowData> rows) {
    final options = <_PrimaryFilterField, List<String>>{};

    List<String> buildOptions(Iterable<String> values) {
      final unique = values.toSet().toList()
        ..sort((a, b) => a.compareTo(b));
      return [_allLabel, ...unique];
    }

    options[_PrimaryFilterField.team] = buildOptions(rows.map((row) => row.teamName));
    options[_PrimaryFilterField.name] = buildOptions(rows.map((row) => row.userName));
    options[_PrimaryFilterField.assetType] = buildOptions(rows.map((row) => row.assetType));

    return options;
  }

  List<_RowData> _applyFilters(List<_RowData> rows) {
    return rows.where((row) {
      final matchesPrimary = switch (_appliedPrimaryField) {
        _PrimaryFilterField.team =>
            _appliedPrimaryValue == _allLabel || row.teamName == _appliedPrimaryValue,
        _PrimaryFilterField.name =>
            _appliedPrimaryValue == _allLabel || row.userName == _appliedPrimaryValue,
        _PrimaryFilterField.assetType =>
            _appliedPrimaryValue == _allLabel || row.assetType == _appliedPrimaryValue,
      };

      final matchesSecondary = switch (_appliedSecondaryField) {
        _SecondaryFilterField.verificationStatus => switch (_appliedVerificationValue) {
            _VerificationStatusFilter.all => true,
            _VerificationStatusFilter.verified => row.isVerified,
            _VerificationStatusFilter.unverified => !row.isVerified,
          },
        _SecondaryFilterField.barcodePhoto => switch (_appliedBarcodeValue) {
            _BarcodePhotoFilter.all => true,
            _BarcodePhotoFilter.withPhoto => row.hasPhoto,
            _BarcodePhotoFilter.withoutPhoto => !row.hasPhoto,
          },
      };

      return matchesPrimary && matchesSecondary;

    }).toList(growable: false);
  }

  Widget _buildColumnLabel(String label, _TableColumn column) {
    return SizedBox(
      width: _columnWidths[column],
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),

      ),
    );
  }

  Widget _buildTableText(String text, _TableColumn column) {
    return SizedBox(
      width: _columnWidths[column],
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

      ),
    );
  }

  Widget _buildVerificationCell(bool isVerified) {
    return SizedBox(
      width: _columnWidths[_TableColumn.verificationStatus],
      child: Align(
        alignment: Alignment.centerLeft,
        child: _VerificationCell(isVerified: isVerified),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    return [
      DataColumn(
        label: _buildColumnLabel('팀', _TableColumn.team),
      ),
      DataColumn(
        label: _buildColumnLabel('사용자', _TableColumn.user),
      ),
      DataColumn(
        label: _buildColumnLabel('장비', _TableColumn.asset),
      ),
      DataColumn(
        label: _buildColumnLabel('자산번호', _TableColumn.assetCode),
      ),
      DataColumn(
        label: _buildColumnLabel('관리자', _TableColumn.manager),
      ),
      DataColumn(
        label: _buildColumnLabel('위치', _TableColumn.location),
      ),
      DataColumn(
        label: _buildColumnLabel('인증여부', _TableColumn.verificationStatus),
      ),
      DataColumn(
        label: _buildColumnLabel('바코드사진', _TableColumn.barcodePhoto),
      ),
    ];
  }

  List<DataRow> _buildRows(List<_RowData> pageRows) {
    return [
      for (final row in pageRows)
        DataRow(
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
              _buildTableText(
                row.assetCode,
                _TableColumn.assetCode,
              ),
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
                row.hasPhoto ? '사진 있음' : '없음',
                _TableColumn.barcodePhoto,
              ),
            ),
          ],
        ),
    ];
  }
}

enum _PrimaryFilterField { team, name, assetType }

extension on _PrimaryFilterField {
  String get label {
    switch (this) {
      case _PrimaryFilterField.team:
        return '팀';
      case _PrimaryFilterField.name:
        return '이름';
      case _PrimaryFilterField.assetType:
        return '장비';
    }
  }
}

enum _SecondaryFilterField { verificationStatus, barcodePhoto }

extension on _SecondaryFilterField {
  String get label {
    switch (this) {
      case _SecondaryFilterField.verificationStatus:
        return '인증여부';
      case _SecondaryFilterField.barcodePhoto:
        return '바코드 사진';
    }
  }
}

enum _VerificationStatusFilter { all, verified, unverified }

extension on _VerificationStatusFilter {
  String get label {
    switch (this) {
      case _VerificationStatusFilter.all:
        return '전체';
      case _VerificationStatusFilter.verified:
        return '인증 완료';
      case _VerificationStatusFilter.unverified:
        return '미인증';
    }
  }
}

enum _BarcodePhotoFilter { all, withPhoto, withoutPhoto }

extension on _BarcodePhotoFilter {
  String get label {
    switch (this) {
      case _BarcodePhotoFilter.all:
        return '전체';
      case _BarcodePhotoFilter.withPhoto:
        return '사진 있음';
      case _BarcodePhotoFilter.withoutPhoto:
        return '사진 없음';
    }
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

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.primaryField,
    required this.primaryValue,
    required this.primaryValueOptions,
    required this.onPrimaryFieldChanged,
    required this.onPrimaryValueChanged,
    required this.secondaryField,
    required this.selectedVerificationValue,
    required this.selectedBarcodeValue,
    required this.onSecondaryFieldChanged,
    required this.onVerificationValueChanged,
    required this.onBarcodeValueChanged,
    required this.onSearch,
    required this.onFilterReset,
    required this.resultCount,
  });

  final _PrimaryFilterField primaryField;
  final String primaryValue;
  final Map<_PrimaryFilterField, List<String>> primaryValueOptions;
  final ValueChanged<_PrimaryFilterField?> onPrimaryFieldChanged;
  final ValueChanged<String?> onPrimaryValueChanged;
  final _SecondaryFilterField secondaryField;
  final _VerificationStatusFilter selectedVerificationValue;
  final _BarcodePhotoFilter selectedBarcodeValue;
  final ValueChanged<_SecondaryFilterField?> onSecondaryFieldChanged;
  final ValueChanged<_VerificationStatusFilter?> onVerificationValueChanged;
  final ValueChanged<_BarcodePhotoFilter?> onBarcodeValueChanged;
  final VoidCallback onSearch;
  final VoidCallback onFilterReset;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final primaryOptions = primaryValueOptions[primaryField] ?? const ['전체'];
    final adjustedPrimaryValue = primaryOptions.contains(primaryValue) ? primaryValue : primaryOptions.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<_PrimaryFilterField>(
                    value: primaryField,
                    items: _PrimaryFilterField.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onPrimaryFieldChanged,
                    decoration: const InputDecoration(
                      labelText: '검색 항목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: adjustedPrimaryValue,
                    items: primaryOptions
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onPrimaryValueChanged,
                    decoration: const InputDecoration(
                      labelText: '검색 값',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<_SecondaryFilterField>(
                    value: secondaryField,
                    items: _SecondaryFilterField.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onSecondaryFieldChanged,
                    decoration: const InputDecoration(
                      labelText: '상태 항목',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: _SecondaryValueDropdown(
                    field: secondaryField,
                    selectedVerificationValue: selectedVerificationValue,
                    selectedBarcodeValue: selectedBarcodeValue,
                    onVerificationValueChanged: onVerificationValueChanged,
                    onBarcodeValueChanged: onBarcodeValueChanged,

                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('검색 결과: ${resultCount}건'),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                ),
                const SizedBox(width: 12),

                TextButton.icon(
                  onPressed: onFilterReset,
                  icon: const Icon(Icons.refresh),
                  label: const Text('필터 초기화'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryValueDropdown extends StatelessWidget {
  const _SecondaryValueDropdown({
    required this.field,
    required this.selectedVerificationValue,
    required this.selectedBarcodeValue,
    required this.onVerificationValueChanged,
    required this.onBarcodeValueChanged,
  });

  final _SecondaryFilterField field;
  final _VerificationStatusFilter selectedVerificationValue;
  final _BarcodePhotoFilter selectedBarcodeValue;
  final ValueChanged<_VerificationStatusFilter?> onVerificationValueChanged;
  final ValueChanged<_BarcodePhotoFilter?> onBarcodeValueChanged;

  @override
  Widget build(BuildContext context) {
    switch (field) {
      case _SecondaryFilterField.verificationStatus:
        return DropdownButtonFormField<_VerificationStatusFilter>(
          value: selectedVerificationValue,
          items: _VerificationStatusFilter.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(growable: false),
          onChanged: onVerificationValueChanged,
          decoration: const InputDecoration(
            labelText: '상태 값',
            border: OutlineInputBorder(),
          ),
        );
      case _SecondaryFilterField.barcodePhoto:
        return DropdownButtonFormField<_BarcodePhotoFilter>(
          value: selectedBarcodeValue,
          items: _BarcodePhotoFilter.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(growable: false),
          onChanged: onBarcodeValueChanged,
          decoration: const InputDecoration(
            labelText: '상태 값',
            border: OutlineInputBorder(),
          ),
        );
    }
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
  ) {
    final asset = provider.assetOf(inspection.assetUid);
    final user = _resolveUser(provider, inspection, asset);
    final assetType = _resolveAssetType(inspection, asset);
    final manager = _resolveManager(asset);
    final location = _resolveLocation(asset);
    final hasPhoto = _hasBarcodePhoto(inspection, asset);

    return _RowData(
      teamName: _normalizeTeamName(inspection.userTeam),
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

String _normalizeTeamName(String? team) {
  final name = team?.trim();
  if (name == null || name.isEmpty) {
    return '미지정 팀';
  }
  return name;
}

UserInfo? _resolveUser(
  InspectionProvider provider,
  Inspection inspection,
  AssetInfo? asset,
) {
  final candidates = <String?>[
    inspection.userId,
    asset?.metadata['user_id'],
    asset?.metadata['employee_id'],
  ];
  for (final id in candidates) {
    if (id == null) continue;
    final user = provider.userOf(id);
    if (user != null) {
      return user;
    }
  }
  return null;
}

String _resolveAssetType(Inspection inspection, AssetInfo? asset) {
  final fromInspection = inspection.assetType?.trim();
  if (fromInspection != null && fromInspection.isNotEmpty) {
    return fromInspection;
  }
  final fromAsset = asset?.assets_types.trim();
  if (fromAsset != null && fromAsset.isNotEmpty) {
    return fromAsset;
  }
  return '';
}

String _resolveManager(AssetInfo? asset) {
  final manager = asset?.metadata['member_name']?.trim();
  if (manager == null || manager.isEmpty) {
    return '';
  }
  return manager;
}

String _resolveLocation(AssetInfo? asset) {
  if (asset == null) return '';
  final parts = <String?>[
    asset.metadata['building1'],
    asset.metadata['building'],
    asset.metadata['floor'],
  ].whereType<String>().map((value) => value.trim()).where((value) => value.isNotEmpty);
  final joined = parts.join(' ');
  if (joined.isNotEmpty) {
    return joined;
  }
  return asset.location.trim();
}

bool _hasBarcodePhoto(Inspection inspection, AssetInfo? asset) {
  final candidates = <String?>[
    inspection.barcodePhotoUrl,
    asset?.metadata['barcode_photo'],
    asset?.metadata['barcode_photo_url'],
    asset?.metadata['barcodePhoto'],
    asset?.metadata['barcodePhotoUrl'],
  ];
  return candidates.any((value) => value != null && value.trim().isNotEmpty);
}
