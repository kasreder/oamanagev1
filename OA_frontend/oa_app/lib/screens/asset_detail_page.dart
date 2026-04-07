import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../main.dart';
import '../constants.dart';
import '../models/asset.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../notifiers/agent_presence_notifier.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../utils/label_ocr.dart';
import '../utils/scan_feedback.dart';
import '../utils/temp_file_cleaner.dart';
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

  bool get _isAdminUser {
    final authState = ref.read(authNotifierProvider);
    return authState.valueOrNull?.user?.isAdminGroup ?? false;
  }

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
  late TextEditingController _ownerEmpIdCtrl;
  late TextEditingController _userNameCtrl;
  late TextEditingController _userDeptCtrl;
  late TextEditingController _userEmpIdCtrl;
  late TextEditingController _adminNameCtrl;
  late TextEditingController _adminDeptCtrl;
  late TextEditingController _adminEmpIdCtrl;
  late TextEditingController _normalCommentCtrl;
  late TextEditingController _oaCommentCtrl;

  String _selectedCategory = assetCategories.first;
  String _selectedStatus = assetStatuses.first;
  String _selectedSupplyType = supplyTypes.first;
  DateTime? _supplyEndDate;
  bool _useNewUidFormat = false; // false=현재기준, true=변경후 기준

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
    _ownerEmpIdCtrl = TextEditingController();
    _userNameCtrl = TextEditingController();
    _userDeptCtrl = TextEditingController();
    _userEmpIdCtrl = TextEditingController();
    _adminNameCtrl = TextEditingController();
    _adminDeptCtrl = TextEditingController();
    _adminEmpIdCtrl = TextEditingController();
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
    _ownerEmpIdCtrl.dispose();
    _userNameCtrl.dispose();
    _userDeptCtrl.dispose();
    _userEmpIdCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminDeptCtrl.dispose();
    _adminEmpIdCtrl.dispose();
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
    _ownerEmpIdCtrl.text = asset.ownerEmployeeId ?? '';
    _userNameCtrl.text = asset.userName ?? '';
    _userDeptCtrl.text = asset.userDepartment ?? '';
    _userEmpIdCtrl.text = asset.userEmployeeId ?? '';
    _adminNameCtrl.text = asset.adminName ?? '';
    _adminDeptCtrl.text = asset.adminDepartment ?? '';
    _adminEmpIdCtrl.text = asset.adminEmployeeId ?? '';
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
        'owner_employee_id': _ownerEmpIdCtrl.text.trim(),
        'user_name': _userNameCtrl.text.trim(),
        'user_department': _userDeptCtrl.text.trim(),
        'user_employee_id': _userEmpIdCtrl.text.trim(),
        'admin_name': _adminNameCtrl.text.trim(),
        'admin_department': _adminDeptCtrl.text.trim(),
        'admin_employee_id': _adminEmpIdCtrl.text.trim(),
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
            content: SelectableText('저장 실패: ${e.toString()}'),
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
            content: SelectableText('삭제 실패: ${e.toString()}'),
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
  /// 사진 촬영 없이 실사 레코드 생성 → 실사 상세 페이지로 이동
  Future<void> _createInspection() async {
    try {
      final assetCode = _asset?.assetUid ?? 'UNKNOWN';

      // 활성 라운드 조회
      final activeRound = await _api.fetchActiveRound();

      // 실사 등록
      final inspection = await _api.createInspection({
        'asset_id': widget.assetId,
        'asset_code': assetCode,
        'asset_type': _asset?.category,
        if (activeRound != null) 'round_id': activeRound.id,
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
            content: SelectableText('실사 등록 실패: ${e.toString()}'),
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

          // 자산번호 기준 선택 (생성 모드 + 관리자만)
          if (widget.isCreateMode && _isAdminUser) ...[
            Row(
              children: [
                const Text('자산번호 기준:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('현재기준'),
                  selected: !_useNewUidFormat,
                  onSelected: (_) => setState(() => _useNewUidFormat = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('변경후'),
                  selected: _useNewUidFormat,
                  onSelected: (_) => setState(() => _useNewUidFormat = true),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // 자산번호
          TextFormField(
            controller: _assetUidCtrl,
            decoration: InputDecoration(
              labelText: '자산번호 *',
              hintText: _useNewUidFormat ? 'BDT00001 형태' : 'D00001 형태',
              border: const OutlineInputBorder(),
              suffixIcon: _isEditing
                  ? _buildQrScanSuffix(_assetUidCtrl)
                  : null,
            ),
            readOnly: readOnly || !widget.isCreateMode,
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '자산번호를 입력하세요.';
              final uid = v.trim().toUpperCase();
              if (_useNewUidFormat) {
                if (!assetUidNewRegex.hasMatch(uid)) {
                  return '변경후 형식: BDT00001, STP22222 등 (8자리)';
                }
              } else {
                if (!assetUidCurrentRegex.hasMatch(uid)) {
                  return '현재기준 형식: D00001, TP0001 등';
                }
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
          Row(
            children: [
              Expanded(child: _buildSectionTitle('제조/모델 정보')),
              if (_isEditing) ...[
                Tooltip(
                  message: '사진 추가로 자동 입력',
                  child: IconButton(
                    icon: const Icon(Icons.photo_library, size: 22),
                    onPressed: _pickAndExtractDeviceInfo,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Tooltip(
                  message: '라벨 촬영으로 자동 입력',
                  child: IconButton(
                    icon: const Icon(Icons.photo_camera, size: 22),
                    onPressed: _captureAndExtractDeviceInfo,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Tooltip(
                  message: '실시간 OCR 스캔',
                  child: IconButton(
                    icon: const Icon(Icons.document_scanner, size: 22),
                    onPressed: _liveOcrScan,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
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
                  decoration: InputDecoration(
                    labelText: '시리얼번호',
                    border: const OutlineInputBorder(),
                    suffixIcon: _buildQrScanSuffix(_serialNumberCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _macAddressCtrl,
                  decoration: InputDecoration(
                    labelText: 'MAC 주소',
                    border: const OutlineInputBorder(),
                    suffixIcon: _buildQrScanSuffix(_macAddressCtrl),
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

          // 1. 실사용자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _userNameCtrl,
                  decoration: const InputDecoration(labelText: '실사용자 *', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _userDeptCtrl,
                  decoration: const InputDecoration(labelText: '실사용 부서', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _userEmpIdCtrl,
                  decoration: const InputDecoration(labelText: '실사용자 사번', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. 소유자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ownerNameCtrl,
                  decoration: const InputDecoration(labelText: '소유자', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ownerDeptCtrl,
                  decoration: const InputDecoration(labelText: '소유 부서', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ownerEmpIdCtrl,
                  decoration: const InputDecoration(labelText: '소유자 사번', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. 관리자
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _adminNameCtrl,
                  decoration: const InputDecoration(labelText: '관리자', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminDeptCtrl,
                  decoration: const InputDecoration(labelText: '관리 부서', border: OutlineInputBorder()),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminEmpIdCtrl,
                  decoration: const InputDecoration(labelText: '관리자 사번', border: OutlineInputBorder()),
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

          // ── 에이전트 상태 (상세 모드만) ──
          if (!widget.isCreateMode && _asset != null) ...[
            _buildAgentStatusSection(context),
            const SizedBox(height: 16),
            _buildDeviceStatusSection(context),
            const SizedBox(height: 24),
          ],

          // ── 액션 버튼 ──
          _buildActionButtons(context),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── 에이전트 상태 섹션 ──────────────────────────────────────────────────
  Widget _buildAgentStatusSection(BuildContext context) {
    final asset = _asset!;
    final theme = Theme.of(context);
    final presenceState = ref.watch(agentPresenceNotifierProvider);
    final isPresenceConnected = presenceState.containsKey(asset.assetUid);
    final dateFmt = DateFormat('yyyy-MM-dd HH:mm');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 접속 상태
            Row(
              children: [
                Icon(Icons.wifi, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('접속 상태', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isPresenceConnected
                        ? Colors.blue
                        : (asset.lastActiveAt != null &&
                                DateTime.now().difference(asset.lastActiveAt!).inMinutes <= 60)
                            ? Colors.green
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPresenceConnected
                      ? '실시간 연결됨'
                      : (asset.lastActiveAt != null
                          ? '마지막 접속: ${dateFmt.format(asset.lastActiveAt!)}'
                          : '접속 기록 없음'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 사용자 확인 현황
            Row(
              children: [
                Icon(Icons.verified_user, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('사용자 확인 현황', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildVerificationIcon(asset.verificationStatus),
                const SizedBox(width: 8),
                Text(_verificationLabel(asset.verificationStatus)),
              ],
            ),
            if (asset.lastVerifiedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '마지막 확인: ${dateFmt.format(asset.lastVerifiedAt!)}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            if (asset.verificationStatus == 'mismatch')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  color: Colors.red.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(child: Text('기존 사용자와 다른 사용자입니다. 확인이 필요합니다.', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // 배정 수령 상태
            Row(
              children: [
                Icon(Icons.assignment_turned_in, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('배정 수령 상태', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildAssignmentBadge(asset.assignmentStatus),
                if (asset.assignmentConfirmedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '확인: ${dateFmt.format(asset.assignmentConfirmedAt!)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // 관리자 명령 버튼
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendAgentCommand('request_heartbeat'),
                    icon: const Icon(Icons.sync, size: 18),
                    label: const Text('즉시 Heartbeat'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendAgentCommand('refresh_system_info'),
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('시스템 정보 갱신'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 에이전트 전송 장비 상세 정보 ─────────────────────────────────────────
  Widget _buildDeviceStatusSection(BuildContext context) {
    final asset = _asset!;
    final theme = Theme.of(context);
    final deviceStatus =
        (asset.specifications['device_status'] as Map<String, dynamic>?) ?? {};

    if (deviceStatus.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.devices, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text('에이전트에서 전송된 장비 정보가 없습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.devices, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('에이전트 장비 정보',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),

            // 장비 기본
            _deviceHeader(theme, Icons.phone_android, '장비'),
            _deviceRow('제조사', deviceStatus['device_manufacturer']),
            _deviceRow('모델', deviceStatus['device_model']),
            _deviceRow('시리얼번호', deviceStatus['serial_number']),
            _deviceRow('MAC 주소', deviceStatus['mac_address']),
            _deviceRow('전화번호', deviceStatus['phone_number']),
            const SizedBox(height: 12),

            // OS
            _deviceHeader(theme, Icons.settings, 'OS'),
            _deviceRow('OS 버전', deviceStatus['os_version']),
            _deviceRow('OS 상세', deviceStatus['os_detail_version']),
            _deviceRow('가동시간', _formatUptime(deviceStatus['uptime_hours'])),
            const SizedBox(height: 12),

            // 성능
            _deviceHeader(theme, Icons.speed, '성능'),
            _deviceRow('CPU 사용률', _formatPercent(deviceStatus['cpu_usage'])),
            _deviceRow('메모리',
                '${deviceStatus['memory_used_mb'] ?? '-'} / ${deviceStatus['memory_total_mb'] ?? '-'} MB'),
            _deviceRow('저장공간',
                '${_formatGb(deviceStatus['storage_used_gb'])} / ${_formatGb(deviceStatus['storage_total_gb'])} GB'),
            const SizedBox(height: 12),

            // 배터리 & 네트워크
            _deviceHeader(theme, Icons.battery_std, '배터리 / 네트워크'),
            _deviceRow('배터리', _formatBattery(
                deviceStatus['battery_level'], deviceStatus['battery_charging'])),
            _deviceRow('네트워크', deviceStatus['network_type']),
            _deviceRow('IP 주소', deviceStatus['ip_address']),
            const SizedBox(height: 12),

            // 사용자 정보
            _deviceHeader(theme, Icons.person, '사용자'),
            _deviceRow('기기 사용자', deviceStatus['device_user']),
            _deviceRow('자산 사용자', deviceStatus['asset_user_name']),
            _deviceRow('사번', deviceStatus['employee_id']),
            _deviceRow('에이전트 버전', deviceStatus['agent_version']),
          ],
        ),
      ),
    );
  }

  Widget _deviceHeader(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.secondary),
          const SizedBox(width: 6),
          Text(title,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
        ],
      ),
    );
  }

  Widget _deviceRow(String label, dynamic value) {
    final text = (value == null || value.toString().isEmpty) ? '-' : value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _formatUptime(dynamic hours) {
    if (hours == null) return '-';
    final h = (hours as num).toDouble();
    if (h < 1) return '${(h * 60).toInt()}분';
    if (h < 24) return '${h.toStringAsFixed(1)}시간';
    return '${(h / 24).toStringAsFixed(1)}일';
  }

  String _formatPercent(dynamic value) {
    if (value == null) return '-';
    return '${(value as num).toStringAsFixed(1)}%';
  }

  String _formatGb(dynamic value) {
    if (value == null) return '-';
    return (value as num).toStringAsFixed(1);
  }

  String _formatBattery(dynamic level, dynamic charging) {
    if (level == null) return '-';
    final pct = '$level%';
    final charge = (charging == true) ? ' (충전 중)' : '';
    return '$pct$charge';
  }

  Widget _buildVerificationIcon(String? status) {
    switch (status) {
      case 'verified':
        return const Icon(Icons.check_circle, color: Colors.green, size: 20);
      case 'mismatch':
        return const Icon(Icons.warning, color: Colors.red, size: 20);
      default:
        return const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20);
    }
  }

  String _verificationLabel(String? status) {
    switch (status) {
      case 'verified':
        return '확인 완료';
      case 'mismatch':
        return '불일치';
      default:
        return '미확인';
    }
  }

  Widget _buildAssignmentBadge(String? status) {
    switch (status) {
      case 'pending':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('수령 대기', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        );
      case 'confirmed':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('수령 완료', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
        );
      default:
        return const Text('배정 없음', style: TextStyle(color: Colors.grey));
    }
  }

  Future<void> _sendAgentCommand(String command) async {
    if (_asset == null) return;
    try {
      await ref.read(realtimeServiceProvider).sendCommand(_asset!.assetUid, command);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('명령 전송 완료: $command')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('명령 전송 실패: $e')),
        );
      }
    }
  }

  // ── QR 스캔 → 특정 필드에 값 입력 ────────────────────────────────────────
  Future<void> _scanQrForField(TextEditingController controller) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _QrScanDialog(),
    );
    if (result != null && result.isNotEmpty && mounted) {
      setState(() => controller.text = result);
    }
  }

  // ── 갤러리에서 사진 선택 → OCR ──────────────────────────────────────────
  Future<void> _pickAndExtractDeviceInfo() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.gallery);
    if (photo == null) return;
    await _processOcrFromXFile(photo);
  }

  // ── 라벨 촬영 → OCR로 제조사/모델/시리얼/MAC 자동 입력 ──────────────────
  Future<void> _captureAndExtractDeviceInfo() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;
    await _processOcrFromXFile(photo);
  }

  // ── 실시간 OCR 스캔 (모바일 전용) ───────────────────────────────────────
  Future<void> _liveOcrScan() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _LiveOcrScanDialog(),
    );

    if (result != null && mounted) {
      setState(() {
        if (result['vendor']?.isNotEmpty == true) _vendorCtrl.text = result['vendor']!;
        if (result['model']?.isNotEmpty == true) _modelNameCtrl.text = result['model']!;
        if (result['serial']?.isNotEmpty == true) _serialNumberCtrl.text = result['serial']!;
        if (result['mac']?.isNotEmpty == true) _macAddressCtrl.text = result['mac']!;
      });
    }
  }

  // ── 공통 OCR 처리 ─────────────────────────────────────────────────────
  Future<void> _processOcrFromXFile(XFile file) async {
    try {
      final lines = await LabelOcr.recognizeFromXFile(file);

      // OCR 완료 후 임시 이미지 파일 삭제
      await TempFileCleaner.delete(file.path);

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('텍스트를 인식하지 못했습니다. 다시 시도해주세요.')),
          );
        }
        return;
      }

      // 인식된 텍스트에서 패턴 매칭
      final extracted = _parseDeviceLabel(lines);

      if (mounted) {
        final result = await showDialog<Map<String, String>>(
          context: context,
          builder: (ctx) => _OcrResultEditDialog(
            extracted: extracted,
            ocrLines: lines,
          ),
        );

        if (result != null && mounted) {
          setState(() {
            if (result['vendor']?.isNotEmpty == true) _vendorCtrl.text = result['vendor']!;
            if (result['model']?.isNotEmpty == true) _modelNameCtrl.text = result['model']!;
            if (result['serial']?.isNotEmpty == true) _serialNumberCtrl.text = result['serial']!;
            if (result['mac']?.isNotEmpty == true) _macAddressCtrl.text = result['mac']!;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('OCR 처리 실패: $e')),
        );
      }
    }
  }

  /// 인식된 텍스트에서 제조사/모델/시리얼/MAC 패턴 추출
  Map<String, String?> _parseDeviceLabel(List<String> lines) {
    String? vendor, model, serial, mac;
    final fullText = lines.join(' ');

    // MAC 주소 패턴: XX:XX:XX:XX:XX:XX 또는 XX-XX-XX-XX-XX-XX
    final macRegex = RegExp(r'([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
    final macMatch = macRegex.firstMatch(fullText);
    if (macMatch != null) mac = macMatch.group(0)!.toUpperCase();

    // 시리얼번호: S/N, Serial, SN: 뒤의 값
    final serialRegex = RegExp(r'(?:S/?N|Serial(?:\s*No)?|SN)\s*[:\.]?\s*([A-Za-z0-9\-]+)', caseSensitive: false);
    final serialMatch = serialRegex.firstMatch(fullText);
    if (serialMatch != null) serial = serialMatch.group(1);

    // 모델명: Model, P/N, Part 뒤의 값
    final modelRegex = RegExp(r'(?:Model|P/?N|Part(?:\s*No)?)\s*[:\.]?\s*([A-Za-z0-9\-\s]+)', caseSensitive: false);
    final modelMatch = modelRegex.firstMatch(fullText);
    if (modelMatch != null) model = modelMatch.group(1)?.trim();

    // 제조사: 알려진 제조사명 매칭
    final knownVendors = [
      'Apple', 'Dell', 'HP', 'Lenovo', 'Samsung', 'LG', 'Cisco', 'Aruba',
      'Fortinet', 'Fujitsu', 'Epson', 'Canon', 'BenQ', 'Yealink', 'ASUS',
      'Acer', 'MSI', 'Intel', 'Microsoft', 'Sony', 'Toshiba', 'Panasonic',
    ];
    for (final v in knownVendors) {
      if (fullText.toUpperCase().contains(v.toUpperCase())) {
        vendor = v;
        break;
      }
    }

    return {'vendor': vendor, 'model': model, 'serial': serial, 'mac': mac};
  }

  /// QR 스캔 버튼 위젯 (편집 모드일 때만 표시)
  Widget _buildQrScanSuffix(TextEditingController controller) {
    if (!_isEditing) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner, size: 22),
      tooltip: 'QR 스캔',
      onPressed: () => _scanQrForField(controller),
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

// ═══════════════════════════════════════════════════════════════════════════
// QR 스캔 다이얼로그 (MobileScanner)
// ═══════════════════════════════════════════════════════════════════════════
class _QrScanDialog extends StatefulWidget {
  @override
  State<_QrScanDialog> createState() => _QrScanDialogState();
}

class _QrScanDialogState extends State<_QrScanDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _scanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('QR / 바코드 스캔'),
      contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      content: SizedBox(
        width: 320,
        height: 320,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode == null || barcode.rawValue == null) return;
              _scanned = true;
              ScanFeedback.success();
              Navigator.pop(context, barcode.rawValue!.trim());
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

// ── OCR 결과 편집 다이얼로그 ─────────────────────────────────────────────
class _OcrResultEditDialog extends StatefulWidget {
  final Map<String, String?> extracted;
  final List<String> ocrLines;

  const _OcrResultEditDialog({
    required this.extracted,
    required this.ocrLines,
  });

  @override
  State<_OcrResultEditDialog> createState() => _OcrResultEditDialogState();
}

class _OcrResultEditDialogState extends State<_OcrResultEditDialog> {
  late final TextEditingController _vendorCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _serialCtrl;
  late final TextEditingController _macCtrl;

  @override
  void initState() {
    super.initState();
    _vendorCtrl = TextEditingController(text: widget.extracted['vendor'] ?? '');
    _modelCtrl = TextEditingController(text: widget.extracted['model'] ?? '');
    _serialCtrl = TextEditingController(text: widget.extracted['serial'] ?? '');
    _macCtrl = TextEditingController(text: widget.extracted['mac'] ?? '');
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _macCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('인식 결과 확인'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('매칭되지 않은 항목은 직접 입력하세요.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            _buildEditableField('제조사', _vendorCtrl, widget.extracted['vendor'] != null),
            _buildEditableField('모델명', _modelCtrl, widget.extracted['model'] != null),
            _buildEditableField('시리얼번호', _serialCtrl, widget.extracted['serial'] != null),
            _buildEditableField('MAC 주소', _macCtrl, widget.extracted['mac'] != null),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('인식된 전체 텍스트 (탭하여 복사)', style: TextStyle(fontSize: 13)),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D2D2D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: widget.ocrLines.map((line) {
                      final words = line.split(RegExp(r'\s+'))
                          .where((w) => w.isNotEmpty)
                          .toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: words.map((word) => _WordChip(
                            word: word,
                            onCopied: (text) {
                              ScaffoldMessenger.of(context)
                                ..clearSnackBars()
                                ..showSnackBar(SnackBar(
                                  content: Text("'$text' 복사됨"),
                                  duration: const Duration(seconds: 1),
                                ));
                            },
                          )).toList(),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, {
            'vendor': _vendorCtrl.text.trim(),
            'model': _modelCtrl.text.trim(),
            'serial': _serialCtrl.text.trim(),
            'mac': _macCtrl.text.trim(),
          }),
          child: const Text('적용'),
        ),
      ],
    );
  }

  Widget _buildEditableField(String label, TextEditingController ctrl, bool matched) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          suffixIcon: matched
              ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
              : const Icon(Icons.edit, color: Colors.orange, size: 18),
          helperText: matched ? null : '자동 인식 실패 — 직접 입력하세요',
          helperStyle: const TextStyle(fontSize: 10, color: Colors.orange),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 실시간 OCR 스캔 다이얼로그 (모바일 전용)
// 카메라로 텍스트를 실시간 인식, 탭하면 필드에 값 입력
// ═══════════════════════════════════════════════════════════════════════════
class _LiveOcrScanDialog extends StatefulWidget {
  const _LiveOcrScanDialog();

  @override
  State<_LiveOcrScanDialog> createState() => _LiveOcrScanDialogState();
}

class _LiveOcrScanDialogState extends State<_LiveOcrScanDialog> {
  List<String> _detectedTexts = [];
  bool _isProcessing = false;

  // 선택된 값
  String? _selectedVendor;
  String? _selectedModel;
  String? _selectedSerial;
  String? _selectedMac;

  // 현재 입력 대상 필드
  String _activeField = 'serial'; // serial, mac, vendor, model

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OCR 스캔'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context, null),
          ),
          actions: [
            FilledButton(
              onPressed: (_selectedSerial != null || _selectedMac != null ||
                      _selectedVendor != null || _selectedModel != null)
                  ? () => Navigator.pop(context, {
                        'vendor': _selectedVendor ?? '',
                        'model': _selectedModel ?? '',
                        'serial': _selectedSerial ?? '',
                        'mac': _selectedMac ?? '',
                      })
                  : null,
              child: const Text('적용'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Column(
          children: [
            // ── 선택된 값 표시 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  _buildSelectedRow('시리얼', _selectedSerial, 'serial', theme),
                  _buildSelectedRow('MAC', _selectedMac, 'mac', theme),
                  _buildSelectedRow('제조사', _selectedVendor, 'vendor', theme),
                  _buildSelectedRow('모델명', _selectedModel, 'model', theme),
                ],
              ),
            ),

            // ── 입력 대상 필드 선택 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Text('입력 대상: ', style: theme.textTheme.labelMedium),
                  const SizedBox(width: 4),
                  _buildFieldChip('시리얼', 'serial', theme),
                  const SizedBox(width: 4),
                  _buildFieldChip('MAC', 'mac', theme),
                  const SizedBox(width: 4),
                  _buildFieldChip('제조사', 'vendor', theme),
                  const SizedBox(width: 4),
                  _buildFieldChip('모델명', 'model', theme),
                ],
              ),
            ),

            // ── 촬영 버튼 + 안내 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  Text(
                    '라벨을 촬영하세요. 인식된 텍스트를 탭하면 선택한 필드에 입력됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _takeAndRecognize,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.camera_alt),
                      label: Text(_detectedTexts.isEmpty ? '촬영하기' : '다시 촬영'),
                    ),
                  ),
                ],
              ),
            ),

            // ── 인식 결과 (탭하면 값 입력) ──
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: _detectedTexts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.document_scanner, size: 48,
                                color: theme.colorScheme.outline.withOpacity(0.4)),
                            const SizedBox(height: 8),
                            Text(
                              '인식된 텍스트가 여기에 표시됩니다',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.outline),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _detectedTexts.map((text) {
                            return ActionChip(
                              label: Text(text, style: const TextStyle(fontSize: 13)),
                              onPressed: () => _onTextTapped(text),
                              backgroundColor: _isHighlightText(text)
                                  ? theme.colorScheme.primaryContainer
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 촬영 후 OCR 분석 (LabelOcr 사용 — 모바일: ML Kit, 웹: Tesseract.js)
  Future<void> _takeAndRecognize() async {
    setState(() => _isProcessing = true);

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1440,
        imageQuality: 85,
      );
      if (photo == null) {
        setState(() => _isProcessing = false);
        return;
      }

      final words = await LabelOcr.recognizeWordsFromXFile(photo);

      // 임시 파일 삭제
      TempFileCleaner.delete(photo.path);

      if (mounted) {
        setState(() {
          _detectedTexts = words;
          _isProcessing = false;
        });

        if (words.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('텍스트를 인식하지 못했습니다.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: SelectableText('OCR 실패: $e')),
        );
      }
    }
  }

  /// 텍스트 탭 → 현재 활성 필드에 값 입력
  void _onTextTapped(String text) {
    setState(() {
      switch (_activeField) {
        case 'serial':
          _selectedSerial = text;
          break;
        case 'mac':
          _selectedMac = text;
          break;
        case 'vendor':
          _selectedVendor = text;
          break;
        case 'model':
          _selectedModel = text;
          break;
      }
    });

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('"$text" → ${_fieldLabel(_activeField)}에 입력'),
        duration: const Duration(seconds: 1),
      ));
  }

  String _fieldLabel(String field) {
    switch (field) {
      case 'serial': return '시리얼';
      case 'mac': return 'MAC';
      case 'vendor': return '제조사';
      case 'model': return '모델명';
      default: return field;
    }
  }

  /// MAC 주소나 시리얼 패턴 하이라이트
  bool _isHighlightText(String text) {
    // MAC 주소 패턴
    if (RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$').hasMatch(text)) return true;
    // 시리얼번호 패턴 (영숫자 6자리 이상)
    if (RegExp(r'^[A-Za-z0-9\-]{6,}$').hasMatch(text)) return true;
    return false;
  }

  Widget _buildSelectedRow(String label, String? value, String field, ThemeData theme) {
    final isActive = _activeField == field;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isActive ? FontWeight.bold : null,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: value != null ? FontWeight.w600 : null,
                color: value != null ? theme.colorScheme.onSurface : theme.colorScheme.outline,
              ),
            ),
          ),
          if (value != null)
            GestureDetector(
              onTap: () => setState(() {
                switch (field) {
                  case 'serial': _selectedSerial = null; break;
                  case 'mac': _selectedMac = null; break;
                  case 'vendor': _selectedVendor = null; break;
                  case 'model': _selectedModel = null; break;
                }
              }),
              child: Icon(Icons.close, size: 16, color: theme.colorScheme.error),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldChip(String label, String field, ThemeData theme) {
    final isActive = _activeField == field;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isActive,
      onSelected: (_) => setState(() => _activeField = field),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ── 단어 칩 (탭하면 클립보드 복사) ──────────────────────────────────────
class _WordChip extends StatelessWidget {
  final String word;
  final ValueChanged<String> onCopied;

  const _WordChip({required this.word, required this.onCopied});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        Clipboard.setData(ClipboardData(text: word));
        onCopied(word);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF424242),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          word,
          style: const TextStyle(
            fontSize: 12,
            fontFamily: 'monospace',
            color: Color(0xFFE0E0E0),
          ),
        ),
      ),
    );
  }
}
