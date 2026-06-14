import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants.dart';
import '../main.dart';
import '../models/asset_inspection.dart';
import '../models/inspection_round.dart';
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../utils/temp_file_cleaner.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 5.1.8 실사 상세 화면 (/inspection/:id)
///
/// - 자산 정보 (자산번호, 사용자, 부서)
/// - 실사 정보 (건물, 층, 위치, 상태, 메모)
/// - 사진 촬영/표시 + 서명 표시
/// - 완료건 (completed=true): 읽기 전용
/// - [사인하기] 버튼 -> /signature (extra: inspectionId)
class InspectionDetailPage extends ConsumerStatefulWidget {
  final int inspectionId;

  const InspectionDetailPage({
    super.key,
    required this.inspectionId,
  });

  @override
  ConsumerState<InspectionDetailPage> createState() =>
      _InspectionDetailPageState();
}

class _InspectionDetailPageState extends ConsumerState<InspectionDetailPage> {
  final ApiService _api = ApiService();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd HH:mm');

  AssetInspection? _inspection;
  InspectionRound? _activeRound;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isLocking = false;
  bool _isUploadingPhoto = false;
  String? _error;

  // Signed URL 캐시
  String? _photoSignedUrl;
  String? _signatureSignedUrl;

  // 편집 가능한 필드 컨트롤러
  late TextEditingController _buildingCtrl;
  late TextEditingController _floorCtrl;
  late TextEditingController _positionCtrl;
  late TextEditingController _memoCtrl;
  late TextEditingController _statusCtrl;

  @override
  void initState() {
    super.initState();
    _buildingCtrl = TextEditingController();
    _floorCtrl = TextEditingController();
    _positionCtrl = TextEditingController();
    _memoCtrl = TextEditingController();
    _statusCtrl = TextEditingController();
    _loadInspection();
  }

  @override
  void dispose() {
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _positionCtrl.dispose();
    _memoCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  void _populateForm(AssetInspection ins) {
    _buildingCtrl.text = ins.inspectionBuilding ?? '';
    _floorCtrl.text = ins.inspectionFloor ?? '';
    _positionCtrl.text = ins.inspectionPosition ?? '';
    _memoCtrl.text = ins.memo ?? '';
    _statusCtrl.text = ins.status ?? '';
  }

  Future<void> _loadInspection() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final inspection = await _api.fetchInspection(widget.inspectionId);
      final activeRound = await _api.fetchActiveRound();
      setState(() {
        _inspection = inspection;
        _activeRound = activeRound;
        _isLoading = false;
      });
      _populateForm(inspection);
      await _loadSignedUrls(inspection);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 사진/서명 Signed URL 로드 (private 버킷용)
  Future<void> _loadSignedUrls(AssetInspection ins) async {
    String? photoUrl;
    String? sigUrl;

    // 사진 URL
    final photoPath = ins.inspectionPhoto;
    if (photoPath != null) {
      if (photoPath.startsWith('http')) {
        photoUrl = photoPath;
      } else {
        try {
          photoUrl = await supabase.storage
              .from('inspection-photos')
              .createSignedUrl(photoPath, 3600);
        } catch (_) {}
      }
    }

    // 서명 URL
    final sigPath = ins.signatureImage;
    if (sigPath != null) {
      if (sigPath.startsWith('http')) {
        sigUrl = sigPath;
      } else {
        try {
          sigUrl = await supabase.storage
              .from('inspection-signatures')
              .createSignedUrl(sigPath, 3600);
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        _photoSignedUrl = photoUrl;
        _signatureSignedUrl = sigUrl;
      });
    }
  }

  /// 실사 정보 업데이트
  Future<void> _updateInspection() async {
    setState(() => _isSaving = true);

    try {
      // 건물/층은 자산 마스터(assets.building/floor) 기준값을 그대로 저장 — UI 입력 없음
      final ins = _inspection;
      await _api.updateInspection(widget.inspectionId, {
        'inspection_building': ins?.assetBuilding,
        'inspection_floor': ins?.assetFloor,
        'inspection_position': _positionCtrl.text.trim(),
        'status': _statusCtrl.text.trim(),
        'memo': _memoCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('실사 정보가 수정되었습니다.')),
        );
        _loadInspection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('수정 실패: ${e.toString()}'),
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

  /// N차 등록 — 잠금
  Future<void> _lockInspection() async {
    final round = _activeRound?.round;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(round != null ? '${round}차 등록' : '실사 등록'),
        content: const Text(
          '등록 후에는 일반 사용자가 수정할 수 없습니다. 계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('등록')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLocking = true);
    try {
      await _api.setInspectionLocked(widget.inspectionId, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록되었습니다.')),
        );
        _loadInspection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('등록 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocking = false);
    }
  }

  void _navigateToSignature() {
    context.go('/signature', extra: {'inspectionId': widget.inspectionId});
  }

  /// 사진 재등록 — DB+Storage 모두 삭제 후 _loadInspection. (확인 다이얼로그)
  Future<void> _resetInspectionPhoto() async {
    if (_inspection?.inspectionPhoto == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('실사 사진 재등록'),
        content: const Text(
          '기존 사진을 데이터베이스와 스토리지에서 모두 삭제하고 새로 등록합니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('재등록')),
        ],
      ),
    );
    if (ok != true) return;
    final path = _inspection!.inspectionPhoto!;
    try {
      // Storage 삭제 → DB 컬럼 NULL → 새 촬영 트리거
      try {
        await Supabase.instance.client.storage.from('inspection-photos').remove([path]);
      } catch (_) { /* 이미 없는 파일이면 무시 */ }
      await _api.updateInspection(widget.inspectionId, {'inspection_photo': null});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기존 사진을 삭제했습니다. 다시 촬영하세요.')),
      );
      await _loadInspection();
      if (mounted) await _captureAndUploadPhoto();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('사진 재등록 실패: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// 서명 재등록 — DB+Storage 모두 삭제 후 서명 페이지로 이동. (확인 다이얼로그)
  Future<void> _resetInspectionSignature() async {
    if (_inspection?.signatureImage == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서명 재등록'),
        content: const Text(
          '기존 서명을 데이터베이스와 스토리지에서 모두 삭제하고 새로 등록합니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('재등록')),
        ],
      ),
    );
    if (ok != true) return;
    final path = _inspection!.signatureImage!;
    try {
      try {
        await Supabase.instance.client.storage.from('inspection-signatures').remove([path]);
      } catch (_) { /* 이미 없는 파일이면 무시 */ }
      await _api.updateInspection(widget.inspectionId, {'signature_image': null});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기존 서명을 삭제했습니다. 다시 서명하세요.')),
      );
      await _loadInspection();
      if (mounted) _navigateToSignature();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('서명 재등록 실패: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// 재실사 진행 — 사진/사인/위치 비우고 다시 실사 가능 상태로 (등록취소된 자산 전용)
  Future<void> _startRecheck() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('재실사 진행'),
        content: const Text(
          '기존 실사 사진/서명/위치/메모/상태를 비우고 처음부터 다시 진행합니다.\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('진행')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.updateInspection(widget.inspectionId, {
        'inspection_photo': null,
        'signature_image': null,
        'inspection_position': null,
        'memo': null,
        'status': null,
        'inspection_date': null,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재실사 모드로 전환되었습니다.')),
      );
      _loadInspection();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('재실사 진행 실패: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// 재실사 요청 — 마스터 관리자에게 알림 발송 (관리자가 직접 등록취소해야 잠금 해제)
  Future<void> _requestRecheck() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('재실사 요청'),
        content: const Text(
          '마스터 관리자에게 재실사 요청 알림이 전송됩니다.\n'
          '관리자가 등록을 취소해야 다시 실사할 수 있습니다.\n\n계속하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('요청')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'request_inspection_recheck',
        params: {'p_inspection_id': widget.inspectionId},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재실사 요청이 전송되었습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: SelectableText('재실사 요청 실패: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// N차 등록취소 — 잠금 해제 (admin만)
  Future<void> _unlockInspection() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('등록 취소'),
        content: const Text('등록을 취소하면 다시 수정 가능 상태가 됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니오')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('등록취소')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isLocking = true);
    try {
      await _api.setInspectionLocked(widget.inspectionId, false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('등록이 취소되었습니다.')),
        );
        _loadInspection();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('취소 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocking = false);
    }
  }

  /// 사진 촬영 및 업로드
  Future<void> _captureAndUploadPhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      maxHeight: 960,
      imageQuality: 70,
    );
    if (photo == null) return;

    setState(() => _isUploadingPhoto = true);

    String? uploadedPath;
    try {
      final now = DateTime.now();
      final assetCode = _inspection?.assetCode ?? 'UNKNOWN';
      final roundNum = _inspection?.roundId ?? 0;
      final timestamp = DateFormat('yyyyMMdd_HHmm').format(now);
      final storagePath = '$roundNum/photos/${assetCode}_detail_${timestamp}_$roundNum.jpg';

      final bytes = await photo.readAsBytes();

      await supabase.storage.from('inspection-photos').uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      uploadedPath = storagePath;

      // 임시 파일 삭제
      await TempFileCleaner.delete(photo.path);

      // inspection 레코드에 사진 경로 업데이트
      await _api.updateInspection(widget.inspectionId, {
        'inspection_photo': storagePath,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진이 저장되었습니다.')),
        );
        _loadInspection();
      }
    } catch (e) {
      // 고아파일 삭제: Storage 업로드 성공 후 DB 실패 시
      if (uploadedPath != null) {
        try {
          await supabase.storage.from('inspection-photos').remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('사진 저장 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '실사 상세',
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '실사 정보를 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadInspection);
    }
    if (_inspection == null) {
      return const AppErrorWidget(message: '실사 정보를 찾을 수 없습니다.');
    }

    final theme = Theme.of(context);
    final ins = _inspection!;
    // 완료(5필드 충족)는 상태 표시용. 수정 잠금은 locked 기준 단일화 —
    // 관리자가 [등록취소]를 누르면 locked=false가 되어 즉시 편집 가능 + 버튼이 "n차 등록"으로 바뀜.
    final isCompleted = ins.completed;
    final readOnly = ins.locked;

    // 권한
    final authState = ref.read(authNotifierProvider);
    final currentUser = authState.valueOrNull?.user;
    final isAdminGroup = currentUser?.isAdminGroup ?? false;
    final isAdmin = currentUser?.isAdmin ?? false;
    final canCapture = isAdminGroup || _activeRound != null;

    // N차 등록 라벨용 — 이 inspection이 속한 라운드 번호(view에서 평탄화) 우선
    final roundNumber = ins.roundRound ?? _activeRound?.round;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 라운드 정보 배너 ──
        if (_activeRound != null)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_activeRound!.title}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        if (!canCapture && !isCompleted)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '진행 중인 실사가 없어 사진/서명을 등록할 수 없습니다.',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),

        // ── 완료 상태 배너 — N차 등록(locked=true)일 때만 표시 ──
        if (ins.locked)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
                const SizedBox(width: 8),
                Text(
                  '실사 완료',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

        // ── 자산 정보 섹션 ──
        _buildSectionTitle('자산 정보'),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoRow('자산번호', ins.assetAssetUid ?? ins.assetCode ?? '-'),
                _infoRow('자산유형', ins.assetType ?? ins.assetCategory ?? '-'),
                _infoRow('실사용자', ins.assetUserName ?? '-'),
                _infoRow('사용자부서', ins.assetUserDepartment ?? '-'),
                _infoRow('담당자', ins.assetAdminName ?? '-'),
                _infoRow('담당자부서', ins.assetAdminDepartment ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── 실사 정보 섹션 ──
        _buildSectionTitle('실사 정보'),
        const SizedBox(height: 8),

        // 건물 / 층 — 자산 마스터(assets) 값 표시. 수정 불가.
        Row(
          children: [
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '건물 (자산기준)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(ins.assetBuilding ?? '-'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '층 (자산기준)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(ins.assetFloor ?? '-'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 위치 — 실사 자체에서 별도 관리
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _positionCtrl,
                decoration: const InputDecoration(
                  labelText: '위치',
                  border: OutlineInputBorder(),
                ),
                readOnly: readOnly,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 상태 (위치/메모 사이)
        DropdownButtonFormField<String>(
          value: inspectionStatusOptions.contains(_statusCtrl.text)
              ? _statusCtrl.text
              : null,
          decoration: const InputDecoration(
            labelText: '상태',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('-')),
            ...inspectionStatusOptions.map(
              (s) => DropdownMenuItem(value: s, child: Text(s)),
            ),
          ],
          onChanged: readOnly
              ? null
              : (v) => setState(() => _statusCtrl.text = v ?? ''),
        ),
        const SizedBox(height: 12),

        // 메모
        TextFormField(
          controller: _memoCtrl,
          decoration: const InputDecoration(
            labelText: '메모',
            border: OutlineInputBorder(),
          ),
          readOnly: readOnly,
          maxLines: 3,
        ),
        const SizedBox(height: 12),

        // 추가 정보
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(
                  '실사 회차',
                  (ins.roundYear != null && ins.roundRound != null)
                      ? '${(ins.roundYear! % 100).toString().padLeft(2, '0')}년 ${ins.roundRound}차'
                      : '${ins.inspectionCount}차',
                ),
                _infoRow(
                    '실사일',
                    ins.inspectionDate != null
                        ? _dateFmt.format(ins.inspectionDate!)
                        : '-'),
                _infoRow('확인 ID', ins.maintenanceCompanyStaff ?? '-'),
                _infoRow('부서 확인', ins.departmentConfirm ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── 사진/서명 섹션 — 데스크탑(>=720): 좌우 배치(각 폭 = 전체/2), 모바일: 세로 배치 ──
        LayoutBuilder(
          builder: (ctx, c) {
            final isWide = c.maxWidth >= 720;
            final photoCard = _buildPhotoCard(theme, canCapture, isCompleted, readOnly);
            final signatureCard = _buildSignatureCard(theme, canCapture, readOnly);
            if (isWide) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: photoCard),
                  const SizedBox(width: 12),
                  Expanded(child: signatureCard),
                ],
              );
            }
            return Column(
              children: [
                photoCard,
                const SizedBox(height: 12),
                signatureCard,
              ],
            );
          },
        ),
        const SizedBox(height: 32),

        // ── 액션 버튼 ── 순서: 사인하기 → 저장 → 자산상세 → N차 등록/취소

        // 1) 사인하기 — 서명 미등록 시에만 노출. 재등록은 서명 카드 내 [서명 재등록] 사용.
        if (canCapture && !readOnly && ins.signatureImage == null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.tonalIcon(
              onPressed: _navigateToSignature,
              icon: const Icon(Icons.draw),
              label: const Text('사인하기'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 2) 저장 (잠금 아닐 때 — admin은 잠금이어도 가능)
        if (!readOnly || isAdmin) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _updateInspection,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: const Text('저장'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3) 자산 상세 이동
        if (ins.assetId != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/asset/${ins.assetId}'),
              icon: const Icon(Icons.devices),
              label: const Text('자산 상세 보기'),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 4) 잠금된 실사 → [N차 등록 완료됨] disabled + [재실사 요청] + (admin) [등록취소]
        if (ins.locked) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check_circle),
              label: Text(
                roundNumber != null
                    ? '${roundNumber}차 등록 완료됨'
                    : '실사 등록 완료됨',
              ),
              style: FilledButton.styleFrom(
                disabledBackgroundColor:
                    theme.colorScheme.primaryContainer,
                disabledForegroundColor:
                    theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _requestRecheck,
              icon: const Icon(Icons.replay),
              label: const Text('재실사 요청'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(color: theme.colorScheme.error),
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton.icon(
                onPressed: _unlockInspection,
                icon: const Icon(Icons.lock_open, size: 18),
                label: Text(
                  roundNumber != null
                      ? '${roundNumber}차 등록취소 (관리자)'
                      : '실사 등록취소 (관리자)',
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '재실사 요청 시 마스터 관리자가 등록취소해야 다시 수정할 수 있습니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ] else if (_activeRound != null) ...[
          // 활성 라운드가 있을 때만 등록 가능
          //  - 5필드 충족(isCompleted=true) → "n차 재실사 진행" (등록취소 후 재실사)
          //  - 5필드 미충족 → "n차 실사등록완료" (lock=true)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _isLocking
                  ? null
                  : (isCompleted ? _startRecheck : _lockInspection),
              icon: _isLocking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isCompleted ? Icons.replay : Icons.lock),
              label: Text(
                isCompleted
                    ? (roundNumber != null
                        ? '${roundNumber}차 재실사 진행'
                        : '재실사 진행')
                    : (roundNumber != null
                        ? '${roundNumber}차 실사등록완료'
                        : '실사 등록완료'),
              ),
              style: isCompleted
                  ? FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.tertiary,
                      foregroundColor: theme.colorScheme.onTertiary,
                    )
                  : null,
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildPhotoCard(
      ThemeData theme, bool canCapture, bool isCompleted, bool readOnly) {
    final has = _photoSignedUrl != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(
          has ? Icons.photo : Icons.photo_camera,
          color: has ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text('실사 사진',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          has ? '등록됨' : '미등록',
          style: theme.textTheme.bodySmall?.copyWith(
            color: has ? Colors.green : theme.colorScheme.outline,
          ),
        ),
        children: [
          if (has)
            CachedNetworkImage(
              imageUrl: _photoSignedUrl!,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (_, __, ___) => SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image,
                          color: theme.colorScheme.outline, size: 32),
                      const SizedBox(height: 4),
                      Text('이미지를 불러올 수 없습니다.',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.photo_camera,
                      size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('사진이 등록되지 않았습니다.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          // 사진 촬영 / 재등록 버튼
          if (!isCompleted && canCapture && !readOnly)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed:
                      _isUploadingPhoto ? null : _captureAndUploadPhoto,
                  icon: _isUploadingPhoto
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  label: const Text('사진 촬영'),
                ),
              ),
            ),
          if (has && !readOnly && canCapture)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetInspectionPhoto,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('사진 재등록'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSignatureCard(
      ThemeData theme, bool canCapture, bool readOnly) {
    final has = _signatureSignedUrl != null;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(
          has ? Icons.draw : Icons.draw_outlined,
          color: has ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text('서명',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(
          has ? '등록됨' : '미등록',
          style: theme.textTheme.bodySmall?.copyWith(
            color: has ? Colors.green : theme.colorScheme.outline,
          ),
        ),
        children: [
          if (has)
            Container(
              color: Colors.white,
              child: CachedNetworkImage(
                imageUrl: _signatureSignedUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => SizedBox(
                  height: 160,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            color: theme.colorScheme.outline, size: 32),
                        const SizedBox(height: 4),
                        Text('서명을 불러올 수 없습니다.',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.draw,
                      size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('서명이 등록되지 않았습니다.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          if (has && !readOnly && canCapture)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _resetInspectionSignature,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('서명 재등록'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    side: BorderSide(color: theme.colorScheme.error),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
