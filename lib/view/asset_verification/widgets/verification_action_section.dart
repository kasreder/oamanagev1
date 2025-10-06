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
  final TextEditingController _noteController = TextEditingController();
  final GlobalKey<SignaturePadState> _signatureKey = GlobalKey<SignaturePadState>();

  bool _isSavingSignature = false;
  bool _isLoadingSignature = false;
  String? _savedSignaturePath;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadExistingSignature();
  }

  @override
  void didUpdateWidget(covariant VerificationActionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final assetChanged = oldWidget.primaryAssetUid != widget.primaryAssetUid;
    final userChanged = oldWidget.primaryUser?.id != widget.primaryUser?.id ||
        oldWidget.primaryUser?.name != widget.primaryUser?.name;
    if (assetChanged || userChanged) {
      _loadExistingSignature();
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('인증 기능이 준비 중입니다.'),
      ),
    );
  }

  void _clear() {
    _noteController.clear();
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
      _showSnackBar('서명이 저장되었습니다. (${file.path})');
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '인증 처리',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('선택된 자산: $assetCount건'),
            const SizedBox(height: 12),
            Text(
              '자필 서명 (필압 지원)',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: SignaturePad(key: _signatureKey),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    _signatureKey.currentState?.clear();
                    setState(() {});
                  },
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
            if (_isLoadingSignature)
              const Text('저장된 서명을 확인하는 중입니다...')
            else if (_savedSignaturePath != null)
              SelectableText('저장 위치: $_savedSignaturePath')
            else
              const Text('저장된 서명이 없습니다.'),
            const SizedBox(height: 4),
            const Text(
              '※ 서명 이미지는 임시로 assets/dummy/sign 폴더에 저장됩니다.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '비고',
                hintText: '인증 관련 메모를 입력하세요.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.verified_outlined),
                  label: const Text('인증 완료 처리'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.clear),
                  label: const Text('입력 초기화'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '※ 실제 인증 절차 연동 전까지는 알림 메시지만 표시됩니다.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
