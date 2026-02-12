import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../main.dart';
import '../models/asset_inspection.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 5.1.8 실사 상세 화면 (/inspection/:id)
///
/// - 자산 정보 (자산번호, 사용자, 부서)
/// - 실사 정보 (건물, 층, 위치, 상태, 메모)
/// - 사진 표시 + 서명 표시
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
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

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
      setState(() {
        _inspection = inspection;
        _isLoading = false;
      });
      _populateForm(inspection);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 실사 정보 업데이트
  Future<void> _updateInspection() async {
    setState(() => _isSaving = true);

    try {
      await _api.updateInspection(widget.inspectionId, {
        'inspection_building': _buildingCtrl.text.trim(),
        'inspection_floor': _floorCtrl.text.trim(),
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
            content: Text('수정 실패: ${e.toString()}'),
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

  /// 사진 URL 취득
  String? get _photoUrl {
    final path = _inspection?.inspectionPhoto;
    if (path == null) return null;
    if (path.startsWith('http')) return path;
    return supabase.storage.from('inspections').getPublicUrl(path);
  }

  /// 서명 URL 취득
  String? get _signatureUrl {
    final path = _inspection?.signatureImage;
    if (path == null) return null;
    if (path.startsWith('http')) return path;
    return supabase.storage.from('signatures').getPublicUrl(path);
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
    final isCompleted = ins.completed;
    final readOnly = isCompleted;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 완료 상태 배너 ──
        if (isCompleted)
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
              children: [
                _infoRow('자산번호', ins.assetCode ?? '-'),
                _infoRow('자산유형', ins.assetType ?? '-'),
                _infoRow('사용자', ins.assetUserName ?? '-'),
                _infoRow('부서', ins.assetUserDepartment ?? '-'),
                _infoRow('담당자', ins.inspectorName ?? '-'),
                _infoRow('팀', ins.userTeam ?? '-'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── 실사 정보 섹션 ──
        _buildSectionTitle('실사 정보'),
        const SizedBox(height: 8),

        // 건물
        TextFormField(
          controller: _buildingCtrl,
          decoration: const InputDecoration(
            labelText: '건물',
            border: OutlineInputBorder(),
          ),
          readOnly: readOnly,
        ),
        const SizedBox(height: 12),

        // 층 + 위치
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _floorCtrl,
                decoration: const InputDecoration(
                  labelText: '층',
                  border: OutlineInputBorder(),
                ),
                readOnly: readOnly,
              ),
            ),
            const SizedBox(width: 12),
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

        // 상태
        TextFormField(
          controller: _statusCtrl,
          decoration: const InputDecoration(
            labelText: '상태',
            border: OutlineInputBorder(),
          ),
          readOnly: readOnly,
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
                _infoRow('실사 회차', '${ins.inspectionCount}'),
                _infoRow(
                    '실사일',
                    ins.inspectionDate != null
                        ? _dateFmt.format(ins.inspectionDate!)
                        : '-'),
                _infoRow('유지보수업체 담당', ins.maintenanceCompanyStaff ?? '-'),
                _infoRow('부서 확인', ins.departmentConfirm ?? '-'),
                _infoRow('동기화', ins.synced ? '완료' : '미완료'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── 사진 섹션 ──
        _buildSectionTitle('실사 사진'),
        const SizedBox(height: 8),
        if (_photoUrl != null)
          Card(
            clipBehavior: Clip.antiAlias,
            child: CachedNetworkImage(
              imageUrl: _photoUrl!,
              height: 200,
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
            ),
          )
        else
          Card(
            child: Container(
              height: 120,
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_camera,
                      size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('사진이 등록되지 않았습니다.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),

        // ── 서명 섹션 ──
        _buildSectionTitle('서명'),
        const SizedBox(height: 8),
        if (_signatureUrl != null)
          Card(
            clipBehavior: Clip.antiAlias,
            child: Container(
              color: Colors.white,
              child: CachedNetworkImage(
                imageUrl: _signatureUrl!,
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
            ),
          )
        else
          Card(
            child: Container(
              height: 100,
              width: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.draw,
                      size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('서명이 등록되지 않았습니다.',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        const SizedBox(height: 32),

        // ── 액션 버튼 ──
        if (!isCompleted) ...[
          // 저장 버튼
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

        // 사인하기 버튼
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.tonalIcon(
            onPressed: () {
              context.go('/signature', extra: {
                'inspectionId': widget.inspectionId,
              });
            },
            icon: const Icon(Icons.draw),
            label: Text(ins.signatureImage != null ? '서명 다시 하기' : '사인하기'),
          ),
        ),

        // 자산 상세 이동
        if (ins.assetId != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/asset/${ins.assetId}'),
              icon: const Icon(Icons.devices),
              label: const Text('자산 상세 보기'),
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
