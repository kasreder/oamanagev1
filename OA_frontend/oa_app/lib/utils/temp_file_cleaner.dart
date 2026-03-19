import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// 임시 파일 삭제 유틸리티 (모바일 전용, 웹에서는 무시)
class TempFileCleaner {
  TempFileCleaner._();

  static Future<void> delete(String? filePath) async {
    if (kIsWeb || filePath == null || filePath.isEmpty) return;
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
