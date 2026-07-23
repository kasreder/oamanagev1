import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../utils/category_icons.dart';

/// 도면 격자의 한 셀(좌석)에 배치된 자산들을 시각화하는 카드.
///
/// - 1행: 대표 사용자명(말줄임). 동일 셀에 다른 user_name 자산이 섞이면 경고 아이콘 + tooltip.
/// - 2행: 등록된 카테고리 아이콘(중복 제거) 최대 3개. 초과 시 "+N" 텍스트.
/// - 우상단: 등록 대수 배지("N대").
class AssetCellCard extends StatelessWidget {
  final List<Asset> assets;
  final VoidCallback? onTap;
  /// 셀 한 변의 layout 픽셀 (격자 크기) — 폰트/아이콘 base 크기 결정
  final double? cellSize;
  /// 뷰어 줌 비율 (InteractiveViewer scale) — 폰트가 raster 확대로 흐려지지
  /// 않도록 layout fontSize를 함께 키운다.
  final double scale;

  const AssetCellCard({
    super.key,
    required this.assets,
    this.onTap,
    this.cellSize,
    this.scale = 1.0,
  });

  /// cellSize의 1/3, 짝수(2의 배수) 단위로 반올림. 최소 2pt.
  /// scale은 InteractiveViewer가 raster로 확대하므로 layout 값엔 반영 안 함.
  double _evenThird() {
    final s = cellSize;
    if (s == null) return 0;
    final n = s / 3;
    final even = (n / 2).round() * 2;
    return even < 2 ? 2 : even.toDouble();
  }

  double _font(double base) {
    final v = _evenThird();
    return v <= 0 ? base : v;
  }

  double _icon(double base) {
    // 아이콘은 글자보다 살짝 큼 — 짝수 단위 유지
    final v = _evenThird();
    if (v <= 0) return base;
    return v + 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (assets.isEmpty) return const SizedBox.shrink();

    // 모바일 판정 — 600px 미만이면 이름만 표시 (카테고리 아이콘/대수 배지 숨김)
    final isMobile = MediaQuery.of(context).size.width < 600;

    // 사용자명 — 첫 자산 기준 + 충돌 검사
    final users = assets
        .map((a) => (a.userName ?? '').trim())
        .where((u) => u.isNotEmpty)
        .toSet();
    final primaryUser = (assets.first.userName ?? '').trim();
    final hasConflict = users.length > 1;

    final container = Container(
      margin: const EdgeInsets.all(1),
      padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 1 : 2, vertical: isMobile ? 1 : 1.5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 0.7,
        ),
      ),
      child: isMobile
          ? _buildMobile(theme, primaryUser, hasConflict, users.length)
          : _buildDesktop(theme, primaryUser, hasConflict, users.length),
    );

    return GestureDetector(onTap: onTap, child: container);
  }

  /// 모바일 — 사용자명만 가운데 정렬 (이름 위주)
  Widget _buildMobile(
      ThemeData theme, String primaryUser, bool hasConflict, int userCount) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              primaryUser.isEmpty ? '·' : primaryUser,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: _font(11),
                fontWeight: FontWeight.w600,
                color: primaryUser.isEmpty
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (hasConflict) ...[
            const SizedBox(width: 1),
            Tooltip(
              message: '충돌: $userCount명',
              child: Icon(Icons.warning_amber,
                  size: _icon(10),
                  color: Colors.orange.shade700),
            ),
          ],
        ],
      ),
    );
  }

  /// 데스크탑 — 사용자명 + 카테고리 아이콘 3개 + 우상단 N대 배지
  Widget _buildDesktop(
      ThemeData theme, String primaryUser, bool hasConflict, int userCount) {
    final categories = assets.map((a) => a.category).toSet().toList();
    final shown = categories.take(3).toList();
    final extraCount = categories.length - shown.length;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    primaryUser.isEmpty ? '미지정' : primaryUser,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _font(11),
                      fontWeight: FontWeight.w600,
                      color: primaryUser.isEmpty
                          ? theme.colorScheme.outline
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (hasConflict)
                  Tooltip(
                    message: '충돌: $userCount명',
                    child: Icon(Icons.warning_amber,
                        size: _icon(12),
                        color: Colors.orange.shade700),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Wrap(
              spacing: 1,
              runSpacing: 0.5,
              children: [
                for (final cat in shown)
                  Icon(
                    iconForCategory(cat),
                    size: _icon(14),
                    color: theme.colorScheme.primary,
                  ),
                if (extraCount > 0)
                  Text(
                    '+$extraCount',
                    style: TextStyle(
                      fontSize: _font(10),
                      color: theme.colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0.5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${assets.length}',
              style: TextStyle(
                fontSize: _font(9),
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
