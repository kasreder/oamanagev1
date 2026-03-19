import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

// 플랫폼별 조건부 임포트
import 'label_ocr_mobile.dart'
    if (dart.library.html) 'label_ocr_stub.dart' as platform_ocr;

/// 라벨 사진 OCR 처리 유틸리티.
/// 모바일: google_mlkit_text_recognition (온디바이스)
/// 웹: Tesseract.js (로컬 번들, JS interop)
class LabelOcr {
  LabelOcr._();

  /// 모든 플랫폼에서 지원
  static bool get isSupported => true;

  /// 파일 경로로 인식 (모바일 전용)
  static Future<List<String>> recognizeFromFile(String filePath) {
    return platform_ocr.recognizeFromFile(filePath);
  }

  /// XFile에서 인식 (모바일 + 웹 모두 지원)
  static Future<List<String>> recognizeFromXFile(XFile file) async {
    if (!kIsWeb) {
      return platform_ocr.recognizeFromFile(file.path);
    }
    // 웹: 바이트를 읽어서 Tesseract.js로 처리
    final bytes = await file.readAsBytes();
    return platform_ocr.recognizeFromBytes(bytes);
  }
}
