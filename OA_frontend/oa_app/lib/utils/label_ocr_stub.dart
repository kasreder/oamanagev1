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
