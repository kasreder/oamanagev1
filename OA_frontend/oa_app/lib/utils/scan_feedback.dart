import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// QR/바코드 스캔 피드백 (진동 + 소리)
/// - 등록 자산: 삑 (진동 없음)
/// - 미등록 자산: 삐빅 (진동 없음)
/// - 형식 오류: 삐-빅(길게 삐*3) + 강한 진동
class ScanFeedback {
  ScanFeedback._();

  static final AudioPlayer _player = AudioPlayer();

  /// 등록된 자산 스캔 시: 삑 (진동 없음)
  static Future<void> success() async {
    await _player.play(AssetSource('sounds/beep_success.wav'));
  }

  /// 미등록 자산 스캔 시: 삐빅 (진동 없음)
  static Future<void> error() async {
    await _player.play(AssetSource('sounds/beep_error.wav'));
  }

  /// 형식에 벗어난 코드 스캔 시: 삐-빅(길게 삐*3) + 강한 진동
  static Future<void> invalid() async {
    HapticFeedback.heavyImpact();
    await _player.play(AssetSource('sounds/beep_invalid.wav'));
  }
}
