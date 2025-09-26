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
  bool _isProcessing = false;
  String? _permissionError;
  // TODO: 카메라 라이트 토글/전면카메라 전환 버튼 제공

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || capture.barcodes.isEmpty) {
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
      final inspection = Inspection(
        id: 'ins_${DateTime.now().microsecondsSinceEpoch}',
        assetUid: assetUid,
        status: '사용',
        memo: '스캔 등록',
        scannedAt: DateTime.now(),
        synced: false,
      );
      final provider = context.read<InspectionProvider>();
      provider.addOrUpdate(inspection);
      if (mounted) {
        context.go('/inspection/${inspection.id}');
      }
    } catch (error) {
      _isProcessing = false;
      _showError('QR 파싱 실패: $error');
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
                return Center(
                  child: Text('카메라 오류: ${error.errorDescription ?? error.errorCode.name}'),
                );
              },
            ),
          ),
          if (_permissionError != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.no_photography, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _permissionError!,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Text(
                  kIsWeb
                      ? '카메라 접근을 허용했는지 확인하세요.'
                      : 'QR 코드를 뷰파인더 중앙에 맞춰주세요.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 8)]),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
