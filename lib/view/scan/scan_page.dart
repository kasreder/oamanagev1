// lib/view/scan/scan_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

// QR 스캔 화면을 담당하는 최상위 위젯
// ------------------------------------------------------------
// 이 화면은 모바일/웹 환경에서 공통으로 사용할 수 있도록 작성되었으며
// 모바일 스캐너 패키지를 통해 QR 코드를 인식한다.
// 아래의 State 클래스에서는 카메라 권한, 토치 제어, 카메라 전환,
// 스캔 결과 처리 등 다양한 상태를 관리한다.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // MobileScanner 컨트롤러: 카메라 제어와 스캔 결과 수신에 사용된다.
  final MobileScannerController _controller = MobileScannerController();
  // 비프음 재생을 위한 오디오 플레이어 (저지연 모드 사용)
  late final AudioPlayer _beepPlayer;
  // 토치(플래시) 상태를 즉시 반영하기 위한 ValueNotifier
  final ValueNotifier<TorchState> _torchStateNotifier =
      ValueNotifier<TorchState>(TorchState.off);
  // 전/후면 카메라 전환 상태를 추적하는 ValueNotifier
  final ValueNotifier<CameraFacing> _cameraFacingNotifier =
      ValueNotifier<CameraFacing>(CameraFacing.back);
  // 스캔 중복 처리를 피하기 위한 플래그
  bool _isProcessing = false;
  // 일시정지 상태인지 여부
  bool _isPaused = false;
  // 권한 관련 에러 메시지 저장용 변수
  String? _permissionError;
  // 최근 스캔된 UID 리스트(최대 5개 보관)
  final List<_ScannedBarcode> _scannedBarcodes = [];

  @override
  void initState() {
    super.initState();
    _beepPlayer = AudioPlayer(playerId: 'beep_player');
    unawaited(_beepPlayer.setPlayerMode(PlayerMode.lowLatency));
    // 최초 진입 시 카메라 권한을 확인한다.
    _checkPermission();
  }

  @override
  void dispose() {
    // 사용 중인 리소스들을 반드시 해제하여 메모리 누수를 방지한다.
    _torchStateNotifier.dispose();
    _cameraFacingNotifier.dispose();
    _controller.dispose();
    _beepPlayer.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // 바코드가 감지될 때마다 호출되는 콜백.
    //   - 중복 스캔 방지를 위해 _isProcessing 플래그를 활용한다.
    //   - 카메라가 일시정지된 경우나 바코드 배열이 비어 있는 경우 조용히 반환한다.
    if (_isProcessing || _isPaused || capture.barcodes.isEmpty) {
      return;
    }
    // 첫 번째 바코드 정보만 사용한다. (다중 바코드는 현재 필요 없음)
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null) {
      _showError('유효하지 않은 QR 코드입니다.');
      return;
    }
    // 중복 처리를 방지하기 위해 플래그를 설정한다.
    _isProcessing = true;
    try {
      // QR 데이터에서 자산 UID를 추출한다.
      final assetUid = _parseAssetUid(rawValue);
      if (!mounted) {
        return;
      }
      final provider = context.read<InspectionProvider>();
      final isRegistered = provider.assetExists(assetUid);
      final existingIndex =
          _scannedBarcodes.indexWhere((item) => item.uid == assetUid);

      if (existingIndex != -1) {
        // 이미 목록에 있는 경우 맨 위로 올리고 진동/단일 비프음 재생
        unawaited(_playBeep());
        _triggerVibration();
        setState(() {
          final updated =
              _ScannedBarcode(uid: assetUid, isRegistered: isRegistered);
          _scannedBarcodes
            ..removeAt(existingIndex)
            ..insert(0, updated);
        });
      } else {
        // 신규 스캔인 경우 등록 여부에 따라 사운드 피드백 제공
        unawaited(_playBeep(count: isRegistered ? 2 : 1));
        setState(() {
          _scannedBarcodes.insert(
            0,
            _ScannedBarcode(uid: assetUid, isRegistered: isRegistered),
          );
          if (_scannedBarcodes.length > 5) {
            _scannedBarcodes.removeRange(5, _scannedBarcodes.length);
          }
        });
      }
    } catch (error) {
      _showError('QR 파싱 실패: $error');
    } finally {
      // 일정 시간 후 다시 스캔 가능하도록 플래그를 초기화한다.
      Timer(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        } else {
          _isProcessing = false;
        }
      });
    }
  }

  String _parseAssetUid(String rawValue) {
    try {
      // JSON 형태의 QR 데이터라면 asset_uid 값을 우선적으로 사용한다.
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        final uid = decoded['asset_uid'] as String?;
        if (uid != null && uid.isNotEmpty) {
          return uid;
        }
      }
    } catch (_) {
      // 단순 문자열 QR 코드 처리.
    }
    // JSON 파싱이 실패하거나 단순 문자열인 경우, 원본 문자열을 그대로 사용한다.
    if (rawValue.isEmpty) {
      throw const FormatException('빈 QR 코드');
    }
    return rawValue;
  }

  void _showError(String message) {
    // 화면이 언마운트된 경우에는 스낵바를 띄울 수 없으므로 즉시 반환한다.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openSettings() async {
    // 사용자가 직접 앱 설정으로 이동하여 권한을 허용하도록 안내한다.
    await openAppSettings();
  }

  Future<void> _checkPermission() async {
    try {
      // 카메라 권한을 요청하고 현재 상태를 갱신한다.
      final status = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permissionError = status.isGranted ? null : '카메라 권한이 필요합니다.';
      });
    } catch (error) {
      // 권한 요청 과정에서 예외가 발생한 경우 사용자에게 안내한다.
      if (!mounted) return;
      setState(() {
        _permissionError = '권한 확인 중 오류: $error';
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        return AppScaffold(
          title: 'QR 스캔',
          selectedIndex: 0,
          showFooter: false,
          // LayoutBuilder는 가용 공간 정보를 전달받아 다양한 화면 크기에서
          // 동일한 UI 가이드를 유지하도록 돕는다.
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              // ▶ 컷아웃(스캔/가이드) 크기와 위치 계산
              //   - 화면 너비의 70%를 기본값으로 삼되, 너무 작거나 크게 표시되지 않도록 클램프한다.
              //   - 세로 비율은 전체 높이의 35%를 사용하되 최대 높이를 제한한다.
              final cutoutWidth  = (size.width  * 0.70).clamp(120.0, size.width);
              final cutoutHeight = (size.height * 0.35).clamp(120.0, size.height * 0.6);

              // 중앙(0.5)보다 위쪽으로: 0.35 지점에 배치하여 사용자가 손을 덜 가리고 스캔할 수 있게 한다.
              final centerY = size.height * 0.35;

              final cutoutRect = Rect.fromCenter(
                center: Offset(size.width / 2, centerY),
                width:  cutoutWidth,
                height: cutoutHeight,
              );

              return Stack(
                children: [
                  // 카메라 & 스캔 영역을 가장 아래 레이어에 배치한다.
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      scanWindow: cutoutRect, // ★ 실제 인식 영역을 위로 이동
                      onDetect: _onDetect,
                      // 스캐너에서 발생한 에러는 사용자에게 즉시 텍스트로 안내한다.
                      errorBuilder: (context, error, child) {
                        final details = error.errorDetails?.toString();
                        return Center(
                          child: Text('카메라 오류: ${details ?? error.errorCode.name}'),
                        );
                      },
                    ),
                  ),

                  // 가이드 오버레이 (같은 사각형 사용)
                  _ScannerOverlay(cutOutRect: cutoutRect),

                  // ===== 상단 컨트롤(뒤로/플래시/전후면/일시정지) - 그대로 유지 =====
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _OverlayIconButton(
                              icon: Icons.arrow_back,
                              label: '뒤로가기',
                              onPressed: () => context.pop(),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 토치 상태는 ValueListenableBuilder를 통해 실시간 반영한다.
                                ValueListenableBuilder<TorchState>(
                                  valueListenable: _torchStateNotifier,
                                  builder: (context, state, _) {
                                    final isOn = state == TorchState.on;
                                    return _OverlayIconButton(
                                      icon: isOn ? Icons.flash_on : Icons.flash_off,
                                      label: '플래시',
                                      onPressed: _toggleTorch,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // 전/후면 카메라 상태 역시 별도 ValueNotifier로 관리한다.
                                ValueListenableBuilder<CameraFacing>(
                                  valueListenable: _cameraFacingNotifier,
                                  builder: (context, facing, _) {
                                    return _OverlayIconButton(
                                      icon: Icons.cameraswitch,
                                      label: facing == CameraFacing.back ? '후면' : '전면',
                                      onPressed: _switchCamera,
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                // 스캔 일시정지 여부에 따라 버튼 모양과 동작이 달라진다.
                                _OverlayIconButton(
                                  icon: _isPaused ? Icons.play_arrow : Icons.pause,
                                  label: _isPaused ? '재시작' : '일시정지',
                                  onPressed: _togglePause,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ===== 권한 에러/하단 패널/최근 UID - 그대로 유지 =====
                  // 권한이 거부된 경우에는 카메라 화면 대신 안내 메시지를 표시한다.
                  if (_permissionError != null)
                    Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.no_photography, color: Colors.white, size: 48),
                          const SizedBox(height: 16),
                          Text(_permissionError!, style: const TextStyle(color: Colors.white, fontSize: 18)),
                          const SizedBox(height: 16),
                          FilledButton(onPressed: _openSettings, child: const Text('설정에서 권한 허용')),
                          TextButton(onPressed: _checkPermission, child: const Text('다시 시도', style: TextStyle(color: Colors.white))),
                          if (kIsWeb)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text('웹에서는 HTTPS 환경과 권한 허용이 필요합니다.', style: TextStyle(color: Colors.white70)),
                            ),
                        ],
                      ),
                    )
                  else
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Container(
                            //   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            //   decoration: BoxDecoration(
                            //     color: Colors.black.withOpacity(0.6),
                            //     borderRadius: BorderRadius.circular(24),
                            //   ),
                            //   child: const Text(
                            //     '신규/재등록 + 코드',
                            //     style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            //   ),
                            // ),
                            // const SizedBox(height: 12),

                            if (_scannedBarcodes.isEmpty)
                              Text(
                                kIsWeb
                                    ? '카메라 접근을 허용했는지 확인하세요.'
                                    : 'QR 코드를 뷰파인더 중앙에 맞춰주세요.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      shadows: const [Shadow(blurRadius: 8)],
                                    ),
                                textAlign: TextAlign.center,
                              )
                            else
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: () {
                                  // 화면에는 최대 5개만 출력 (이미 _onDetect에서도 5개로 유지 중)
                                  final visible = _scannedBarcodes.take(5).toList();
                                  return [
                                    for (var i = 0; i < visible.length; i++) ...[
                                      _ScannedBarcodeRow(
                                        barcode: visible[i].uid,
                                        isRegistered: visible[i].isRegistered,
                                        onAction: visible[i].isRegistered
                                            ? () => _verifyAsset(visible[i].uid)
                                            : () => _registerAsset(visible[i].uid),
                                        onDelete: () => _removeBarcode(visible[i].uid),
                                      ),
                                      if (i != visible.length - 1) const SizedBox(height: 2),
                                    ],
                                  ];
                                }(),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );

      },
    );
  }

  Future<void> _toggleTorch() async {
    // MobileScanner 컨트롤러를 통해 토치 상태를 토글한다.
    await _controller.toggleTorch();
    if (!mounted) return;
    final current = _torchStateNotifier.value;
    _torchStateNotifier.value =
        current == TorchState.on ? TorchState.off : TorchState.on;
  }

  Future<void> _switchCamera() async {
    // 전/후면 카메라를 전환하고 상태를 반영한다.
    await _controller.switchCamera();
    if (!mounted) return;
    final current = _cameraFacingNotifier.value;
    _cameraFacingNotifier.value =
        current == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
  }

  Future<void> _togglePause() async {
    // 스캔을 일시정지하거나 재시작한다.
    //   - stop() 호출 시 카메라 스트림이 중지되어 onDetect 콜백이 더 이상 호출되지 않는다.
    //   - start() 호출 시 다시 스트림을 시작한다.
    if (_isPaused) {
      await _controller.start();
    } else {
      await _controller.stop();
    }
    if (!mounted) return;
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _removeBarcode(String uid) {
    // 하단 목록에서 특정 UID를 제거한다.
    // 최근 스캔한 값을 사용자가 직접 삭제할 수 있도록 제공되는 기능이다.
    setState(() {
      _scannedBarcodes.removeWhere((item) => item.uid == uid);
    });
  }

  Future<void> _playBeep({int count = 1}) async {
    // 로컬 자산으로 저장된 비프음을 재생하여 스캔 성공을 알린다.
    // count 매개변수를 통해 동일한 사운드를 여러 번 연속 재생할 수 있다.
    for (var i = 0; i < count; i++) {
      try {
        await _beepPlayer.stop();
        await _beepPlayer.play(AssetSource('sounds/Beep1.mp3'));
      } catch (error) {
        debugPrint('비프음 재생 실패: $error');
        break;
      }
      if (i < count - 1) {
        await Future.delayed(const Duration(milliseconds: 160));
      }
    }
  }

  void _triggerVibration() {
    // 햅틱 피드백을 통해 사용자가 동일한 QR을 다시 스캔했음을 직관적으로 알 수 있게 한다.
    HapticFeedback.mediumImpact();
  }

  void _verifyAsset(String uid) {
    // 자산 검수(검증) 내역을 즉시 생성하여 저장한다.
    //   1. InspectionProvider에서 자산 정보를 조회한다.
    //   2. 현재 시간을 기록하여 고유한 검수 ID를 만든다.
    //   3. status 값은 기존 자산 상태가 존재하면 그대로 사용하고, 없으면 기본값 '사용'을 적용한다.
    //   4. 생성된 Inspection을 저장하고 사용자에게 스낵바로 알린다.
    final provider = context.read<InspectionProvider>();
    final now = DateTime.now();
    final asset = provider.assetOf(uid);
    final inspection = Inspection(
      id: 'ins_${uid}_${now.microsecondsSinceEpoch}',
      assetUid: uid,
      status: asset?.status.isNotEmpty == true ? asset!.status : '사용',
      memo: 'QR 인증',
      scannedAt: now,
      synced: false,
    );
    provider.addOrUpdate(inspection);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('인증 내역이 저장되었습니다. (${inspection.assetUid})')),
    );
  }

  void _registerAsset(String uid) {
    // 등록되지 않은 자산이라면 사용자에게 등록을 유도한다.
    // 이후 자산 등록 화면으로 즉시 라우팅하여 흐름을 이어갈 수 있도록 한다.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('새 자산 등록을 진행해주세요. ($uid)')),
    );
    final encoded = Uri.encodeComponent(uid);
    context.go('/assets/register?uid=$encoded');
  }
}

/// 스캔된 바코드와 해당 자산의 등록 여부를 묶어 관리하는 단순 데이터 클래스.
/// 최근 5개까지만 보관하여 사용자에게 직관적인 히스토리를 제공한다.
class _ScannedBarcode {
  const _ScannedBarcode({required this.uid, required this.isRegistered});

  final String uid;
  final bool isRegistered;
}

/// 최근 스캔된 바코드 한 항목을 표현하는 위젯.
/// 등록 여부에 따라 버튼 라벨과 동작이 달라지며, 삭제 버튼으로 목록에서 제거할 수 있다.
class _ScannedBarcodeRow extends StatelessWidget {
  const _ScannedBarcodeRow({
    required this.barcode,
    required this.isRegistered,
    required this.onAction,
    required this.onDelete,
  });

  final String barcode;
  final bool isRegistered;
  final VoidCallback onAction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final buttonLabel = isRegistered ? '인증' : '자산등록';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), // 세로 여백 축소
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(8), // 조금 더 작게
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              barcode,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(70, 32), // 버튼 크기 축소
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 13), // 글자 크기도 약간 줄임
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onDelete,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white12,
              foregroundColor: Colors.white,
              minimumSize: const Size(32, 32), // 아이콘 버튼 최소 크기 줄임
              padding: EdgeInsets.zero,        // 내부 여백 제거
            ),
            icon: const Icon(Icons.close, size: 18), // 아이콘 크기 축소
          ),
        ],
      ),
    );

  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.cutOutRect});
  final Rect cutOutRect;

  @override
  Widget build(BuildContext context) {
    // overlay 터치 이벤트가 하위 위젯에 전달되도록 IgnorePointer로 감싼다.
    // 즉, 오버레이는 시각적인 정보만 제공하며 사용자 입력은 MobileScanner로 전달된다.
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ScannerOverlayPainter(cutOutRect),
      ),
    );
  }
}


class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter(this.cutOutRect);

  final Rect cutOutRect;

  @override
  void paint(Canvas canvas, Size size) {
    // 화면 전체에 반투명 흰색을 깔고, 스캔 영역은 투명하게 처리한다.
    // PathFillType.evenOdd를 사용하여 사각형 안쪽이 비어 보이도록 구성한다.
    final overlayPaint = Paint()
      ..color = Colors.white.withOpacity(0.85);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectXY(cutOutRect, 16, 16));
    canvas.drawPath(path, overlayPaint);

    // 스캔 영역 경계를 파란색으로 강조하여 사용자 가이드를 돕는다.
    final borderPaint = Paint()
      ..color = Colors.indigo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawRRect(
      RRect.fromRectXY(cutOutRect, 16, 16),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    // 컷아웃 위치나 크기가 변경될 때만 다시 그려주면 된다.
    return oldDelegate.cutOutRect != cutOutRect;
  }
}

class _OverlayIconButton extends StatelessWidget {
  const _OverlayIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // 상단 컨트롤 버튼들을 일관된 스타일로 렌더링한다.
    // 모든 버튼이 동일한 배경/모서리/텍스트 크기를 갖도록 중앙에서 조정한다.
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: Colors.black.withOpacity(0.55),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        elevation: 0,
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
