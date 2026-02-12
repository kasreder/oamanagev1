import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class DrawingService {
  final SupabaseClient _client = Supabase.instance.client;

  static const _bucket = 'drawing-images';

  /// 도면 이미지 업로드
  ///
  /// [drawingId] 도면 ID
  /// [filename] 파일명 (예: 'floor_plan.png')
  /// [imageBytes] 이미지 바이트 데이터
  ///
  /// 반환: Storage 내 파일 경로
  Future<String> upload({
    required int drawingId,
    required String filename,
    required Uint8List imageBytes,
  }) async {
    final path = '$drawingId/$filename';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          imageBytes,
          fileOptions: const FileOptions(
            upsert: true,
          ),
        );

    return path;
  }

  /// 도면 이미지 Signed URL 발급 (유효기간 1시간)
  Future<String> getSignedUrl(String path) async {
    return _client.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  /// 도면 이미지 삭제
  Future<void> delete(String path) async {
    await _client.storage.from(_bucket).remove([path]);
  }
}
