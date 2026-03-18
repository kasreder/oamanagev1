import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 라벨 사진 OCR 처리 유틸리티.
/// google_mlkit_text_recognition (모바일 전용).
class LabelOcr {
  LabelOcr._();

  /// 지원 여부 (Web은 미지원)
  static bool get isSupported => !kIsWeb;

  /// 이미지 파일에서 텍스트를 인식하여 줄 단위 리스트로 반환.
  static Future<List<String>> recognizeFromFile(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    final recognizer = TextRecognizer();
    try {
      final result = await recognizer.processImage(inputImage);
      return result.text
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
    } finally {
      recognizer.close();
    }
  }
}
