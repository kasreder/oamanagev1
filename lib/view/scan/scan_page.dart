// lib/view/scan/scan_page.dart
import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  // 화면 하단에 표시될 현재 활성 UID
  String? _activeUid;
  // 최근 스캔된 UID 리스트(최대 5개 보관)
  final List<String> _recentUids = [];

  @override
  void initState() {
    super.initState();
    // 최초 진입 시 카메라 권한을 확인한다.
    _checkPermission();
  }

  @override
  void dispose() {
    // 사용 중인 리소스들을 반드시 해제하여 메모리 누수를 방지한다.
    _torchStateNotifier.dispose();
    _cameraFacingNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // 이미 처리 중이거나 일시정지 상태일 경우 추가 처리를 막는다.
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
      setState(() {
        // 현재 활성 UID 업데이트
        _activeUid = assetUid;
        // 중복 제거 후 최근 리스트 맨 앞에 추가
        _recentUids.remove(assetUid);
        _recentUids.insert(0, assetUid);
        if (_recentUids.length > 5) {
          // 최대 5개까지만 유지하여 UI 혼잡을 줄인다.
          _recentUids.removeRange(5, _recentUids.length);
        }
      });
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
        // 현재 활성 UID에 대한 자산 정보를 조회한다.
        final activeUid = _activeUid;
        final activeAsset =
            activeUid != null ? provider.assetOf(activeUid) : null;
        final isRegistered =
            activeUid != null ? provider.assetExists(activeUid) : false;
// ... 생략 ...

        return AppScaffold(
          title: 'QR 스캔',
          selectedIndex: 0,
          showFooter: false,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);

              // ▶ 컷아웃(스캔/가이드) 크기와 위치 계산
              final cutoutWidth  = (size.width  * 0.70).clamp(120.0, size.width);
              final cutoutHeight = (size.height * 0.35).clamp(120.0, size.height * 0.6);

              // 중앙(0.5)보다 위쪽으로: 0.35 지점
              final centerY = size.height * 0.35;

              final cutoutRect = Rect.fromCenter(
                center: Offset(size.width / 2, centerY),
                width:  cutoutWidth,
                height: cutoutHeight,
              );

              return Stack(
                children: [
                  // 카메라 & 스캔
                  Positioned.fill(
                    child: MobileScanner(
                      controller: _controller,
                      fit: BoxFit.cover,
                      scanWindow: cutoutRect, // ★ 실제 인식 영역을 위로 이동
                      onDetect: _onDetect,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Text(
                                '신규/재등록 + 코드',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (activeUid == null)
                              Text(
                                kIsWeb ? '카메라 접근을 허용했는지 확인하세요.' : 'QR 코드를 뷰파인더 중앙에 맞춰주세요.',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white,
                                  shadows: const [Shadow(blurRadius: 8)],
                                ),
                                textAlign: TextAlign.center,
                              )
                            else
                              _ScannedAssetPanel(
                                uid: activeUid,
                                assetName: activeAsset?.name,
                                location: activeAsset?.location,
                                isRegistered: isRegistered,
                                onEdit: () => _openAssetDetail(activeUid),
                                onVerify: () => _verifyAsset(activeUid),
                                onRegister: () => _registerAsset(activeUid),
                              ),

                            if (_recentUids.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 8,
                                children: _recentUids.map((uid) {
                                  return ChoiceChip(
                                    label: Text(uid),
                                    selected: uid == activeUid,
                                    onSelected: (_) => setState(() => _activeUid = uid),
                                  );
                                }).toList(),
                              ),
                            ],
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

  void _openAssetDetail(String uid) {
    // 자산 상세 화면으로 이동한다.
    context.go('/assets/$uid');
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

  void _verifyAsset(String uid) {
    // 자산 검수(검증) 내역을 즉시 생성하여 저장한다.
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('새 자산 등록을 진행해주세요. ($uid)')),
    );
    context.go('/assets/register');
  }
}
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.cutOutRect});
  final Rect cutOutRect;

  @override
  Widget build(BuildContext context) {
    // overlay 터치 이벤트가 하위 위젯에 전달되도록 IgnorePointer로 감싼다.
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
    return oldDelegate.cutOutRect != cutOutRect;
  }
}

class _ScannedAssetPanel extends StatelessWidget {
  const _ScannedAssetPanel({
    required this.uid,
    required this.isRegistered,
    this.assetName,
    this.location,
    this.onEdit,
    this.onVerify,
    this.onRegister,
  });
  final String uid;
  final bool isRegistered;
  final String? assetName;
  final String? location;
  final VoidCallback? onEdit;
  final VoidCallback? onVerify;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    // 스캔 결과를 카드 형태로 표현하여 가독성을 높인다.
    return Card(
      color: Colors.black.withOpacity(0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '스캔된 자산번호',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              uid,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            if (assetName != null && assetName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                assetName!,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            if (location != null && location!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                location!,
                style: const TextStyle(color: Colors.white54),
              ),
            ],
            const SizedBox(height: 12),
            if (isRegistered)
              Row(
                children: [
                  Expanded(
                    // 이미 등록된 자산이라면 수정 버튼과 인증 버튼을 함께 제공한다.
                    child: FilledButton(
                      onPressed: onEdit,
                      child: const Text('수정하기'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onVerify,
                      child: const Text('인증하기'),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // 미등록 자산은 등록하기 버튼만 단독으로 노출한다.
                  onPressed: onRegister,
                  child: const Text('등록하기'),
                ),
              ),
          ],
        ),
      ),
    );
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
