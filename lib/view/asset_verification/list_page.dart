// lib/view/asset_verification/list_page.dart
import 'package:collection/collection.dart';
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
        final unsynced = provider.unsyncedItems;
        final theme = Theme.of(context);
        if (unsynced.isEmpty) {
          return const AppScaffold(
            title: '미검증 자산',
            selectedIndex: 2,
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Card(
                child: ListTile(
                  leading: Icon(Icons.check_circle, color: Colors.green),
                  title: Text('미검증 자산이 없습니다.'),
                ),
              ),
            ),
          );
        }

        final grouped = unsynced.groupListsBy((inspection) {
          final team = inspection.userTeam?.trim();
          if (team != null && team.isNotEmpty) {
            return team;
          }
          final userId = inspection.userId;
          if (userId != null) {
            final user = provider.userOf(userId);
            if (user != null && user.department.isNotEmpty) {
              return user.department;
            }
          }
          return '미지정 팀';
        });
        final sortedTeams = grouped.keys.toList()
          ..sort((a, b) => a.compareTo(b));

        return AppScaffold(
          title: '미검증 자산',
          selectedIndex: 2,
          body: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: sortedTeams.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final teamName = sortedTeams[index];
              final teamInspections = grouped[teamName]!;
              final List<_InspectionRow> rows = teamInspections
                  .map(
                    (inspection) => _buildRow(
                      inspection: inspection,
                      provider: provider,
                    ),
                  )
                  .toList();
              rows.sort((a, b) {
                final primary = a.sortKey.compareTo(b.sortKey);
                if (primary != 0) {
                  return primary;
                }
                return a.cells[2].compareTo(b.cells[2]);
              });

              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '$teamName (${rows.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingTextStyle: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                          columns: const [
                            DataColumn(label: Text('사용자')),
                            DataColumn(label: Text('장비')),
                            DataColumn(label: Text('자산번호')),
                            DataColumn(label: Text('관리자')),
                            DataColumn(label: Text('위치')),
                            DataColumn(label: Text('인증여부')),
                            DataColumn(label: Text('바코드사진')),
                          ],
                          rows: rows
                              .map(
                                (row) => DataRow(
                                  cells: row.cells
                                      .map((value) => DataCell(Text(value)))
                                      .toList(growable: false),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

typedef _InspectionRow = ({String sortKey, List<String> cells});

_InspectionRow _buildRow({
  required Inspection inspection,
  required InspectionProvider provider,
}) {
  final asset = provider.assetOf(inspection.assetUid);
  final userId = inspection.userId;
  final user = userId != null ? provider.userOf(userId) : null;
  final userName = user?.name ?? '-';
  final assetType = inspection.assetType ?? asset?.assets_types ?? '-';
  final assetCode = inspection.assetUid;
  final manager =
      asset?.metadata['member_name'] ?? asset?.name ?? '-';
  final assetLocation = asset?.location ?? '';
  final location = assetLocation.isEmpty ? '-' : assetLocation;
  final verification = inspection.isVerified == null
      ? '-'
      : inspection.isVerified!
          ? '인증'
          : '미인증';
  final barcodePhoto = inspection.hasBarcodePhoto ? '있음' : '없음';

  return (
    sortKey: userName,
    cells: <String>[
      userName,
      assetType,
      assetCode,
      manager,
      location,
      verification,
      barcodePhoto,
    ],
  );
}
