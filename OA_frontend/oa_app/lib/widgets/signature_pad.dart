import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../constants.dart';

/// 친필 서명 패드 위젯.
///
/// signature 패키지의 [Signature] 위젯을 사용하여 400x400px 크기의
/// 서명 영역을 제공한다. 완료 시 PNG [Uint8List]를 콜백으로 반환한다.
class SignaturePadWidget extends StatefulWidget {
  /// 서명 완료 시 PNG 데이터 콜백
  final ValueChanged<Uint8List> onCompleted;

  const SignaturePadWidget({
    super.key,
    required this.onCompleted,
  });

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  late final SignatureController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 서명 영역
        Container(
          width: signaturePadSize,
          height: signaturePadSize,
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Signature(
              controller: _controller,
              backgroundColor: Colors.white,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 버튼 영역
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 초기화 버튼
            OutlinedButton.icon(
              onPressed: () {
                _controller.clear();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('초기화'),
            ),
            const SizedBox(width: 16),

            // 완료 버튼
            FilledButton.icon(
              onPressed: _onComplete,
              icon: const Icon(Icons.check),
              label: const Text('완료'),
            ),
          ],
        ),
      ],
    );
  }

  /// 서명 완료 처리: PNG 바이트 변환 후 콜백 호출
  Future<void> _onComplete() async {
    if (_controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명을 입력해 주세요.')),
      );
      return;
    }

    final pngBytes = await _controller.toPngBytes();
    if (pngBytes != null) {
      widget.onCompleted(pngBytes);
    }
  }
}
