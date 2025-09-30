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

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final ValueNotifier<TorchState> _torchStateNotifier =
      ValueNotifier<TorchState>(TorchState.off);
  final ValueNotifier<CameraFacing> _cameraFacingNotifier =
      ValueNotifier<CameraFacing>(CameraFacing.back);
  bool _isProcessing = false;
  bool _isPaused = false;
  String? _permissionError;
  String? _activeUid;
  final List<String> _recentUids = [];

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _torchStateNotifier.dispose();
    _cameraFacingNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _isPaused || capture.barcodes.isEmpty) {
      return;
    }
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null) {
      _showError('유효하지 않은 QR 코드입니다.');
      return;
    }
    _isProcessing = true;
    try {
      final assetUid = _parseAssetUid(rawValue);
      setState(() {
        _activeUid = assetUid;
        _recentUids.remove(assetUid);
        _recentUids.insert(0, assetUid);
        if (_recentUids.length > 5) {
          _recentUids.removeRange(5, _recentUids.length);
        }
      });
    } catch (error) {
      _showError('QR 파싱 실패: $error');
    } finally {
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
    if (rawValue.isEmpty) {
      throw const FormatException('빈 QR 코드');
    }
    return rawValue;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  Future<void> _checkPermission() async {
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      setState(() {
        _permissionError = status.isGranted ? null : '카메라 권한이 필요합니다.';
      });
    } catch (error) {
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
        final activeUid = _activeUid;
        final activeAsset =
            activeUid != null ? provider.assetOf(activeUid) : null;
        final isRegistered =
            activeUid != null ? provider.assetExists(activeUid) : false;
        return AppScaffold(
          title: 'QR 스캔',
          selectedIndex: 0,
          showFooter: false,
          body: Stack(
            children: [
              Positioned.fill(
                child: MobileScanner(
                  controller: _controller,
                  fit: BoxFit.cover,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    final details = error.errorDetails?.toString();
                    return Center(
                      child:
                          Text('카메라 오류: ${details ?? error.errorCode.name}'),
                    );
                  },
                ),
              ),
              const _ScannerOverlay(),
              if (_isPaused)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        '스캔이 일시정지되었습니다.',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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
                                  icon:
                                      isOn ? Icons.flash_on : Icons.flash_off,
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
                                  label: facing == CameraFacing.back
                                      ? '후면'
                                      : '전면',
                                  onPressed: _switchCamera,
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            _OverlayIconButton(
                              icon: _isPaused
                                  ? Icons.play_arrow
                                  : Icons.pause,
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
              if (_permissionError != null)
                Container(
                  color: Colors.black54,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography,
                          color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _permissionError!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _openSettings,
                        child: const Text('설정에서 권한 허용'),
                      ),
                      TextButton(
                        onPressed: _checkPermission,
                        child: const Text(
                          '다시 시도',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      if (kIsWeb)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            '웹에서는 HTTPS 환경과 권한 허용이 필요합니다.',
                            style: TextStyle(color: Colors.white70),
                          ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            '신규/재등록 + 코드',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (activeUid == null)
                          Text(
                            kIsWeb
                                ? '카메라 접근을 허용했는지 확인하세요.'
                                : 'QR 코드를 뷰파인더 중앙에 맞춰주세요.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                    color: Colors.white,
                                    shadows: const [Shadow(blurRadius: 8)]),
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
                            children: _recentUids
                                .map(
                                  (uid) => ChoiceChip(
                                    label: Text(uid),
                                    selected: uid == activeUid,
                                    onSelected: (_) {
                                      setState(() {
                                        _activeUid = uid;
                                      });
                                    },
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openAssetDetail(String uid) {
    context.go('/assets/$uid');
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    if (!mounted) return;
    final current = _torchStateNotifier.value;
    _torchStateNotifier.value =
        current == TorchState.on ? TorchState.off : TorchState.on;
  }

  Future<void> _switchCamera() async {
    await _controller.switchCamera();
    if (!mounted) return;
    final current = _cameraFacingNotifier.value;
    _cameraFacingNotifier.value =
        current == CameraFacing.back ? CameraFacing.front : CameraFacing.back;
  }

  Future<void> _togglePause() async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('새 자산 등록을 진행해주세요. ($uid)')),
    );
    context.go('/assets/register');
  }
}
class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final cutoutWidth = size.width * 0.7;
          final cutoutHeight = size.height * 0.35;
          final rect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: cutoutWidth.clamp(120.0, size.width),
            height: cutoutHeight.clamp(120.0, size.height * 0.6),
          );
          return CustomPaint(
            size: size,
            painter: _ScannerOverlayPainter(rect),
          );
        },
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter(this.cutOutRect);

  final Rect cutOutRect;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.white.withOpacity(0.85);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectXY(cutOutRect, 16, 16));
    canvas.drawPath(path, overlayPaint);

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
