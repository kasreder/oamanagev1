import 'package:flutter/material.dart';

import '../models/drawing.dart';

/// 도면 위에 격자(Grid)를 오버레이하는 위젯.
///
/// [CustomPainter]를 사용해 gridRows x gridCols 크기의 격자선을 그리며,
/// 각 셀에 [Drawing.getGridLabel]로 생성한 라벨(예: "A-1", "B-3")을
/// 표시한다.
class DrawingGridOverlay extends StatelessWidget {
  /// 격자 행 수
  final int gridRows;

  /// 격자 열 수
  final int gridCols;

  /// 격자선 색상 (기본값: 반투명 회색)
  final Color? lineColor;

  /// 격자선 두께
  final double lineWidth;

  /// 라벨 표시 여부
  final bool showLabels;

  const DrawingGridOverlay({
    super.key,
    required this.gridRows,
    required this.gridCols,
    this.lineColor,
    this.lineWidth = 0.5,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor =
        lineColor ?? Theme.of(context).colorScheme.outline.withOpacity(0.4);

    return IgnorePointer(
      child: CustomPaint(
        painter: _GridPainter(
          gridRows: gridRows,
          gridCols: gridCols,
          lineColor: effectiveColor,
          lineWidth: lineWidth,
        ),
        child: showLabels
            ? LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = constraints.maxWidth / gridCols;
                  final cellHeight = constraints.maxHeight / gridRows;

                  return Stack(
                    children: [
                      for (int row = 0; row < gridRows; row++)
                        for (int col = 0; col < gridCols; col++)
                          Positioned(
                            left: col * cellWidth + 2,
                            top: row * cellHeight + 1,
                            child: Text(
                              Drawing.getGridLabel(row, col),
                              style: TextStyle(
                                fontSize: 9,
                                color: effectiveColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                    ],
                  );
                },
              )
            : null,
      ),
    );
  }
}

/// 격자선을 그리는 CustomPainter.
class _GridPainter extends CustomPainter {
  final int gridRows;
  final int gridCols;
  final Color lineColor;
  final double lineWidth;

  _GridPainter({
    required this.gridRows,
    required this.gridCols,
    required this.lineColor,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    final cellWidth = size.width / gridCols;
    final cellHeight = size.height / gridRows;

    // 수직선
    for (int col = 0; col <= gridCols; col++) {
      final x = col * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 수평선
    for (int row = 0; row <= gridRows; row++) {
      final y = row * cellHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) {
    return gridRows != oldDelegate.gridRows ||
        gridCols != oldDelegate.gridCols ||
        lineColor != oldDelegate.lineColor ||
        lineWidth != oldDelegate.lineWidth;
  }
}
