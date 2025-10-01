import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScannedFooter extends StatelessWidget {
  const ScannedFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false, // ★ 하단 여백 제거
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: FilledButton.icon(
          onPressed: () => context.go('/scan'),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('QR 코드 촬영'),
        ),
      ),
    );
  }
}
