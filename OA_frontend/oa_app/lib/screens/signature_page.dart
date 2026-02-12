import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

import '../constants.dart';
import '../main.dart';
import '../services/api_service.dart';

/// 5.1.9 친필 서명 화면 (/signature)
///
/// - 전체 화면 서명 패드 (signature 패키지)
/// - 완료 시 서명 이미지 업로드 -> inspection 업데이트 -> pop
class SignaturePage extends ConsumerStatefulWidget {
  final int? inspectionId;

  const SignaturePage({
    super.key,
    this.inspectionId,
  });

  @override
  ConsumerState<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends ConsumerState<SignaturePage> {
  final ApiService _api = ApiService();
  late final SignatureController _signatureCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _signatureCtrl = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
      exportPenColor: Colors.black,
    );
  }

  @override
  void dispose() {
    _signatureCtrl.dispose();
    super.dispose();
  }

  /// 서명 완료 처리
  Future<void> _onComplete() async {
    if (_signatureCtrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('서명을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 서명 이미지를 PNG로 내보내기
      final data = await _signatureCtrl.toPngBytes(
        height: signaturePadSize.toInt(),
        width: signaturePadSize.toInt(),
      );

      if (data == null) {
        throw Exception('서명 이미지 생성 실패');
      }

      // Supabase Storage에 업로드
      final fileName =
          'signatures/${widget.inspectionId ?? 'temp'}_${DateTime.now().millisecondsSinceEpoch}.png';

      await supabase.storage.from('signatures').uploadBinary(
            fileName,
            data,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: true,
            ),
          );

      // inspection 레코드 업데이트
      if (widget.inspectionId != null) {
        await _api.updateInspection(widget.inspectionId!, {
          'signature_image': fileName,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('서명이 저장되었습니다.')),
        );

        // 이전 화면으로 복귀
        if (widget.inspectionId != null) {
          context.go('/inspection/${widget.inspectionId}');
        } else {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('서명 저장 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 전체 화면 서명 모드 (AppScaffold 사용하지 않음)
    return Scaffold(
      appBar: AppBar(
        title: const Text('서명'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (widget.inspectionId != null) {
              context.go('/inspection/${widget.inspectionId}');
            } else {
              context.pop();
            }
          },
        ),
        actions: [
          // 지우기 버튼
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: () => _signatureCtrl.undo(),
            tooltip: '실행 취소',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _signatureCtrl.clear(),
            tooltip: '전체 지우기',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── 안내 문구 ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Text(
              '아래 영역에 서명을 입력해 주세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // ── 서명 패드 ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _signatureCtrl,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),

          // ── 완료 버튼 ──
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 32),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _onComplete,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text(
                  '서명 완료',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
