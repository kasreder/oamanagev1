import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 모바일 전용: ML Kit OCR
Future<List<String>> recognizeFromFile(String filePath) async {
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

/// 모바일: 바이트에서 인식 (사용되지 않음, 인터페이스 통일용)
Future<List<String>> recognizeFromBytes(Uint8List bytes) async {
  throw UnsupportedError('모바일에서는 recognizeFromFile을 사용하세요.');
}

/// 모바일: 바이트에서 단어 단위 인식 (미사용, 인터페이스 통일용)
Future<List<String>> recognizeWordsFromBytes(Uint8List bytes) async {
  throw UnsupportedError('모바일에서는 recognizeWordsFromFile을 사용하세요.');
}

/// 모바일 전용: 파일 경로에서 단어 단위로 인식
Future<List<String>> recognizeWordsFromFile(String filePath) async {
  final inputImage = InputImage.fromFilePath(filePath);
  final recognizer = TextRecognizer();
  try {
    final result = await recognizer.processImage(inputImage);
    final words = <String>[];
    for (final block in result.blocks) {
      for (final line in block.lines) {
        for (final element in line.elements) {
          final text = element.text.trim();
          if (text.isNotEmpty) words.add(text);
        }
      }
    }
    return words;
  } finally {
    recognizer.close();
  }
}
