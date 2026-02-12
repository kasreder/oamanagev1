import 'package:flutter/material.dart';

/// 로딩 상태를 표시하는 공통 위젯.
///
/// CircularProgressIndicator를 화면 중앙에 배치한다.
class LoadingWidget extends StatelessWidget {
  /// 로딩 인디케이터 아래에 표시할 선택적 메시지
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}
