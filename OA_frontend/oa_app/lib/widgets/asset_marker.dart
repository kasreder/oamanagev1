import 'package:flutter/material.dart';

import '../models/asset.dart';
import '../models/drawing.dart';
import '../theme.dart';

/// 도면 위에 자산 위치를 표시하는 마커 위젯.
///
/// [Positioned] 위젯으로 격자 좌표(gridRow, gridCol)에 배치되며,
/// 원형 마커를 상태별 색상([getStatusColor])으로 표시한다.
/// 탭 시 자산 정보를 Tooltip 또는 Dialog로 보여준다.
class AssetMarker extends StatelessWidget {
  /// 표시할 자산 정보
  final Asset asset;

  /// 격자 행 위치 (0-based)
  final int gridRow;

  /// 격자 열 위치 (0-based)
  final int gridCol;

  /// 마커 탭 콜백
  final VoidCallback? onTap;

  /// 마커 크기 (지름)
  final double size;

  const AssetMarker({
    super.key,
    required this.asset,
    required this.gridRow,
    required this.gridCol,
    this.onTap,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = getStatusColor(asset.assetsStatus, brightness);
    final label = Drawing.getGridLabel(gridRow, gridCol);

    return Tooltip(
      richMessage: TextSpan(
        children: [
          TextSpan(
            text: '${asset.assetUid}\n',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (asset.name != null)
            TextSpan(text: '${asset.name}\n'),
          TextSpan(text: '상태: ${asset.assetsStatus}\n'),
          TextSpan(text: '위치: $label'),
        ],
      ),
      child: GestureDetector(
        onTap: onTap ?? () => _showAssetInfo(context, color, label),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.85),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              asset.category.isNotEmpty ? asset.category[0] : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 자산 정보를 다이얼로그로 표시
  void _showAssetInfo(BuildContext context, Color color, String label) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                asset.assetUid,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('자산명', asset.name ?? '-'),
            _infoRow('카테고리', asset.category),
            _infoRow('상태', asset.assetsStatus),
            _infoRow('위치', label),
            if (asset.building != null)
              _infoRow('건물', asset.building!),
            if (asset.floor != null)
              _infoRow('층', asset.floor!),
            if (asset.userName != null)
              _infoRow('사용자', asset.userName!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  /// 정보 행 빌더
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
