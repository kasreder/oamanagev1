// lib/view/asset_verification/widgets/verification_action_section.dart

import 'package:flutter/material.dart';

import '../../../data/signature_storage.dart';
import '../../../models/user_info.dart';
import '../signature_utils.dart';
import 'signature_pad.dart';

class VerificationActionSection extends StatefulWidget {
  const VerificationActionSection({
    super.key,
    required this.assetUids,
    this.primaryAssetUid,
    this.primaryUser,
    this.onSignaturesSaved,
    this.assetUsers = const {},
  });

  final List<String> assetUids;
  final String? primaryAssetUid;
  final UserInfo? primaryUser;
  final VoidCallback? onSignaturesSaved;
  final Map<String, UserInfo?> assetUsers;

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

    final resolvedTargets = _resolveTargets();

    if (resolvedTargets.isEmpty) {
      _showSnackBar('자산 또는 사용자 정보가 없어 서명을 저장할 수 없습니다.');
      return;
    }

    final hasInvalidUser = resolvedTargets.any(
      (target) =>
          target.user == null ||
          target.user!.id.trim().isEmpty ||
          target.user!.name.trim().isEmpty,
    );

    if (hasInvalidUser) {
      _showSnackBar('자산 또는 사용자 정보가 없어 서명을 저장할 수 없습니다.');
      return;
    }

    if (_hasMultipleUsers(resolvedTargets)) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('사용자 확인 필요'),
              content: const Text('사용자가 여러명입니다. 실사용자와 인증자 확인후 진행해주세요'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('확인했습니다'),
                ),
              ],
            ),
          ) ??
          false;

      if (!mounted) {
        return;
      }

      if (!confirmed) {
        return;
      }
    }

    final existingChecks = await Future.wait(
      resolvedTargets.map(
        (target) => signatureExists(
          assetUid: target.assetUid,
          user: target.user,
        ),
      ),
    );

    final alreadyVerified = <_AssetSignatureTarget>[];
    final pendingTargets = <_AssetSignatureTarget>[];
    for (var i = 0; i < resolvedTargets.length; i++) {
      final target = resolvedTargets[i];
      if (existingChecks[i]) {
        alreadyVerified.add(target);
      } else {
        pendingTargets.add(target);
      }
    }

    var targets = List<_AssetSignatureTarget>.from(resolvedTargets);
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

      for (final target in targets) {
        final targetUser = target.user!;
        final storedSignature = await SignatureStorage.save(
          data: imageBytes,
          assetUid: target.assetUid,
          userName: targetUser.name,
          employeeId: targetUser.id,
        );

        final normalizedTarget = target.assetUid.toLowerCase();
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

  List<_AssetSignatureTarget> _resolveTargets() {
    final seen = <String>{};
    final targets = <_AssetSignatureTarget>[];
    for (final rawUid in widget.assetUids) {
      final normalizedUid = rawUid.trim();
      if (normalizedUid.isEmpty) {
        continue;
      }
      final user = _resolveUserForAsset(normalizedUid);
      final targetKey = '${normalizedUid.toLowerCase()}::${_userKey(user)}';
      if (seen.add(targetKey)) {
        targets.add(
          _AssetSignatureTarget(
            assetUid: normalizedUid,
            user: user,
          ),
        );
      }
    }
    return targets;
  }

  UserInfo? _userForAsset(String assetUid) {
    final normalized = assetUid.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final candidates = <UserInfo?>[
      widget.assetUsers[normalized],
      widget.assetUsers[normalized.toLowerCase()],
      widget.assetUsers[normalized.toUpperCase()],
      widget.assetUsers[assetUid],
    ];

    for (final candidate in candidates) {
      if (candidate != null) {
        return candidate;
      }
    }

    return null;
  }

  UserInfo? _resolveUserForAsset(String assetUid) {
    return _userForAsset(assetUid) ?? widget.primaryUser;
  }

  bool _hasMultipleUsers(List<_AssetSignatureTarget> targets) {
    final userKeys = <String>{};
    for (final target in targets) {
      userKeys.add(_userKey(target.user));
    }
    return userKeys.length > 1;
  }

  String _userKey(UserInfo? user) {
    if (user == null) {
      return '__unknown__';
    }
    final normalizedId = user.id.trim().toLowerCase();
    final normalizedName = user.name.trim();
    if (normalizedId.isEmpty && normalizedName.isEmpty) {
      return '__unknown__';
    }
    return '$normalizedId::$normalizedName';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _AssetSignatureTarget {
  const _AssetSignatureTarget({
    required this.assetUid,
    required this.user,
  });

  final String assetUid;
  final UserInfo? user;
}
