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
import '../models/drawing.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';
import '../notifiers/agent_presence_notifier.dart';
import '../notifiers/dropdown_options_provider.dart';
import '../notifiers/auth_notifier.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../utils/label_ocr.dart';
import '../utils/os_security.dart';
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
  late TextEditingController _adminCompanyCtrl;
  late TextEditingController _normalCommentCtrl;
  late TextEditingController _oaCommentCtrl;

  String _selectedCategory = assetCategories.first;
  String _selectedSupplyType = supplyTypes.first;
  String? _selectedBuilding1;     // 위치 대분류 — building1Options
  String? _selectedAdminAffiliation; // 담당자 소속 — adminAffiliationOptions
  DateTime? _supplyEndDate;
  // 도면 좌표
  List<Drawing> _drawings = [];
  int? _selectedDrawingId;
  int? _selectedRow;
  int? _selectedCol;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadDrawings();

    if (widget.isCreateMode) {
      _isEditing = true;
      if (widget.initialAssetUid != null) {
        _assetUidCtrl.text = widget.initialAssetUid!;
      }
    } else if (widget.assetId != null) {
      _loadAsset();
    }
  }

  Drawing? get _selectedDrawing {
    for (final d in _drawings) {
      if (d.id == _selectedDrawingId) return d;
    }
    return null;
  }

  // 행/열 입력은 1-based 텍스트, 저장은 0-based int
  final TextEditingController _rowInputCtrl = TextEditingController();
  final TextEditingController _colInputCtrl = TextEditingController();

  void _syncRowColControllers() {
    _rowInputCtrl.text =
        _selectedRow == null ? '' : '${_selectedRow! + 1}';
    _colInputCtrl.text =
        _selectedCol == null ? '' : '${_selectedCol! + 1}';
  }

  Future<void> _loadDrawings() async {
    try {
      final list = await _api.fetchDrawings();
      if (!mounted) return;
      setState(() => _drawings = list);
    } catch (_) {/* 도면 로드 실패는 무시 — 위치 입력만 비활성 */}
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
    _adminCompanyCtrl = TextEditingController();
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
    _adminCompanyCtrl.dispose();
    _normalCommentCtrl.dispose();
    _oaCommentCtrl.dispose();
    _rowInputCtrl.dispose();
    _colInputCtrl.dispose();
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
    _adminCompanyCtrl.text = asset.adminCompany ?? '';
    _normalCommentCtrl.text = asset.normalComment ?? '';
    _oaCommentCtrl.text = asset.oaComment ?? '';

    _selectedCategory = assetCategories.contains(asset.category)
        ? asset.category
        : assetCategories.first;
    _selectedSupplyType = supplyTypes.contains(asset.supplyType)
        ? asset.supplyType
        : supplyTypes.first;
    _supplyEndDate = asset.supplyEndDate;
    _selectedBuilding1 = (asset.building1?.isNotEmpty ?? false) ? asset.building1 : null;
    _selectedAdminAffiliation =
        (asset.adminAffiliation?.isNotEmpty ?? false) ? asset.adminAffiliation : null;
    _selectedDrawingId = asset.locationDrawingId;
    _selectedRow = asset.locationRow;
    _selectedCol = asset.locationCol;
    _syncRowColControllers();
  }

  /// "이 값으로 자산목록 검색" — 자산상세에서 값이 있는 필드 우측 🔍 아이콘.
  /// 생성 모드에서는 비활성. 빈 값 필드도 비활성.
  Widget? _searchSuffix(String columnKey, TextEditingController ctrl) {
    if (widget.isCreateMode) return null;
    return ListenableBuilder(
      listenable: ctrl,
      builder: (ctx, _) {
        final v = ctrl.text.trim();
        if (v.isEmpty) return const SizedBox.shrink();
        return IconButton(
          tooltip: '이 값으로 자산목록 검색',
          icon: const Icon(Icons.search, size: 18),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          onPressed: () => _gotoSearch(columnKey, v),
        );
      },
    );
  }

  void _gotoSearch(String columnKey, String value) {
    final encoded = Uri.encodeQueryComponent(value);
    context.go('/assets?col=$columnKey&val=$encoded');
  }

  /// QR 등 다른 suffix와 함께 쓰는 경우 — Row로 묶어 반환
  Widget? _suffixWithSearch(
    String columnKey,
    TextEditingController ctrl, {
    Widget? qr,
  }) {
    final searchWidget = _searchSuffix(columnKey, ctrl);
    if (qr == null && searchWidget == null) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (searchWidget != null) searchWidget,
        if (qr != null) qr,
      ],
    );
  }

  /// 드롭다운/날짜 필드 옆에 붙는 작은 🔍 IconButton.
  /// value가 비거나 생성모드면 SizedBox.shrink.
  Widget _searchIconButton(String columnKey, String? value) {
    if (widget.isCreateMode) return const SizedBox.shrink();
    final v = (value ?? '').trim();
    if (v.isEmpty) return const SizedBox.shrink();
    return IconButton(
      tooltip: '이 값으로 자산목록 검색',
      icon: const Icon(Icons.search, size: 20),
      visualDensity: VisualDensity.compact,
      onPressed: () => _gotoSearch(columnKey, v),
    );
  }

  /// 자식 위젯(보통 Dropdown) + 우측 🔍 IconButton을 묶은 Row.
  /// 값이 비어있거나 생성 모드면 아이콘은 SizedBox.shrink (자리만 차지하지 않음).
  Widget _withSearchIcon({
    required Widget child,
    required String columnKey,
    required String? value,
  }) {
    final icon = _searchIconButton(columnKey, value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: child),
        icon,
      ],
    );
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

    // 지급형태가 만료일 필수 항목인 경우 _supplyEndDate가 비면 막음
    final needsEndDate = supplyTypesRequireEndDate.contains(_selectedSupplyType);
    if (needsEndDate && _supplyEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지급형태에 따라 만료일을 입력해야 합니다.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = <String, dynamic>{
        'asset_uid': _assetUidCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'category': _selectedCategory,
        'supply_type': _selectedSupplyType,
        'serial_number': _serialNumberCtrl.text.trim(),
        'model_name': _modelNameCtrl.text.trim(),
        'vendor': _vendorCtrl.text.trim(),
        'network': _networkCtrl.text.trim(),
        'mac_address': _macAddressCtrl.text.trim(),
        'building1': _selectedBuilding1,
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
        'admin_affiliation': _selectedAdminAffiliation,
        'admin_company': _selectedAdminAffiliation == '롯데카드 외'
            ? _adminCompanyCtrl.text.trim()
            : null,
        'location_drawing_id': _selectedDrawingId,
        'location_row': _selectedRow,
        'location_col': _selectedCol,
        'normal_comment': _normalCommentCtrl.text.trim(),
        'oa_comment': _oaCommentCtrl.text.trim(),
        'supply_end_date':
            needsEndDate ? _supplyEndDate!.toIso8601String() : null,
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

  /// 자산 상세에서 [실사 보기] 버튼:
  /// - 가장 최근 inspection이 있으면 그 상세 페이지로 이동
  /// - 없으면 새 inspection을 자동 생성 후 그 상세 페이지로 이동
  Future<void> _createInspection() async {
    final assetId = widget.assetId;
    if (assetId == null) return;
    try {
      // 1. 가장 최근 inspection 있으면 그것으로 이동
      final latest = await _api.fetchLatestInspectionForAsset(assetId);
      if (!mounted) return;
      if (latest != null) {
        context.go('/inspection/${latest.id}');
        return;
      }

      // 2. 없으면 새 inspection 생성 후 이동
      final assetCode = _asset?.assetUid ?? 'UNKNOWN';
      final activeRound = await _api.fetchActiveRound();
      final created = await _api.createInspection({
        'asset_id': assetId,
        'asset_code': assetCode,
        'asset_type': _asset?.category,
        if (activeRound != null) 'round_id': activeRound.id,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실사가 등록되었습니다.')),
      );
      context.go('/inspection/${created.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SelectableText('실사 조회/등록 실패: ${e.toString()}'),
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

    // ── DB에서 드롭다운 옵션 가져오기 (실패시 const fallback) ─────────────
    final categories = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'category')))
            .valueOrNull ??
        assetCategories;
    final supplyTypeList = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'supply_type')))
            .valueOrNull ??
        supplyTypes;
    final networkList = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'network')))
            .valueOrNull ??
        networkOptions;
    final building1List = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'building1')))
            .valueOrNull ??
        building1Options;
    final affiliationList = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'admin_affiliation')))
            .valueOrNull ??
        adminAffiliationOptions;
    final floorList = ref
            .watch(dropdownOptionsProvider(
                const DropdownKey('asset_detail', 'floor')))
            .valueOrNull ??
        floorOptions;

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
            decoration: InputDecoration(
              labelText: '자산번호 *',
              hintText: 'D00001 형태 (영문 1~2자리 + 숫자 4~5자리)',
              border: const OutlineInputBorder(),
              suffixIcon: _suffixWithSearch(
                'asset_uid',
                _assetUidCtrl,
                qr: _isEditing ? _buildQrScanSuffix(_assetUidCtrl) : null,
              ),
            ),
            readOnly: readOnly || !widget.isCreateMode,
            textCapitalization: TextCapitalization.characters,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return '자산번호를 입력하세요.';
              final uid = v.trim().toUpperCase();
              if (!assetUidRegex.hasMatch(uid)) {
                return '자산번호 형식: D00001, TP0001 등 (영문 1~2자리 + 숫자 4~5자리)';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // 자산명
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: '자산명',
              border: const OutlineInputBorder(),
              suffixIcon: _searchSuffix('name', _nameCtrl),
            ),
            readOnly: readOnly,
          ),
          const SizedBox(height: 12),

          // 카테고리 + 지급형태(필수)
          Row(
            children: [
              Expanded(
                child: _withSearchIcon(
                  columnKey: 'category',
                  value: _selectedCategory,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: '자산종류 *',
                      border: OutlineInputBorder(),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: readOnly
                        ? null
                        : (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _withSearchIcon(
                  columnKey: 'supply_type',
                  value: _selectedSupplyType,
                  child: DropdownButtonFormField<String>(
                    value: _selectedSupplyType,
                    decoration: const InputDecoration(
                      labelText: '지급형태 *',
                      border: OutlineInputBorder(),
                    ),
                    items: supplyTypeList
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: readOnly
                        ? null
                        : (v) => setState(() => _selectedSupplyType = v!),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? '지급형태를 선택하세요.' : null,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 만료일 (렌탈/대여/도급/개인일 때만 표시)
          if (supplyTypesRequireEndDate.contains(_selectedSupplyType)) ...[
            _withSearchIcon(
              columnKey: 'supply_end_date',
              value:
                  _supplyEndDate != null ? _dateFmt.format(_supplyEndDate!) : '',
              child: InkWell(
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
                    labelText: '만료일 *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _supplyEndDate != null
                        ? _dateFmt.format(_supplyEndDate!)
                        : '날짜 선택',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),

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
                  decoration: InputDecoration(
                    labelText: '제조사',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('vendor', _vendorCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _modelNameCtrl,
                  decoration: InputDecoration(
                    labelText: '모델명',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('model_name', _modelNameCtrl),
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
                    suffixIcon: _suffixWithSearch(
                      'serial_number',
                      _serialNumberCtrl,
                      qr: _buildQrScanSuffix(_serialNumberCtrl),
                    ),
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
                    suffixIcon: _suffixWithSearch(
                      'mac_address',
                      _macAddressCtrl,
                      qr: _buildQrScanSuffix(_macAddressCtrl),
                    ),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 사용망 — 권장 옵션 드롭다운 (자유 입력 호환: 옛값이 옵션에 없으면 옵션 끝에 추가)
          _withSearchIcon(
            columnKey: 'network',
            value: _networkCtrl.text.trim(),
            child: DropdownButtonFormField<String>(
              value: () {
                final v = _networkCtrl.text.trim();
                if (v.isEmpty) return null;
                return networkList.contains(v) ? v : v;
              }(),
              decoration: const InputDecoration(
                labelText: '사용망',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('-')),
                ...networkList
                    .map((n) => DropdownMenuItem(value: n, child: Text(n))),
                if (_networkCtrl.text.trim().isNotEmpty &&
                    !networkList.contains(_networkCtrl.text.trim()))
                  DropdownMenuItem(
                    value: _networkCtrl.text.trim(),
                    child: Text('${_networkCtrl.text.trim()} (기타)'),
                  ),
              ],
              onChanged: readOnly
                  ? null
                  : (v) => setState(() => _networkCtrl.text = v ?? ''),
            ),
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
                  decoration: InputDecoration(
                    labelText: '실사용자 *',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('user_name', _userNameCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _userDeptCtrl,
                  decoration: InputDecoration(
                    labelText: '실사용 부서',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('user_department', _userDeptCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _userEmpIdCtrl,
                  decoration: InputDecoration(
                    labelText: '실사용자 사번',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('user_employee_id', _userEmpIdCtrl),
                  ),
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
                  decoration: InputDecoration(
                    labelText: '소유자',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('owner_name', _ownerNameCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ownerDeptCtrl,
                  decoration: InputDecoration(
                    labelText: '소유 부서',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('owner_department', _ownerDeptCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _ownerEmpIdCtrl,
                  decoration: InputDecoration(
                    labelText: '소유자 사번',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('owner_employee_id', _ownerEmpIdCtrl),
                  ),
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
                  decoration: InputDecoration(
                    labelText: '관리자',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('admin_name', _adminNameCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminDeptCtrl,
                  decoration: InputDecoration(
                    labelText: '관리 부서',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('admin_department', _adminDeptCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _adminEmpIdCtrl,
                  decoration: InputDecoration(
                    labelText: '관리자 사번',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('admin_employee_id', _adminEmpIdCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3-1. 담당자 소속 드롭다운
          _withSearchIcon(
            columnKey: 'admin_affiliation',
            value: _selectedAdminAffiliation,
            child: DropdownButtonFormField<String>(
              value: affiliationList.contains(_selectedAdminAffiliation)
                  ? _selectedAdminAffiliation
                  : null,
              decoration: const InputDecoration(
                labelText: '소속',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('-')),
                ...affiliationList
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: readOnly
                  ? null
                  : (v) => setState(() => _selectedAdminAffiliation = v),
            ),
          ),

          // 3-2. 소속이 '롯데카드 외'일 때만 표시되는 회사명
          if (_selectedAdminAffiliation == '롯데카드 외') ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _adminCompanyCtrl,
              decoration: InputDecoration(
                labelText: '회사명 *',
                hintText: '소속 회사명을 입력하세요',
                border: const OutlineInputBorder(),
                suffixIcon: _searchSuffix('admin_company', _adminCompanyCtrl),
              ),
              readOnly: readOnly,
              validator: (v) {
                if (_selectedAdminAffiliation != '롯데카드 외') return null;
                if (v == null || v.trim().isEmpty) {
                  return '소속이 [롯데카드 외]일 때 회사명을 입력하세요.';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 20),

          // ── 위치 정보 ──
          _buildSectionTitle('위치 정보'),
          const SizedBox(height: 8),

          // 건물 대분류 드롭다운
          _withSearchIcon(
            columnKey: 'building1',
            value: _selectedBuilding1,
            child: DropdownButtonFormField<String>(
              value: building1List.contains(_selectedBuilding1)
                  ? _selectedBuilding1
                  : null,
              decoration: const InputDecoration(
                labelText: '건물(대)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('-')),
                ...building1List
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))),
              ],
              onChanged: readOnly
                  ? null
                  : (v) => setState(() => _selectedBuilding1 = v),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _buildingCtrl,
                  decoration: InputDecoration(
                    labelText: '건물(상세)',
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchSuffix('building', _buildingCtrl),
                  ),
                  readOnly: readOnly,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _withSearchIcon(
                  columnKey: 'floor',
                  value: _floorCtrl.text.trim(),
                  child: DropdownButtonFormField<String>(
                    value: floorList.contains(_floorCtrl.text.trim())
                        ? _floorCtrl.text.trim()
                        : null,
                    decoration: const InputDecoration(
                      labelText: '층',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: null, child: Text('-')),
                      ...floorList
                          .map((f) => DropdownMenuItem(value: f, child: Text(f))),
                      if (_floorCtrl.text.trim().isNotEmpty &&
                          !floorList.contains(_floorCtrl.text.trim()))
                        DropdownMenuItem(
                          value: _floorCtrl.text.trim(),
                          child: Text('${_floorCtrl.text.trim()} (기타)'),
                        ),
                    ],
                    onChanged: readOnly
                        ? null
                        : (v) => setState(() => _floorCtrl.text = v ?? ''),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 도면 좌표 (도면 / 행 / 열) — 자리 단위 자산 배치
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int?>(
                  value: _drawings.any((d) => d.id == _selectedDrawingId)
                      ? _selectedDrawingId
                      : null,
                  decoration: const InputDecoration(
                    labelText: '도면',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('-')),
                    ..._drawings.map((d) => DropdownMenuItem<int?>(
                          value: d.id,
                          child: Text('${d.building} ${d.floor}'),
                        )),
                  ],
                  onChanged: readOnly
                      ? null
                      : (v) => setState(() {
                            _selectedDrawingId = v;
                            _selectedRow = null;
                            _selectedCol = null;
                            _rowInputCtrl.clear();
                            _colInputCtrl.clear();
                          }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _rowInputCtrl,
                  decoration: InputDecoration(
                    labelText: '행 (가로, 1~${_selectedDrawing?.gridRows ?? "-"})',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: readOnly || _selectedDrawingId == null,
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    final max = _selectedDrawing?.gridRows ?? 0;
                    setState(() => _selectedRow =
                        (n == null || n < 1 || n > max) ? null : n - 1);
                  },
                  validator: (v) {
                    if (_selectedDrawingId == null) return null;
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    final max = _selectedDrawing!.gridRows;
                    if (n == null || n < 1 || n > max) {
                      return '1~$max 사이 숫자';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _colInputCtrl,
                  decoration: InputDecoration(
                    labelText: '열 (세로, 1~${_selectedDrawing?.gridCols ?? "-"})',
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  readOnly: readOnly || _selectedDrawingId == null,
                  onChanged: (v) {
                    final n = int.tryParse(v.trim());
                    final max = _selectedDrawing?.gridCols ?? 0;
                    setState(() => _selectedCol =
                        (n == null || n < 1 || n > max) ? null : n - 1);
                  },
                  validator: (v) {
                    if (_selectedDrawingId == null) return null;
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    final max = _selectedDrawing!.gridCols;
                    if (n == null || n < 1 || n > max) {
                      return '1~$max 사이 숫자';
                    }
                    return null;
                  },
                ),
              ),
              if (!readOnly)
                TextButton(
                  onPressed: () => setState(() {
                    _selectedDrawingId = null;
                    _selectedRow = null;
                    _selectedCol = null;
                    _rowInputCtrl.clear();
                    _colInputCtrl.clear();
                  }),
                  child: const Text('지우기'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // ── 메모 ──
          _buildSectionTitle('메모'),
          const SizedBox(height: 8),

          TextFormField(
            controller: _normalCommentCtrl,
            decoration: InputDecoration(
              labelText: '일반 메모',
              border: const OutlineInputBorder(),
              suffixIcon: _searchSuffix('normal_comment', _normalCommentCtrl),
            ),
            readOnly: readOnly,
            maxLines: 3,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _oaCommentCtrl,
            decoration: InputDecoration(
              labelText: 'OA 메모',
              border: const OutlineInputBorder(),
              suffixIcon: _searchSuffix('oa_comment', _oaCommentCtrl),
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
            if (!isPresenceConnected && asset.lastActiveAt != null) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (ctx) {
                  final days = DateTime.now().difference(asset.lastActiveAt!).inDays;
                  final isStale = days >= 31;
                  return Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Row(
                      children: [
                        Text(
                          '미접속일: $days일',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isStale ? Colors.red.shade700 : null,
                          ),
                        ),
                        if (isStale) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '장기 미접속',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),

            // 실사 회차
            Row(
              children: [
                Icon(Icons.event_repeat, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('실사 회차', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: asset.inspectionRoundNo > 0
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${asset.inspectionRoundNo}차',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: asset.inspectionRoundNo > 0
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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

            // 관리자 명령 버튼
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetUserVerification,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('사용자 확인 초기화'),
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
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _requestForceVerify,
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: const Text('관리자 재확인 요청'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange.shade800,
                  side: BorderSide(color: Colors.orange.shade800),
                ),
              ),
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
            // 추가: OS 보안 (기기 종류별 기준 평가) ──────────
            _buildOsSecurityRow(context, deviceStatus),
            // OS별 보안패치 세부 항목
            if ((deviceStatus['os_security_patch'] as String?)?.isNotEmpty == true)
              _deviceRow('보안패치(Android)', deviceStatus['os_security_patch']),
            if ((deviceStatus['os_vendor_security_patch'] as String?)?.isNotEmpty == true)
              _deviceRow('벤더 패치', deviceStatus['os_vendor_security_patch']),
            if ((deviceStatus['os_build_number'] as String?)?.isNotEmpty == true)
              _deviceRow('OS 빌드 번호', deviceStatus['os_build_number']),
            if ((deviceStatus['os_ubr'] as String?)?.isNotEmpty == true)
              _deviceRow('UBR (Windows)', deviceStatus['os_ubr']),
            if ((deviceStatus['os_kb_list'] as String?)?.isNotEmpty == true)
              _deviceRow('적용 KB', _truncateKb(deviceStatus['os_kb_list'] as String)),
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

  /// OS 보안 상태 한 줄 — 라벨 + 색상 칩 + 상세 텍스트
  Widget _buildOsSecurityRow(
      BuildContext context, Map<String, dynamic> ds) {
    final v = evaluateOsSecurity(ds);
    final color = v.color(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 100,
            child: Text('OS 보안',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(v.icon, color: color, size: 14),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        v.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (v.detail.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      v.detail,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _truncateKb(String kbList) {
    if (kbList.length <= 60) return kbList;
    return '${kbList.substring(0, 60)}... (${kbList.split(',').length}건)';
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

  /// 사용자 확인 현황 초기화 — verification_status / last_verified_at만 리셋 (단말 알림 X)
  Future<void> _resetUserVerification() async {
    if (_asset == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사용자 확인 초기화'),
        content: const Text(
          '이 자산의 사용자 확인 기록을 미확인 상태로 되돌립니다. 단말에 알림은 전송하지 않습니다. 계속할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('초기화')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client
          .from('assets')
          .update({
            'verification_status': null,
            'last_verified_at': null,
          })
          .eq('id', _asset!.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('사용자 확인 기록 초기화 완료')),
      );
      await _loadAsset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 실패: $e')),
      );
    }
  }

  Future<void> _requestForceVerify() async {
    if (_asset == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('관리자 재확인 요청'),
        content: const Text(
          '에이전트의 사용자 확인 상태를 초기화하고 단말에 알림을 보냅니다. 계속할까요?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('요청')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Supabase.instance.client.rpc(
        'admin_force_verify',
        params: {'p_asset_uid': _asset!.assetUid},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재확인 요청 전송 완료')),
      );
      await _loadAsset();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('재확인 요청 실패: $e')),
      );
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

        // 실사 보기 버튼 — 새 실사 생성 X, 최근 실사 상세로 이동
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.tonalIcon(
            onPressed: _createInspection,
            icon: const Icon(Icons.fact_check),
            label: const Text('실사 보기'),
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
