import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../constants.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';

/// 5.1.5 자산 상세/등록 화면 (/asset/:id, /asset/new)
///
/// - 같은 위젯, isCreateMode로 분기
/// - 모든 자산 필드 표시/편집
/// - QR코드 표시 (qr_flutter)
/// - 저장/수정/삭제 버튼
/// - 생성 모드: 저장 후 /asset/:newId 이동
/// - 상세 모드: 편집/삭제 가능, [실사 등록] 버튼
class AssetDetailPage extends ConsumerStatefulWidget {
  final bool isCreateMode;
  final int? assetId;
  final String? initialAssetUid;

  const AssetDetailPage({
    super.key,
    this.isCreateMode = false,
    this.assetId,
    this.initialAssetUid,
  });

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isEditing = false;
  String? _error;
  Asset? _asset;

  // 폼 컨트롤러
  late TextEditingController _assetUidCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _serialNumberCtrl;
  late TextEditingController _modelNameCtrl;
  late TextEditingController _vendorCtrl;
  late TextEditingController _networkCtrl;
  late TextEditingController _macAddressCtrl;
  late TextEditingController _buildingCtrl;
  late TextEditingController _floorCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _ownerDeptCtrl;
  late TextEditingController _userNameCtrl;
  late TextEditingController _userDeptCtrl;
  late TextEditingController _adminNameCtrl;
  late TextEditingController _adminDeptCtrl;
  late TextEditingController _normalCommentCtrl;
  late TextEditingController _oaCommentCtrl;

  String _selectedCategory = assetCategories.first;
  String _selectedStatus = assetStatuses.first;
  String _selectedSupplyType = supplyTypes.first;
  DateTime? _supplyEndDate;

  @override
  void initState() {
    super.initState();
    _initControllers();

    if (widget.isCreateMode) {
      _isEditing = true;
      if (widget.initialAssetUid != null) {
        _assetUidCtrl.text = widget.initialAssetUid!;
      }
    } else if (widget.assetId != null) {
      _loadAsset();
    }
  }

  void _initControllers() {
    _assetUidCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _serialNumberCtrl = TextEditingController();
    _modelNameCtrl = TextEditingController();
    _vendorCtrl = TextEditingController();
    _networkCtrl = TextEditingController();
    _macAddressCtrl = TextEditingController();
    _buildingCtrl = TextEditingController();
    _floorCtrl = TextEditingController();
    _ownerNameCtrl = TextEditingController();
    _ownerDeptCtrl = TextEditingController();
    _userNameCtrl = TextEditingController();
    _userDeptCtrl = TextEditingController();
    _adminNameCtrl = TextEditingController();
    _adminDeptCtrl = TextEditingController();
    _normalCommentCtrl = TextEditingController();
    _oaCommentCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _assetUidCtrl.dispose();
    _nameCtrl.dispose();
    _serialNumberCtrl.dispose();
    _modelNameCtrl.dispose();
    _vendorCtrl.dispose();
    _networkCtrl.dispose();
    _macAddressCtrl.dispose();
    _buildingCtrl.dispose();
    _floorCtrl.dispose();
    _ownerNameCtrl.dispose();
    _ownerDeptCtrl.dispose();
    _userNameCtrl.dispose();
    _userDeptCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminDeptCtrl.dispose();
    _normalCommentCtrl.dispose();
    _oaCommentCtrl.dispose();
    super.dispose();
  }

  /// 자산 데이터를 폼 컨트롤러에 반영
  void _populateForm(Asset asset) {
    _assetUidCtrl.text = asset.assetUid;
    _nameCtrl.text = asset.name ?? '';
    _serialNumberCtrl.text = asset.serialNumber ?? '';
    _modelNameCtrl.text = asset.modelName ?? '';
    _vendorCtrl.text = asset.vendor ?? '';
    _networkCtrl.text = asset.network ?? '';
    _macAddressCtrl.text = asset.macAddress ?? '';
    _buildingCtrl.text = asset.building ?? '';
    _floorCtrl.text = asset.floor ?? '';
    _ownerNameCtrl.text = asset.ownerName ?? '';
    _ownerDeptCtrl.text = asset.ownerDepartment ?? '';
    _userNameCtrl.text = asset.userName ?? '';
    _userDeptCtrl.text = asset.userDepartment ?? '';
    _adminNameCtrl.text = asset.adminName ?? '';
    _adminDeptCtrl.text = asset.adminDepartment ?? '';
    _normalCommentCtrl.text = asset.normalComment ?? '';
    _oaCommentCtrl.text = asset.oaComment ?? '';

    _selectedCategory = assetCategories.contains(asset.category)
        ? asset.category
        : assetCategories.first;
    _selectedStatus = assetStatuses.contains(asset.assetsStatus)
        ? asset.assetsStatus
        : assetStatuses.first;
    _selectedSupplyType = supplyTypes.contains(asset.supplyType)
        ? asset.supplyType
        : supplyTypes.first;
    _supplyEndDate = asset.supplyEndDate;
  }

  Future<void> _loadAsset() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final asset = await _api.fetchAsset(widget.assetId!);
      setState(() {
        _asset = asset;
        _isLoading = false;
      });
      _populateForm(asset);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 자산 저장 (생성/수정)
  Future<void> _saveAsset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'asset_uid': _assetUidCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'category': _selectedCategory,
        'assets_status': _selectedStatus,
        'supply_type': _selectedSupplyType,
        'serial_number': _serialNumberCtrl.text.trim(),
        'model_name': _modelNameCtrl.text.trim(),
        'vendor': _vendorCtrl.text.trim(),
        'network': _networkCtrl.text.trim(),
        'mac_address': _macAddressCtrl.text.trim(),
        'building': _buildingCtrl.text.trim(),
        'floor': _floorCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'owner_department': _ownerDeptCtrl.text.trim(),
        'user_name': _userNameCtrl.text.trim(),
        'user_department': _userDeptCtrl.text.trim(),
        'admin_name': _adminNameCtrl.text.trim(),
        'admin_department': _adminDeptCtrl.text.trim(),
        'normal_comment': _normalCommentCtrl.text.trim(),
        'oa_comment': _oaCommentCtrl.text.trim(),
        if (_supplyEndDate != null)
          'supply_end_date': _supplyEndDate!.toIso8601String(),
      };

      if (widget.isCreateMode) {
        final newAsset = await _api.createAsset(data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('자산이 등록되었습니다.')),
          );
          context.go('/asset/${newAsset.id}');
        }
      } else {
        await _api.updateAsset(widget.assetId!, data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('자산이 수정되었습니다.')),
          );
          setState(() => _isEditing = false);
          _loadAsset();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: ${e.toString()}'),
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

  /// 자산 삭제
  Future<void> _deleteAsset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자산 삭제'),
        content: const Text('이 자산을 삭제하시겠습니까?\n삭제된 데이터는 복구할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteAsset(widget.assetId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자산이 삭제되었습니다.')),
        );
        context.go('/assets');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('삭제 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 날짜 선택기
  Future<DateTime?> _pickDate(DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
  }

  /// 실사 등록 (자산 상세 모드에서)
  Future<void> _createInspection() async {
    try {
      final inspection = await _api.createInspection({
        'asset_id': widget.assetId,
        'asset_code': _asset?.assetUid,
        'asset_type': _asset?.category,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('실사가 등록되었습니다.')),
        );
        context.go('/inspection/${inspection.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('실사 등록 실패: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isCreateMode ? '자산 등록' : '자산 상세';

    return AppScaffold(
      title: title,
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const LoadingWidget(message: '자산 정보를 불러오는 중...');
    }
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _loadAsset);
    }

    final theme = Theme.of(context);
    final readOnly = !_isEditing;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── QR코드 (상세 모드만) ──
          if (!widget.isCreateMode && _asset != null) ...[
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _asset!.assetUid,
                        version: QrVersions.auto,
                        size: 160,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _asset!.assetUid,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── 기본 정보 섹션 ──
          _buildSectionTitle('기본 정보'),
          const SizedBox(height: 8),

          // 자산번호
          TextFormField(
            controller: _assetUidCtrl,
            decoration: const InputDecoration(
              labelText: '자산번호 *',
              hintText: 'BDT00001 형태',
              border: OutlineInputBorder(),
            ),
            readOnly: readOnly || !widget.isCreateMode,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '자산번호를 입력하세요.';
              if (!assetUidRegex.hasMatch(v.trim())) {
                return '올바른 자산번호 형식이 아닙니다.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 자산명
          TextFormField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '자산명',
              border: OutlineInputBorder(),
            ),
            readOnly: readOnly,
          ),
          const SizedBox(height: 12),

          // 카테고리 + 상태
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: '카테고리 *',
                    border: OutlineInputBorder(),
                  ),
                  items: assetCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() => _selectedCategory = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: '상태 *',
                    border: OutlineInputBorder(),
                  ),
                  items: assetStatuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() => _selectedStatus = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 제조/모델 정보 ──
          _buildSectionTitle('제조/모델 정보'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(
                    labelText: '제조사',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _modelNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '모델명',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _serialNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: '시리얼번호',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _macAddressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'MAC 주소',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _networkCtrl,
            decoration: const InputDecoration(
              labelText: '네트워크',
              border: OutlineInputBorder(),
            ),
            readOnly: readOnly,
          ),
          const SizedBox(height: 20),

          // ── 담당자 정보 ──
          _buildSectionTitle('담당자 정보'),
          const SizedBox(height: 8),

          // 소유자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ownerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '소유자',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ownerDeptCtrl,
                  decoration: const InputDecoration(
                    labelText: '소유자 부서',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 사용자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _userNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '사용자',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _userDeptCtrl,
                  decoration: const InputDecoration(
                    labelText: '사용자 부서',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 관리자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminNameCtrl,
                  decoration: const InputDecoration(
                    labelText: '관리자',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminDeptCtrl,
                  decoration: const InputDecoration(
                    labelText: '관리자 부서',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 위치 정보 ──
          _buildSectionTitle('위치 정보'),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _buildingCtrl,
                  decoration: const InputDecoration(
                    labelText: '건물',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 20),

          // ── 지급 정보 ──
          _buildSectionTitle('지급 정보'),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
            value: _selectedSupplyType,
            decoration: const InputDecoration(
              labelText: '지급형태',
              border: OutlineInputBorder(),
            ),
            items: supplyTypes
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: readOnly
                ? null
                : (v) => setState(() => _selectedSupplyType = v!),
          ),
          const SizedBox(height: 12),

          // 만료일
          InkWell(
            onTap: readOnly
                ? null
                : () async {
                    final picked = await _pickDate(_supplyEndDate);
                    if (picked != null) {
                      setState(() => _supplyEndDate = picked);
                    }
                  },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '만료일',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                _supplyEndDate != null ? _dateFmt.format(_supplyEndDate!) : '-',
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── 메모 ──
          _buildSectionTitle('메모'),
          const SizedBox(height: 8),

          TextFormField(
            controller: _normalCommentCtrl,
            decoration: const InputDecoration(
              labelText: '일반 메모',
              border: OutlineInputBorder(),
            ),
            readOnly: readOnly,
            maxLines: 3,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _oaCommentCtrl,
            decoration: const InputDecoration(
              labelText: 'OA 메모',
              border: OutlineInputBorder(),
            ),
            readOnly: readOnly,
            maxLines: 3,
          ),
          const SizedBox(height: 32),

          // ── 액션 버튼 ──
          _buildActionButtons(context),
          const SizedBox(height: 32),
        ],
      ),
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

  Widget _buildActionButtons(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.isCreateMode) {
      // 생성 모드: 저장 버튼
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _saveAsset,
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          label: const Text('저장'),
        ),
      );
    }

    // 상세 모드
    if (_isEditing) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _isEditing = false);
                if (_asset != null) _populateForm(_asset!);
              },
              child: const Text('취소'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveAsset,
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
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 편집 + 삭제
        Row(
          children: [
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => setState(() => _isEditing = true),
                icon: const Icon(Icons.edit),
                label: const Text('편집'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _deleteAsset,
                icon: Icon(Icons.delete, color: theme.colorScheme.error),
                label: Text('삭제',
                    style: TextStyle(color: theme.colorScheme.error)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.colorScheme.error),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 실사 등록 버튼
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.tonalIcon(
            onPressed: _createInspection,
            icon: const Icon(Icons.fact_check),
            label: const Text('실사 등록'),
          ),
        ),
      ],
    );
  }
}
