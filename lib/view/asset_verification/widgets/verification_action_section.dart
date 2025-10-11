// lib/view/asset_verification/widgets/verification_action_section.dart

import 'package:flutter/material.dart';
import '../../../data/signature_storage.dart';
import '../../../providers/inspection_provider.dart' show UserInfo;
import '../signature_utils.dart';
import 'signature_pad.dart';
import 'signature_thumbnail.dart';

class VerificationActionSection extends StatefulWidget {
  const VerificationActionSection({
    super.key,
    required this.assetUids,
    this.primaryAssetUid,
    this.primaryUser,
    this.onSignaturesSaved,
  });

  final List<String> assetUids;
  final String? primaryAssetUid;
  final UserInfo? primaryUser;
  final VoidCallback? onSignaturesSaved;

  @override
  State<VerificationActionSection> createState() => _VerificationActionSectionState();
}

class _VerificationActionSectionState extends State<VerificationActionSection> {
  final GlobalKey<SignaturePadState> _signatureKey = GlobalKey<SignaturePadState>();

  bool _isSavingSignature = false;
  bool _isLoadingSignature = false;
  String? _savedSignatureLocation;
  SignatureData? _savedSignatureData;

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
              height: 200,
              width: 400,
              child: SignaturePad(key: _signatureKey),
            ),
            const SizedBox(height: 8),
            if (_isLoadingSignature)
              const Text('저장된 서명을 확인하는 중입니다...')
            else if (_savedSignatureData != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  SelectableText(
                    '저장 위치: ${_savedSignatureLocation ?? _savedSignatureData!.location}',
                  ),
                ],
              )
            else
              const Text('서명 저장 시 인증이 완료됩니다.'),
          ],
        ),
      ),
    );
  }

  void _clearSignature() {
    _signatureKey.currentState?.clear();
    setState(() {});
  }

  Future<void> _loadExistingSignature() async {
    final assetUid = widget.primaryAssetUid?.trim();
    final user = widget.primaryUser;
    if (assetUid == null || assetUid.isEmpty || user == null) {
      setState(() {
        _savedSignatureLocation = null;
        _savedSignatureData = null;
        _isLoadingSignature = false;
      });
      return;
    }

    setState(() {
      _isLoadingSignature = true;
    });

    try {
      final signature = await loadSignatureData(assetUid: assetUid, user: user);
      if (!mounted) return;
      setState(() {
        _savedSignatureLocation = signature?.location;
        _savedSignatureData = signature;
        _isLoadingSignature = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedSignatureLocation = null;
        _savedSignatureData = null;
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
    final normalizedAssetUids = <String>{
      for (final uid in widget.assetUids)
        if (uid.trim().isNotEmpty) uid.trim(),
    }.toList(growable: false);

    if (user == null ||
        user.id.trim().isEmpty ||
        user.name.trim().isEmpty ||
        normalizedAssetUids.isEmpty) {
      _showSnackBar('자산 또는 사용자 정보가 없어 서명을 저장할 수 없습니다.');
      return;
    }

    final existingChecks = await Future.wait(
      normalizedAssetUids.map(
        (uid) => signatureExists(
          assetUid: uid,
          user: user,
        ),
      ),
    );

    final alreadyVerified = <String>[];
    final pendingTargets = <String>[];
    for (var i = 0; i < normalizedAssetUids.length; i++) {
      final uid = normalizedAssetUids[i];
      if (existingChecks[i]) {
        alreadyVerified.add(uid);
      } else {
        pendingTargets.add(uid);
      }
    }

    var targets = List<String>.from(normalizedAssetUids);
    var skippedCount = 0;

    if (alreadyVerified.isNotEmpty) {
      final shouldReverify = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('재인증 확인'),
              content: const Text('인증된 자산이 있습니다. 재인증 할까요?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('아니오'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('예'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) {
        return;
      }

      if (!shouldReverify) {
        targets = pendingTargets;
        skippedCount = alreadyVerified.length;
      }
    }

    if (targets.isEmpty) {
      _showSnackBar('인증할 자산이 없습니다. (이미 인증됨)');
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
      final primaryAssetUid = widget.primaryAssetUid?.trim().toLowerCase();
      String? primarySignatureLocation;

      for (final targetUid in targets) {
        final storedSignature = await SignatureStorage.save(
          data: imageBytes,
          assetUid: targetUid,
          userName: user.name,
          employeeId: user.id,
        );

        final normalizedTarget = targetUid.toLowerCase();
        if (primaryAssetUid != null) {
          if (primaryAssetUid == normalizedTarget) {
            primarySignatureLocation = storedSignature.location;
          }
        } else if (primarySignatureLocation == null) {
          primarySignatureLocation = storedSignature.location;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isSavingSignature = false;
        if (primarySignatureLocation != null) {
          _savedSignatureLocation = primarySignatureLocation;
        }
        _savedSignatureData = null;

      });

      await _loadExistingSignature();
      widget.onSignaturesSaved?.call();

      final savedCount = targets.length;
      if (skippedCount > 0) {
        _showSnackBar('서명이 저장되어 인증이 완료되었습니다. (신규 인증 $savedCount건, 제외 $skippedCount건)');
      } else {
        _showSnackBar('서명이 저장되어 인증이 완료되었습니다. ($savedCount건)');
      }
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
              height: 200,
              width: 400,
              child: SignaturePad(key: _signatureKey),
            ),
            const SizedBox(height: 8),
            if (_isLoadingSignature)
              const Text('저장된 서명을 확인하는 중입니다...')
            else if (_savedSignatureData != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  SelectableText(
                    '저장 위치: ${_savedSignatureLocation ?? _savedSignatureData!.location}',
                  ),
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
