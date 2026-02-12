import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 페이지네이션 컨트롤 위젯.
///
/// << < 1 2 3 ... > >> 형태의 페이지 네비게이션을 제공한다.
/// Supabase Range 헤더 기반 30건 단위 페이지네이션에 대응.
class PaginationWidget extends StatelessWidget {
  /// 현재 페이지 (1-based)
  final int currentPage;

  /// 전체 페이지 수
  final int totalPages;

  /// 페이지 변경 콜백
  final ValueChanged<int> onPageChanged;

  /// 표시할 최대 페이지 버튼 수 (기본 5)
  final int maxVisiblePages;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
    this.maxVisiblePages = 5,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final pages = _buildPageNumbers();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // << 처음 페이지
          _NavButton(
            label: '<<',
            onPressed: currentPage > 1 ? () => onPageChanged(1) : null,
          ),
          const SizedBox(width: 4),

          // < 이전 페이지
          _NavButton(
            label: '<',
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),
          const SizedBox(width: 8),

          // 페이지 번호 버튼들
          ...pages.map((page) {
            if (page == -1) {
              // 생략 부호 (...)
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...'),
              );
            }

            final isActive = page == currentPage;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: isActive
                  ? FilledButton(
                      onPressed: null,
                      child: Text('$page'),
                    )
                  : OutlinedButton(
                      onPressed: () => onPageChanged(page),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
            );
          }),

          const SizedBox(width: 8),

          // > 다음 페이지
          _NavButton(
            label: '>',
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
          const SizedBox(width: 4),

          // >> 마지막 페이지
          _NavButton(
            label: '>>',
            onPressed: currentPage < totalPages
                ? () => onPageChanged(totalPages)
                : null,
          ),
        ],
      ),
    );
  }

  /// 표시할 페이지 번호 리스트 생성.
  /// -1은 생략 부호(...)를 의미한다.
  List<int> _buildPageNumbers() {
    if (totalPages <= maxVisiblePages) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final pages = <int>[];
    final half = maxVisiblePages ~/ 2;

    int start = math.max(1, currentPage - half);
    int end = math.min(totalPages, start + maxVisiblePages - 1);

    // start 보정
    if (end - start < maxVisiblePages - 1) {
      start = math.max(1, end - maxVisiblePages + 1);
    }

    if (start > 1) {
      pages.add(1);
      if (start > 2) pages.add(-1); // ...
    }

    for (int i = start; i <= end; i++) {
      pages.add(i);
    }

    if (end < totalPages) {
      if (end < totalPages - 1) pages.add(-1); // ...
      pages.add(totalPages);
    }

    return pages;
  }
}

/// 이전/다음/처음/마지막 네비게이션 버튼
class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _NavButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton(
        onPressed: onPressed,
        icon: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: onPressed != null
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).disabledColor,
          ),
        ),
      ),
    );
  }
}
