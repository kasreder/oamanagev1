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
  String _status = '사용';
  Inspection? _inspection;
  String? _selectedAssetUid;
  bool _assetNotFound = false;
  bool _initialLoadDone = false;

  @override
  void dispose() {
    _memoController.dispose();
    _searchController.dispose();
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
      _status = inspection.status;
      final memo = inspection.memo ?? '';
      _memoController.text = memo;
      _memoController.selection = TextSelection.collapsed(offset: memo.length);
      _searchController.text = inspection.assetUid;
      return;
    }

    final asset = provider.assetOf(widget.inspectionId);
    if (asset != null) {
      _selectedAssetUid = asset.uid;
      _status = asset.status.isNotEmpty ? asset.status : '사용';
      _searchController.text = asset.uid;
    }
  }

  void _performSearch(InspectionProvider provider) {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _selectedAssetUid = null;
        _inspection = null;
        _status = '사용';
        _assetNotFound = false;
      });
      _memoController
        ..text = ''
        ..selection = const TextSelection.collapsed(offset: 0);
      return;
    }

    final asset = provider.assetOf(query);
    final inspection = provider.latestByAssetUid(query);
    final nextStatus = inspection?.status ?? (asset != null && asset.status.isNotEmpty
        ? asset.status
        : '사용');
    final memo = inspection?.memo ?? '';

    setState(() {
      _selectedAssetUid = asset?.uid;
      _inspection = inspection;
      _status = nextStatus;
      _assetNotFound = asset == null;
    });
    _memoController
      ..text = memo
      ..selection = TextSelection.collapsed(offset: memo.length);

    if (asset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('자산을 찾을 수 없습니다: $query')),
      );
    }
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
              status: _status,
              memo: _memoController.text,
              scannedAt: now,
              synced: false,
            ))
        .copyWith(
      status: _status,
      memo: _memoController.text,
      scannedAt: now,
      synced: false,
    );
    provider.addOrUpdate(inspection);
    setState(() {
      _inspection = inspection;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.')),
    );
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
            _infoRow('모델명', asset.model),
            _infoRow('시리얼', asset.serial),
            _infoRow('제조사', asset.vendor),
            _infoRow('위치', asset.location),
            _infoRow('자산 상태', asset.status.isEmpty ? '-' : asset.status),
            _infoRow('장비 종류', asset.assets_types.isEmpty ? '-' : asset.assets_types),
            _infoRow('소속 조직', asset.organization.isEmpty ? '-' : asset.organization),
          ],
        ),
      ),
    );
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
            _infoRow('상태', inspection.status),
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
                          value: _status,
                          decoration: const InputDecoration(labelText: '상태'),
                          items: const [
                            DropdownMenuItem(value: '사용', child: Text('사용')),
                            DropdownMenuItem(value: '가용(창고)', child: Text('가용(창고)')),
                            DropdownMenuItem(value: '이동', child: Text('이동')),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _status = value;
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
                              onPressed: () => context.go('/assets'),
                              child: const Text('완료'),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _inspection == null
                                  ? null
                                  : () => _delete(provider),
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