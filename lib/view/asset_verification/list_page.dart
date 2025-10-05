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
  final TextEditingController _teamController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _assetTypeController = TextEditingController();
  _VerificationStatusFilter _verificationFilter = _VerificationStatusFilter.all;
  _BarcodePhotoFilter _barcodePhotoFilter = _BarcodePhotoFilter.all;
  int _currentPage = 0;

  static const _pageSize = 20;

  @override
  void dispose() {
    _teamController.dispose();
    _nameController.dispose();
    _assetTypeController.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    setState(() {
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
      _teamController.clear();
      _nameController.clear();
      _assetTypeController.clear();
      _verificationFilter = _VerificationStatusFilter.all;
      _barcodePhotoFilter = _BarcodePhotoFilter.all;
      _currentPage = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final filteredRows = _filterRows(provider);
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
                  teamController: _teamController,
                  nameController: _nameController,
                  assetTypeController: _assetTypeController,
                  verificationFilter: _verificationFilter,
                  barcodePhotoFilter: _barcodePhotoFilter,
                  onVerificationFilterChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _verificationFilter = value;
                      _currentPage = 0;
                    });
                  },
                  onBarcodeFilterChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _barcodePhotoFilter = value;
                      _currentPage = 0;
                    });
                  },
                  onFilterReset: _resetFilters,
                  onQueryChanged: _onFilterChanged,
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
                                return Scrollbar(
                                  thumbVisibility: true,
                                  notificationPredicate: (notification) => notification.metrics.axis == Axis.horizontal,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                      child: Scrollbar(
                                        thumbVisibility: true,
                                        notificationPredicate: (notification) => notification.metrics.axis == Axis.vertical,
                                        child: SingleChildScrollView(
                                          child: DataTable(
                                            columnSpacing: 32,
                                            headingRowHeight: 44,
                                            dataRowMinHeight: 44,
                                            dataRowMaxHeight: 72,
                                            columns: const [
                                              DataColumn(label: Text('팀')),
                                              DataColumn(label: Text('사용자')),
                                              DataColumn(label: Text('장비')),
                                              DataColumn(label: Text('자산번호')),
                                              DataColumn(label: Text('관리자')),
                                              DataColumn(label: Text('위치')),
                                              DataColumn(label: Text('인증여부')),
                                              DataColumn(label: Text('바코드사진')),
                                            ],
                                            rows: [
                                              for (final row in pageRows)
                                                DataRow(
                                                  cells: [
                                                    DataCell(Text(row.teamName)),
                                                    DataCell(Text(row.userName)),
                                                    DataCell(Text(row.assetType)),
                                                    DataCell(Text(row.assetCode)),
                                                    DataCell(Text(row.manager)),
                                                    DataCell(Text(row.location)),
                                                    DataCell(
                                                      _VerificationCell(isVerified: row.isVerified),
                                                    ),
                                                    DataCell(Text(row.hasPhoto ? '사진 있음' : '없음')),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
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

  List<_RowData> _filterRows(InspectionProvider provider) {
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

    final teamQuery = _teamController.text.trim().toLowerCase();
    final nameQuery = _nameController.text.trim().toLowerCase();
    final assetTypeQuery = _assetTypeController.text.trim().toLowerCase();

    return rows.where((row) {
      final matchesTeam = teamQuery.isEmpty || row.teamName.toLowerCase().contains(teamQuery);
      final matchesName = nameQuery.isEmpty || row.userName.toLowerCase().contains(nameQuery);
      final matchesAssetType = assetTypeQuery.isEmpty || row.assetType.toLowerCase().contains(assetTypeQuery);
      final matchesVerification = switch (_verificationFilter) {
        _VerificationStatusFilter.all => true,
        _VerificationStatusFilter.verified => row.isVerified,
        _VerificationStatusFilter.unverified => !row.isVerified,
      };
      final matchesBarcode = switch (_barcodePhotoFilter) {
        _BarcodePhotoFilter.all => true,
        _BarcodePhotoFilter.withPhoto => row.hasPhoto,
        _BarcodePhotoFilter.withoutPhoto => !row.hasPhoto,
      };

      return matchesTeam && matchesName && matchesAssetType && matchesVerification && matchesBarcode;
    }).toList(growable: false);
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

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.teamController,
    required this.nameController,
    required this.assetTypeController,
    required this.verificationFilter,
    required this.barcodePhotoFilter,
    required this.onVerificationFilterChanged,
    required this.onBarcodeFilterChanged,
    required this.onFilterReset,
    required this.onQueryChanged,
    required this.resultCount,
  });

  final TextEditingController teamController;
  final TextEditingController nameController;
  final TextEditingController assetTypeController;
  final _VerificationStatusFilter verificationFilter;
  final _BarcodePhotoFilter barcodePhotoFilter;
  final ValueChanged<_VerificationStatusFilter?> onVerificationFilterChanged;
  final ValueChanged<_BarcodePhotoFilter?> onBarcodeFilterChanged;
  final VoidCallback onFilterReset;
  final VoidCallback onQueryChanged;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
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
                  child: TextField(
                    controller: teamController,
                    decoration: const InputDecoration(
                      labelText: '팀',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onQueryChanged(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: '이름',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onQueryChanged(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: assetTypeController,
                    decoration: const InputDecoration(
                      labelText: '장비',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => onQueryChanged(),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<_VerificationStatusFilter>(
                    value: verificationFilter,
                    items: _VerificationStatusFilter.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onVerificationFilterChanged,
                    decoration: const InputDecoration(
                      labelText: '인증여부',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<_BarcodePhotoFilter>(
                    value: barcodePhotoFilter,
                    items: _BarcodePhotoFilter.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: onBarcodeFilterChanged,
                    decoration: const InputDecoration(
                      labelText: '바코드 사진',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('검색 결과: ${resultCount}건'),
                const Spacer(),
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
