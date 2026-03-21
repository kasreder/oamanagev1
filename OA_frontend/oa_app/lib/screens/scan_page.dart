import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../constants.dart';
import '../main.dart';
import '../widgets/common/app_scaffold.dart';

/// 5.1.6 QR 스캔 화면 (/scan)
///
/// - 모바일/웹 공통: MobileScanner 카메라 QR 인식 (mobile_scanner 5.x 웹 지원)
/// - 웹: 카메라 접근 실패 시 자산번호 직접 입력 폴백
/// - 스캔 결과: asset_uid 추출 -> assets 테이블 조회
///   - 등록된 자산: /asset/:id 이동
///   - 미등록: "등록하시겠습니까?" 다이얼로그 -> /asset/new (asset_uid 전달)
/// - 최대 5건 연속 스캔 (maxScanCount)
class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  late final MobileScannerController _scannerController;
  final TextEditingController _manualInputCtrl = TextEditingController();

  int _scanCount = 0;
  bool _isProcessing = false;
  bool _cameraFailed = false;
  final List<String> _scannedCodes = [];

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputCtrl.dispose();
    super.dispose();
  }

  /// QR 코드 감지 콜백
  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    if (_scanCount >= maxScanCount) {
      _showMaxScanReached();
      return;
    }

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final code = barcode.rawValue!.trim();
    if (_scannedCodes.contains(code)) return;

    setState(() => _isProcessing = true);
    _scannedCodes.add(code);
    _scanCount++;

    try {
      await _processScannedCode(code);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 수동 입력 처리
  Future<void> _onManualSubmit() async {
    final code = _manualInputCtrl.text.trim();
    if (code.isEmpty) return;

    if (_scanCount >= maxScanCount) {
      _showMaxScanReached();
      return;
    }

    if (_scannedCodes.contains(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이미 조회한 자산번호입니다.')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    _scannedCodes.add(code);
    _scanCount++;
    _manualInputCtrl.clear();

    try {
      await _processScannedCode(code);
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// 스캔된 코드 처리
  Future<void> _processScannedCode(String assetUid) async {
    try {
      final result = await supabase
          .from('assets')
          .select('id')
          .eq('asset_uid', assetUid)
          .maybeSingle();

      if (!mounted) return;

      if (result != null) {
        final assetId = result['id'] as int;
        context.go('/asset/$assetId');
      } else {
        _showRegisterDialog(assetUid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('조회 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 미등록 자산 등록 다이얼로그
  void _showRegisterDialog(String assetUid) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('미등록 자산'),
        content: Text(
          '자산번호 "$assetUid"은(는) 등록되지 않은 자산입니다.\n새로 등록하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/asset/new', extra: {'initialAssetUid': assetUid});
            },
            child: const Text('등록'),
          ),
        ],
      ),
    );
  }

  /// 최대 스캔 횟수 도달 알림
  void _showMaxScanReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('최대 연속 스캔 횟수($maxScanCount회)에 도달했습니다.'),
        action: SnackBarAction(
          label: '초기화',
          onPressed: _resetScan,
        ),
      ),
    );
  }

  /// 스캔 상태 초기화
  void _resetScan() {
    setState(() {
      _scanCount = 0;
      _scannedCodes.clear();
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'QR 스캔',
      currentIndex: 1,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // ── 스캔 상태 표시 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '스캔 횟수: $_scanCount / $maxScanCount',
                style: theme.textTheme.bodyMedium,
              ),
              Row(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: _resetScan,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('초기화'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── 카메라 스캔 영역 ──
        Expanded(
          child: _cameraFailed
              ? _buildManualInput(theme)
              : _buildScannerView(theme),
        ),

        // ── 웹: 수동 입력 바 (카메라와 함께 표시) ──
        if (kIsWeb && !_cameraFailed) _buildManualInputBar(theme),

        // ── 최근 스캔 이력 ──
        if (_scannedCodes.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxHeight: 120),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '최근 스캔',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    reverse: true,
                    itemCount: _scannedCodes.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${index + 1}. ${_scannedCodes[index]}',
                          style: theme.textTheme.bodySmall,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 카메라 스캔 뷰 (모바일 + 웹 공통)
  Widget _buildScannerView(ThemeData theme) {
    return Stack(
      children: [
        MobileScanner(
          controller: _scannerController,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) {
            // 카메라 접근 실패 시 수동 입력으로 전환
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_cameraFailed) {
                setState(() => _cameraFailed = true);
              }
            });
            return const SizedBox.shrink();
          },
        ),

        // 스캔 가이드 오버레이
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.7),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),

        // 하단 안내 문구
        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'QR 코드를 사각형 안에 맞춰주세요',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ),
        ),

        if (_isProcessing)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  /// 웹 하단: 수동 입력 바 (카메라와 함께 표시)
  Widget _buildManualInputBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Icon(Icons.keyboard, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _manualInputCtrl,
                decoration: const InputDecoration(
                  hintText: '자산번호 직접 입력',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(),
                ),
                style: theme.textTheme.bodySmall,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onManualSubmit(),
                enabled: !_isProcessing,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: FilledButton(
              onPressed: _isProcessing ? null : _onManualSubmit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: const Text('조회'),
            ),
          ),
        ],
      ),
    );
  }

  /// 카메라 실패 시 수동 입력 전체 화면
  Widget _buildManualInput(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              '카메라에 접근할 수 없습니다.\n자산번호를 직접 입력해 주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 360,
              child: TextField(
                controller: _manualInputCtrl,
                decoration: InputDecoration(
                  labelText: '자산번호',
                  hintText: '예) BDT00001, D00123',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _isProcessing ? null : _onManualSubmit,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _onManualSubmit(),
                enabled: !_isProcessing,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 360,
              height: 48,
              child: FilledButton.icon(
                onPressed: _isProcessing ? null : _onManualSubmit,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.search),
                label: const Text('조회'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() => _cameraFailed = false);
              },
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('카메라 다시 시도'),
            ),
          ],
        ),
      ),
    );
  }
}
