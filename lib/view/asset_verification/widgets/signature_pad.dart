import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.backgroundColor = Colors.white});

  final Color backgroundColor;

  @override
  SignaturePadState createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<_Stroke> _strokes = [];
  final GlobalKey _boundaryKey = GlobalKey();

  bool get isEmpty => _strokes.every((stroke) => stroke.points.length < 2);

  void clear() {
    setState(() {
      _strokes.clear();
    });
  }

  Future<Uint8List?> exportImage({double pixelRatio = 3}) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _handlePointerDown(PointerDownEvent event) {
    final stroke = _Stroke();
    _appendPoint(stroke, event.localPosition, event.pressure, event);
    setState(() {
      _strokes.add(stroke);
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_strokes.isEmpty) return;
    final stroke = _strokes.last;
    setState(() {
      _appendPoint(stroke, event.localPosition, event.pressure, event);
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_strokes.isEmpty) return;
    final stroke = _strokes.last;
    setState(() {
      _appendPoint(stroke, event.localPosition, event.pressure, event);
    });
  }

  void _appendPoint(
    _Stroke stroke,
    Offset position,
    double pressure,
    PointerEvent event,
  ) {
    final clampedPosition = _clampToBounds(position);
    final normalized = _normalizePressure(pressure, event.pressureMin, event.pressureMax);
    stroke.points.add(clampedPosition);
    stroke.widths.add(_strokeWidth(normalized));
  }

  Offset _clampToBounds(Offset position) {
    final boundaryContext = _boundaryKey.currentContext;
    if (boundaryContext == null) {
      return position;
    }

    final size = boundaryContext.size;
    if (size == null) {
      return position;
    }

    final dx = position.dx.clamp(0.0, size.width);
    final dy = position.dy.clamp(0.0, size.height);
    return Offset(dx, dy);
  }

  double _normalizePressure(double pressure, double min, double max) {
    final resolvedMin = min == max ? 0.0 : min;
    final resolvedMax = min == max ? 1.0 : math.max(max, min + 1e-3);
    final clamped = pressure.clamp(resolvedMin, resolvedMax);
    final normalized = (clamped - resolvedMin) / (resolvedMax - resolvedMin);
    return normalized.clamp(0.0, 1.0);
  }

  double _strokeWidth(double pressure) {
    const minWidth = 1.5;
    const maxWidth = 5.0;
    return minWidth + (maxWidth - minWidth) * pressure;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: _boundaryKey,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade400),
        ),
        child: Listener(
          onPointerDown: _handlePointerDown,
          onPointerMove: _handlePointerMove,
          onPointerUp: _handlePointerUp,
          onPointerCancel: (_) {},
          behavior: HitTestBehavior.opaque,
          child: CustomPaint(
            painter: _SignaturePainter(_strokes),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _Stroke {
  final List<Offset> points = [];
  final List<double> widths = [];
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<_Stroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final stroke in strokes) {
      if (stroke.points.length < 2) {
        if (stroke.points.isNotEmpty) {
          paint.strokeWidth = stroke.widths.firstOrNull ?? 2.0;
          canvas.drawPoints(ui.PointMode.points, stroke.points, paint);
        }
        continue;
      }

      for (var i = 0; i < stroke.points.length - 1; i++) {
        final start = stroke.points[i];
        final end = stroke.points[i + 1];
        final width = stroke.widths[i];
        final nextWidth = stroke.widths[i + 1];
        paint.strokeWidth = (width + nextWidth) / 2;
        canvas.drawLine(start, end, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

extension on List<double> {
  double? get firstOrNull => isEmpty ? null : first;
}
