import 'dart:typed_data';

import 'package:flutter/material.dart';

class SignatureThumbnail extends StatelessWidget {
  const SignatureThumbnail({
    super.key,
    required this.bytes,
    this.maxWidth = 72,
    this.maxHeight = 28,
  });

  final Uint8List bytes;
  final double maxWidth;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: maxWidth,
      height: maxHeight,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.center,
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
