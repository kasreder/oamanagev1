import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SignatureService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _bucket = 'inspection-signatures';

  /// 서명 이미지 업로드
  ///
  /// [inspectionId] 실사 ID
  /// [signatureBytes] 서명 이미지 PNG 바이트 데이터
  ///
  /// 반환: Storage 내 파일 경로
  Future<String> upload({
    required int inspectionId,
    required Uint8List signatureBytes,
  }) async {
    final path = '$inspectionId/signature.png';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          signatureBytes,
          fileOptions: const FileOptions(
            contentType: 'image/png',
            upsert: true,
          ),
        );

    return path;
  }

  /// 서명 이미지 Signed URL 발급 (유효기간 1시간)
  Future<String> getSignedUrl(String path) async {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }
}
