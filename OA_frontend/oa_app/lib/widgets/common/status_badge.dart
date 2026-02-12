import 'package:flutter/material.dart';

import '../../theme.dart';

/// 자산 상태를 색상 뱃지로 표시하는 위젯.
///
/// 5가지 상태(사용, 가용, 점검필요, 고장, 이동)를 getStatusColor()
/// 함수로 테마에 맞는 색상으로 표시한다.
class StatusBadge extends StatelessWidget {
  /// 자산 상태 문자열 (예: '사용', '가용', '점검필요', '고장', '이동')
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = getStatusColor(status, brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
