import 'package:flutter/material.dart';

/// 데이터가 없을 때 빈 상태를 표시하는 위젯.
///
/// 아이콘과 안내 메시지를 화면 중앙에 표시한다.
class EmptyStateWidget extends StatelessWidget {
  /// 표시할 아이콘 (기본값: Icons.inbox)
  final IconData icon;

  /// 안내 메시지
  final String message;

  /// 부가 설명 (선택)
  final String? subMessage;

  const EmptyStateWidget({
    super.key,
    this.icon = Icons.inbox,
    required this.message,
    this.subMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (subMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                subMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
