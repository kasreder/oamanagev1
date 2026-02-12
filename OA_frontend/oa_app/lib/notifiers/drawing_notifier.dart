import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/asset.dart';
import '../models/drawing.dart';
import '../services/api_service.dart';
import '../services/drawing_service.dart';

/// 도면 목록 관리 Notifier
class DrawingNotifier extends AsyncNotifier<List<Drawing>> {
  late final ApiService _apiService;
  late final DrawingService _drawingService;

  @override
  Future<List<Drawing>> build() async {
    _apiService = ApiService();
    _drawingService = DrawingService();
    return _fetchDrawings();
  }

  /// 도면 목록 조회 (내부)
  Future<List<Drawing>> _fetchDrawings() async {
    return _apiService.fetchDrawings();
  }

  /// 도면 목록 새로고침
  Future<void> fetchDrawings() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchDrawings);
  }

  /// 도면 등록 (이미지 업로드 포함)
  Future<Drawing> createDrawing({
    required Map<String, dynamic> data,
    required Uint8List imageFile,
    required String filename,
  }) async {
    // 1) DB에 도면 레코드 생성
    final drawing = await _apiService.createDrawing(data);

    // 2) Storage에 이미지 업로드
    final storagePath = await _drawingService.upload(
      drawingId: drawing.id,
      filename: filename,
      imageBytes: imageFile,
    );

    // 3) drawing_file 경로 갱신
    final updated = await _apiService.updateDrawing(drawing.id, {
      'drawing_file': storagePath,
    });

    // 4) 목록 새로고침
    await fetchDrawings();

    return updated;
  }

  /// 도면 수정
  Future<Drawing> updateDrawing(
    int id,
    Map<String, dynamic> data,
  ) async {
    final updated = await _apiService.updateDrawing(id, data);
    await fetchDrawings();
    return updated;
  }

  /// 도면 삭제 (이미지 포함)
  Future<void> deleteDrawing(int id) async {
    // 도면 정보 조회하여 이미지 경로 확인
    final drawing = await _apiService.fetchDrawing(id);
    if (drawing.drawingFile != null && drawing.drawingFile!.isNotEmpty) {
      await _drawingService.delete(drawing.drawingFile!);
    }

    await _apiService.deleteDrawing(id);
    await fetchDrawings();
  }

  /// 특정 도면에 배치된 자산 목록 조회
  Future<List<Asset>> getAssetsOnDrawing(int drawingId) async {
    return _apiService.fetchAssetsOnDrawing(drawingId);
  }
}

/// 도면 목록 Provider
final drawingNotifierProvider =
    AsyncNotifierProvider<DrawingNotifier, List<Drawing>>(DrawingNotifier.new);
