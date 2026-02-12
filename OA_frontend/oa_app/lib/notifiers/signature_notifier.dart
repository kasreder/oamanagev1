import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 서명 이미지 상태 관리 Notifier
///
/// 서명 패드에서 캡처한 PNG 바이트 데이터를 임시 보관합니다.
/// 실사 저장 시 SignatureService를 통해 Storage에 업로드합니다.
class SignatureNotifier extends Notifier<Uint8List?> {
  @override
  Uint8List? build() {
    return null;
  }

  /// 서명 데이터 설정
  void setSignature(Uint8List bytes) {
    state = bytes;
  }

  /// 서명 데이터 초기화
  void clearSignature() {
    state = null;
  }
}

/// 서명 상태 Provider
final signatureNotifierProvider =
    NotifierProvider<SignatureNotifier, Uint8List?>(SignatureNotifier.new);
