// lib/view/asset_verification/list_page.dart

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetVerificationListPage extends StatelessWidget {
  const AssetVerificationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final inspections = provider.items;
        if (inspections.isEmpty) {
          return AppScaffold(
            title: '팀별 자산 인증 현황',
            selectedIndex: 2,
            body: const Center(
              child: Text('표시할 자산 실사 이력이 없습니다.'),
            ),
          );
        }

        final grouped = SplayTreeMap<String, List<_RowData>>((a, b) {
          if (a == b) return 0;
          if (a == '미지정 팀') return 1;
          if (b == '미지정 팀') return -1;
          return a.compareTo(b);
        });

        for (final inspection in inspections) {
          final row = _RowData.fromInspection(inspection, provider);
          grouped.putIfAbsent(row.teamName, () => <_RowData>[]).add(row);
        }

        return AppScaffold(
          title: '팀별 자산 인증 현황',
          selectedIndex: 2,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in grouped.entries)
                _TeamSection(
                  teamName: entry.key,
                  rows: entry.value,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({
    required this.teamName,
    required this.rows,
  });

  final String teamName;
  final List<_RowData> rows;

  @override
  Widget build(BuildContext context) {
    final sortedRows = List<_RowData>.from(rows)
      ..sort((a, b) => a.assetCode.compareTo(b.assetCode));
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                teamName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DataTable(
                columnSpacing: 32,
                headingRowHeight: 44,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 72,
                columns: const [
                  DataColumn(label: Text('사용자')),
                  DataColumn(label: Text('장비')),
                  DataColumn(label: Text('자산번호')),
                  DataColumn(label: Text('관리자')),
                  DataColumn(label: Text('위치')),
                  DataColumn(label: Text('인증여부')),
                  DataColumn(label: Text('바코드사진')),
                ],
                rows: [
                  for (final row in sortedRows)
                    DataRow(
                      cells: [
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
