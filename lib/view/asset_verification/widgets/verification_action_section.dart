import 'package:flutter/material.dart';

import '../../../data/signature_storage.dart';
import '../../../providers/inspection_provider.dart' show UserInfo;
import 'signature_pad.dart';

class VerificationActionSection extends StatefulWidget {
  const VerificationActionSection({
    super.key,
    required this.assetUids,
    this.primaryAssetUid,
    this.primaryUser,
  });

  final List<String> assetUids;
  final String? primaryAssetUid;
  final UserInfo? primaryUser;

  @override
  State<VerificationActionSection> createState() => _VerificationActionSectionState();
}

class _VerificationActionSectionState extends State<VerificationActionSection> {
  final GlobalKey<SignaturePadState> _signatureKey = GlobalKey<SignaturePadState>();

  bool _isSavingSignature = false;
  bool _isLoadingSignature = false;
  String? _savedSignaturePath;

  @override
  void initState() {
    super.initState();
    _loadExistingSignature();
  }

  @override
  void didUpdateWidget(covariant VerificationActionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final assetChanged = oldWidget.primaryAssetUid != widget.primaryAssetUid;
    final userChanged = oldWidget.primaryUser?.id != widget.primaryUser?.id || oldWidget.primaryUser?.name != widget.primaryUser?.name;
    if (assetChanged || userChanged) {
      _loadExistingSignature();
    }
  }

  void _clearSignature() {
    _signatureKey.currentState?.clear();
    setState(() {});
  }

  Future<void> _loadExistingSignature() async {
    final assetUid = widget.primaryAssetUid;
    final user = widget.primaryUser;
    if (assetUid == null || user == null) {
      setState(() {
        _savedSignaturePath = null;
        _isLoadingSignature = false;
      });
      return;
    }

    setState(() {
      _isLoadingSignature = true;
    });

    try {
      final file = await SignatureStorage.find(
        assetUid: assetUid,
        userName: user.name,
        employeeId: user.id,
      );
      if (!mounted) return;
      setState(() {
        _savedSignaturePath = file?.path;
        _isLoadingSignature = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedSignaturePath = null;
        _isLoadingSignature = false;
      });
    }
  }

  Future<void> _saveSignature() async {
    final padState = _signatureKey.currentState;
    if (padState == null || padState.isEmpty) {
      _showSnackBar('서명 입력 후 저장할 수 있습니다.');
      return;
    }

    final user = widget.primaryUser;
    final assetUid = widget.primaryAssetUid ?? (widget.assetUids.length == 1 ? widget.assetUids.first : null);
    if (user == null || assetUid == null) {
      _showSnackBar('자산 또는 사용자 정보가 없어 서명을 저장할 수 없습니다.');
      return;
    }

    final imageBytes = await padState.exportImage();
    if (imageBytes == null) {
      _showSnackBar('서명 이미지를 생성하지 못했습니다. 다시 시도해주세요.');
      return;
    }

    setState(() {
      _isSavingSignature = true;
    });

    try {
      final file = await SignatureStorage.save(
        data: imageBytes,
        assetUid: assetUid,
        userName: user.name,
        employeeId: user.id,
      );
      if (!mounted) return;
      setState(() {
        _savedSignaturePath = file.path;
        _isSavingSignature = false;
      });
      _showSnackBar('서명이 저장되어 인증이 완료되었습니다. (${file.path})');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingSignature = false;
      });
      _showSnackBar('서명 저장 중 오류가 발생했습니다. ${error.toString()}');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assetCount = widget.assetUids.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '사인란',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 12),
                Text(' 인증처리 할 선택 자산: $assetCount건'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _clearSignature,
                  icon: const Icon(Icons.refresh),
                  label: const Text('서명 다시하기'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSavingSignature ? null : _saveSignature,
                  icon: _isSavingSignature
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_alt),
                  label: Text(_isSavingSignature ? '저장 중...' : '서명 저장'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: SignaturePad(key: _signatureKey),
            ),
            const SizedBox(height: 8),
            if (_isLoadingSignature)
              const Text('저장된 서명을 확인하는 중입니다...')
            else if (_savedSignaturePath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    avatar: const Icon(
                      Icons.verified_outlined,
                      color: Colors.white,
                    ),
                    backgroundColor: Colors.green,
                    label: const Text(
                      '인증 완료',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText('저장 위치: $_savedSignaturePath'),
                ],
              )
            else
              const Text('서명 저장 시 인증이 완료됩니다.'),
          ],
        ),
      ),
    );
  }
}
