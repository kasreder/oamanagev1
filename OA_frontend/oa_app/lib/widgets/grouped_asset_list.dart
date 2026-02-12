import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grouped_list/grouped_list.dart';

import '../models/asset.dart';
import 'common/status_badge.dart';

/// 카테고리별로 그룹화된 자산 리스트 위젯.
///
/// [grouped_list] 패키지를 사용하여 자산을 카테고리별로 묶어 표시한다.
/// 각 행은 asset_uid, name, 상태 뱃지를 보여주며,
/// 행을 탭하면 /asset/:id 경로로 이동한다.
class GroupedAssetList extends StatelessWidget {
  /// 표시할 자산 목록
  final List<Asset> assets;

  const GroupedAssetList({
    super.key,
    required this.assets,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (assets.isEmpty) {
      return Center(
        child: Text(
          '자산이 없습니다.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return GroupedListView<Asset, String>(
      elements: assets,
      groupBy: (asset) => asset.category,
      groupComparator: (a, b) => a.compareTo(b),
      itemComparator: (a, b) => a.assetUid.compareTo(b.assetUid),
      order: GroupedListOrder.ASC,

      // 그룹 헤더
      groupSeparatorBuilder: (String category) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Text(
            category,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        );
      },

      // 자산 행
      itemBuilder: (context, Asset asset) {
        return InkWell(
          onTap: () => context.push('/asset/${asset.id}'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 자산 번호
                SizedBox(
                  width: 120,
                  child: Text(
                    asset.assetUid,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 자산명
                Expanded(
                  child: Text(
                    asset.name ?? '-',
                    style: theme.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),

                // 상태 뱃지
                StatusBadge(status: asset.assetsStatus),
              ],
            ),
          ),
        );
      },

      // 항목 구분선
      separator: const Divider(height: 1),
    );
  }
}
