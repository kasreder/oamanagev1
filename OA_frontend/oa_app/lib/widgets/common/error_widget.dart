import 'package:flutter/material.dart';

/// 에러 상태를 표시하는 공통 위젯.
///
/// 에러 메시지와 재시도 버튼을 화면 중앙에 배치한다.
class AppErrorWidget extends StatelessWidget {
  /// 표시할 에러 메시지
  final String message;

  /// 재시도 버튼 콜백 (null이면 버튼 숨김)
  final VoidCallback? onRetry;

  const AppErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
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
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('재시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
