// lib/view/assets/datail.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/inspection.dart';
import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetsDetailPage extends StatefulWidget {
  const AssetsDetailPage({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  State<AssetsDetailPage> createState() => _AssetsDetailPageState();
}

class _AssetsDetailPageState extends State<AssetsDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _memoController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _assetModelController = TextEditingController();
  final TextEditingController _assetSerialController = TextEditingController();
  final TextEditingController _assetVendorController = TextEditingController();
  final TextEditingController _assetLocationController = TextEditingController();
  final TextEditingController _assetStatusController = TextEditingController();
  final TextEditingController _assetTypeController = TextEditingController();
  final TextEditingController _assetOrganizationController = TextEditingController();
  final TextEditingController _assetOsController = TextEditingController();
  final TextEditingController _assetOsVersionController = TextEditingController();
  final TextEditingController _assetNetworkController = TextEditingController();
  final TextEditingController _assetUserController = TextEditingController();
  final TextEditingController _assetMemoController = TextEditingController();
  final TextEditingController _assetMemo2Controller = TextEditingController();
  
  String _inspectionStatus = '사용';
  Inspection? _inspection;
  String? _selectedAssetUid;
  bool _assetNotFound = false;
  bool _initialLoadDone = false;
  bool _isEditing = false;

  @override
  void dispose() {
    _memoController.dispose();
    _searchController.dispose();
    _assetNameController.dispose();
    _assetModelController.dispose();
    _assetSerialController.dispose();
    _assetVendorController.dispose();
    _assetLocationController.dispose();
    _assetStatusController.dispose();
    _assetTypeController.dispose();
    _assetOrganizationController.dispose();
    _assetOsController.dispose();
    _assetOsVersionController.dispose();
    _assetNetworkController.dispose();
    _assetUserController.dispose();
    _assetMemoController.dispose();
    _assetMemo2Controller.dispose();

    super.dispose();
  }

  void _ensureInitialLoad(InspectionProvider provider) {
    if (_initialLoadDone) {
      return;
    }
    _initialLoadDone = true;

    final inspection =
        provider.findById(widget.inspectionId) ?? provider.latestByAssetUid(widget.inspectionId);
    if (inspection != null) {
      _inspection = inspection;
      _selectedAssetUid = inspection.assetUid;
      _inspectionStatus = _normalizeStatus(inspection.status);
      final memo = inspection.memo ?? '';
      _memoController.text = memo;
      _memoController.selection = TextSelection.collapsed(offset: memo.length);
      _searchController.text = inspection.assetUid;
      final asset = provider.assetOf(inspection.assetUid);
      if (asset != null) {
        _populateAssetControllers(asset);
      }
      return;
    }

    final asset = provider.assetOf(widget.inspectionId);
    if (asset != null) {
      _selectedAssetUid = asset.uid;
      _inspectionStatus = _normalizeStatus(
        asset.status.isNotEmpty ? asset.status : '사용',
      );
      _populateAssetControllers(asset);
      _searchController.text = asset.uid;
    }
  }

  void _performSearch(InspectionProvider provider) {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _selectedAssetUid = null;
        _inspection = null;
        _inspectionStatus = '사용';
        _assetNotFound = false;
      });
      _memoController
        ..text = ''
        ..selection = const TextSelection.collapsed(offset: 0);
      _clearAssetControllers();
      return;
    }

    final asset = provider.assetOf(query);
    final inspection = provider.latestByAssetUid(query);
    final nextStatus = inspection?.status ??
        (asset != null && asset.status.isNotEmpty ? asset.status : '사용');
    final memo = inspection?.memo ?? '';

    setState(() {
      _selectedAssetUid = asset?.uid;
      _inspection = inspection;
      _inspectionStatus = _normalizeStatus(nextStatus);
      _assetNotFound = asset == null;
      _isEditing = false;
    });
    _memoController
      ..text = memo
      ..selection = TextSelection.collapsed(offset: memo.length);
    if (asset != null) {
      _populateAssetControllers(asset);
    } else {
      _clearAssetControllers();
    }

    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자산을 찾을 수 없습니다: $query')),
      );
    }
  }

  void _populateAssetControllers(AssetInfo asset) {
    _setControllerText(_assetNameController, asset.name);
    _setControllerText(_assetModelController, asset.model);
    _setControllerText(_assetSerialController, asset.serial);
    _setControllerText(_assetVendorController, asset.vendor);
    _setControllerText(_assetLocationController, asset.location);
    _setControllerText(_assetStatusController, asset.status);
    _setControllerText(_assetTypeController, asset.assets_types);
    _setControllerText(_assetOrganizationController, asset.organization);
    _setControllerText(_assetOsController, _metadataValue(asset, 'os'));
    _setControllerText(_assetOsVersionController, _metadataValue(asset, 'os_ver'));
    _setControllerText(_assetNetworkController, _metadataValue(asset, 'network'));
    _setControllerText(_assetUserController, _metadataValue(asset, 'member_name'));
    _setControllerText(_assetMemoController, _metadataValue(asset, 'memo'));
    _setControllerText(_assetMemo2Controller, _metadataValue(asset, 'memo2'));

  }

  void _clearAssetControllers() {
    for (final controller in [
      _assetNameController,
      _assetModelController,
      _assetSerialController,
      _assetVendorController,
      _assetLocationController,
      _assetStatusController,
      _assetTypeController,
      _assetOrganizationController,
      _assetOsController,
      _assetOsVersionController,
      _assetNetworkController,
      _assetUserController,
      _assetMemoController,
      _assetMemo2Controller,

    ]) {
      _setControllerText(controller, '');
    }
  }

  void _setControllerText(TextEditingController controller, String value) {
    controller
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
  }

  String _normalizeStatus(String status) {
    const allowed = {'사용', '가용(창고)', '이동'};
    if (allowed.contains(status)) {
      return status;
    }
    if (status.isEmpty) {
      return '사용';
    }
    return status;
  }

  void _save(InspectionProvider provider) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final assetUid = _selectedAssetUid;
    if (assetUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자산 UID를 먼저 검색해주세요.')),
      );
      return;
    }
    final now = DateTime.now();
    final inspection = (_inspection ??
            Inspection(
              id: _inspection?.id ?? 'ins_${assetUid}_${now.millisecondsSinceEpoch}',
              assetUid: assetUid,
              status: _inspectionStatus,
              memo: _memoController.text,
              scannedAt: now,
              synced: false,
            ))
        .copyWith(
      status: _inspectionStatus,
      memo: _memoController.text,
      scannedAt: now,
      synced: false,
    );
    provider.addOrUpdate(inspection);
    final asset = provider.assetOf(assetUid);
    if (asset != null) {
      final updatedMetadata = Map<String, String>.from(asset.metadata);
      void updateMetadata(String key, TextEditingController controller) {
        final value = controller.text.trim();
        if (value.isEmpty) {
          updatedMetadata.remove(key);
        } else {
          updatedMetadata[key] = value;
        }
      }

      updateMetadata('os', _assetOsController);
      updateMetadata('os_ver', _assetOsVersionController);
      updateMetadata('network', _assetNetworkController);
      updateMetadata('member_name', _assetUserController);
      updateMetadata('memo', _assetMemoController);
      updateMetadata('memo2', _assetMemo2Controller);

      provider.upsertAssetInfo(
        AssetInfo(
          uid: asset.uid,
          name: _assetNameController.text.trim(),
          model: _assetModelController.text.trim(),
          serial: _assetSerialController.text.trim(),
          vendor: _assetVendorController.text.trim(),
          location: _assetLocationController.text.trim(),
          status: _assetStatusController.text.trim(),
          assets_types: _assetTypeController.text.trim(),
          organization: _assetOrganizationController.text.trim(),
          metadata: updatedMetadata,

        ),
      );
    }
    setState(() {
      _inspection = inspection;
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.')),
    );
  }

  void _cancelEditing(InspectionProvider provider) {
    final inspection = _inspection;
    if (inspection != null) {
      final memo = inspection.memo ?? '';
      _memoController
        ..text = memo
        ..selection = TextSelection.collapsed(offset: memo.length);
      setState(() {
        _inspectionStatus = _normalizeStatus(inspection.status);
        _isEditing = false;
      });
      final asset = _selectedAssetUid != null
          ? provider.assetOf(_selectedAssetUid!)
          : null;
      if (asset != null) {
        _populateAssetControllers(asset);
      }
      return;
    }

    final assetUid = _selectedAssetUid;
    final asset = assetUid != null ? provider.assetOf(assetUid) : null;
    final nextStatus = asset != null && asset.status.isNotEmpty ? asset.status : '사용';
    _memoController
      ..text = ''
      ..selection = const TextSelection.collapsed(offset: 0);
    setState(() {
      _inspectionStatus = _normalizeStatus(nextStatus);
      _isEditing = false;
    });
    if (asset != null) {
      _populateAssetControllers(asset);
    } else {
      _clearAssetControllers();
    }
  }

  void _delete(InspectionProvider provider) async {
    final inspection = _inspection;
    if (inspection == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('삭제 확인'),
            content: const Text('실사 내역을 삭제하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    provider.remove(inspection.id);
    if (!mounted) return;
    context.go('/assets');
  }

  Widget _buildSearchSection(InspectionProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '자산 UID 검색',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'asset_uid 입력',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _performSearch(provider),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  onPressed: () => _performSearch(provider),
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                ),
              ],
            ),
            if (_assetNotFound)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  '일치하는 자산이 없습니다. asset_uid를 확인해주세요.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetInfo(AssetInfo asset) {
    final metadataRows = _buildAssetMetadataRows(asset);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              asset.name.isEmpty ? '자산 정보' : asset.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _infoRow('자산 UID', asset.uid),
            if (_isEditing)
              _editField(controller: _assetNameController, label: '자산명')
            else
              _infoRow('자산명', asset.name),
            if (_isEditing)
              _editField(controller: _assetModelController, label: '모델명')
            else
              _infoRow('모델명', asset.model),
            if (_isEditing)
              _editField(controller: _assetSerialController, label: '시리얼')
            else
              _infoRow('시리얼', asset.serial),
            if (_isEditing)
              _editField(controller: _assetVendorController, label: '제조사')
            else
              _infoRow('제조사', asset.vendor),
            if (_isEditing)
              _editField(controller: _assetLocationController, label: '위치')
            else
              _infoRow('위치', asset.location),
            if (_isEditing)
              _editField(controller: _assetStatusController, label: '자산 상태')
            else
              _infoRow('자산 상태', asset.status.isEmpty ? '-' : asset.status),
            if (_isEditing)
              _editField(controller: _assetTypeController, label: '장비 종류')
            else
              _infoRow('장비 종류',
                  asset.assets_types.isEmpty ? '-' : asset.assets_types),
            if (_isEditing)
              _editField(controller: _assetOrganizationController, label: '소속 조직')
            else
              _infoRow('소속 조직',
                  asset.organization.isEmpty ? '-' : asset.organization),
            if (_isEditing)
              _editField(controller: _assetOsController, label: '운영체제')
            else
              _infoRow('운영체제', _metadataValue(asset, 'os')),
            if (_isEditing)
              _editField(controller: _assetOsVersionController, label: '운영체제 버전')
            else
              _infoRow('운영체제 버전', _metadataValue(asset, 'os_ver')),
            if (_isEditing)
              _editField(controller: _assetNetworkController, label: '네트워크')
            else
              _infoRow('네트워크', _metadataValue(asset, 'network')),
            if (_isEditing)
              _editField(controller: _assetUserController, label: '사용자')
            else
              _infoRow('사용자', _metadataValue(asset, 'member_name')),
            if (_isEditing)
              _editField(
                controller: _assetMemoController,
                label: '메모',
                maxLines: 3,
              )
            else
              _infoRow('메모', _metadataValue(asset, 'memo')),
            if (_isEditing)
              _editField(
                controller: _assetMemo2Controller,
                label: '메모2',
                maxLines: 3,
              )
            else
              _infoRow('메모2', _metadataValue(asset, 'memo2')),

            if (metadataRows.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                '자산 상세 정보',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...metadataRows,
            ],
          ],
        ),
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,

  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        maxLines: maxLines,

      ),
    );
  }

  List<Widget> _buildAssetMetadataRows(AssetInfo asset) {
    const primaryKeys = {
      'uid',
      'asset_uid',
      'name',
      'model',
      'model_name',
      'serial',
      'serial_number',
      'vendor',
      'location',
      'building',
      'building1',
      'floor',
      'location_row',
      'location_col',
      'assets_status',
      'status',
      'assets_types',
      'organization',
      'os',
      'os_ver',
      'network',
      'member_name',
      'memo',
      'memo1',
      'memo2',
    };
    final entries = asset.metadata.entries
        .where((entry) => entry.value.isNotEmpty)
        .where((entry) => !primaryKeys.contains(entry.key))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return entries
        .map(
          (entry) => _infoRow(_assetFieldLabel(entry.key), entry.value),
        )
        .toList(growable: false);
  }

  String _assetFieldLabel(String key) {
    switch (key) {
      case 'network':
        return '네트워크';
      case 'physical_check_date':
        return '실사일';
      case 'confirmation_date':
        return '확인일';
      case 'normal_comment':
        return '일반 코멘트';
      case 'oa_comment':
        return 'OA 코멘트';
      case 'mac_address':
        return 'MAC 주소';
      case 'location_drawing_id':
        return '도면 ID';
      case 'location_drawing_file':
        return '도면 파일';
      case 'memo1':
        return '메모1';
      case 'memo2':
        return '메모2';
      case 'memo':
        return '메모';
      case 'os':
        return '운영체제';
      case 'os_ver':
        return '운영체제 버전';
      case 'user_id':
        return '사용자 ID';
      case 'member_name':
        return '사용자';
      case 'organization_hq':
        return '본부';
      case 'organization_dept':
        return '부서';
      case 'organization_team':
        return '팀';
      case 'organization_part':
        return '파트';
      case 'created_at':
        return '생성일';
      case 'updated_at':
        return '수정일';
      default:
        return key;
    }
  }

  String _metadataValue(AssetInfo asset, String key) {
    return asset.metadata[key] ?? '';
  }
  Widget _buildInspectionMeta(InspectionProvider provider) {
    final inspection = _inspection;
    if (inspection == null) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '최근 실사 이력',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _infoRow('상태', _isEditing ? _inspectionStatus : inspection.status),
            _infoRow('스캔 일시', provider.formatDateTime(inspection.scannedAt)),
            _infoRow('동기화', inspection.synced ? '완료' : '대기 중'),
            if ((inspection.memo ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _infoRow('메모', inspection.memo ?? ''),
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        _ensureInitialLoad(provider);
        final asset =
            _selectedAssetUid != null ? provider.assetOf(_selectedAssetUid!) : null;
        final hasAsset = asset != null;

        return AppScaffold(
          title: '자산 상세',
          selectedIndex: 1,
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildSearchSection(provider),
                const SizedBox(height: 16),
                if (hasAsset) _buildAssetInfo(asset!),
                if (hasAsset) ...[
                  const SizedBox(height: 16),
                  _buildInspectionMeta(provider),
                  const SizedBox(height: 16),
                  if (_isEditing)
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '실사 수정',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _inspectionStatus,
                            decoration: const InputDecoration(labelText: '상태'),
                            items: const [
                              DropdownMenuItem(value: '사용', child: Text('사용')),
                              DropdownMenuItem(value: '가용(창고)', child: Text('가용(창고)')),
                              DropdownMenuItem(value: '이동', child: Text('이동')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _inspectionStatus = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _memoController,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              labelText: '메모',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              FilledButton(
                                onPressed: () => _save(provider),
                                child: const Text('저장'),
                              ),
                              const SizedBox(width: 12),
                              OutlinedButton(
                                onPressed: () => _cancelEditing(provider),
                                child: const Text('취소'),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed:
                                    _inspection == null ? null : () => _delete(provider),
                                icon: const Icon(Icons.delete),
                                label: const Text('삭제'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _isEditing = true;
                            });
                          },
                          child: const Text('수정'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => context.go('/assets'),
                          child: const Text('완료'),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed:
                              _inspection == null ? null : () => _delete(provider),
                          icon: const Icon(Icons.delete),
                          label: const Text('삭제'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                ] else if (!_assetNotFound) ...[
                  const SizedBox(height: 24),
                  const Center(child: Text('asset_uid를 검색하여 자산 정보를 확인하세요.')),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}