import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

/// 웹: Tesseract.js (로컬 번들)를 JS interop으로 호출
Future<List<String>> recognizeFromFile(String filePath) async {
  throw UnsupportedError('웹에서는 recognizeFromXFile을 사용하세요.');
}

/// 웹: 이미지 바이트를 base64로 변환 후 JS ocrRecognize() 호출
Future<List<String>> recognizeFromBytes(Uint8List bytes) async {
  final base64 = base64Encode(bytes);
  final jsResult = await _jsOcrRecognize(base64.toJS).toDart;
  final text = jsResult.toDart;

  return text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
}

@JS('ocrRecognize')
external JSPromise<JSString> _jsOcrRecognize(JSString imageBase64);

/// 웹: 바이트에서 단어 단위 인식 (Tesseract.js)
Future<List<String>> recognizeWordsFromFile(String filePath) async {
  throw UnsupportedError('웹에서는 recognizeWordsFromBytes를 사용하세요.');
}

/// 웹: 바이트에서 단어 단위 인식
Future<List<String>> recognizeWordsFromBytes(Uint8List bytes) async {
  final lines = await recognizeFromBytes(bytes);
  final words = <String>[];
  for (final line in lines) {
    for (final word in line.split(RegExp(r'\s+'))) {
      final w = word.trim();
      if (w.isNotEmpty) words.add(w);
    }
  }
  return words;
}
