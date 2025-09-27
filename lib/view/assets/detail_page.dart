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
  late TextEditingController _memoController;
  String _status = '사용';
  Inspection? _inspection;

  @override
  void initState() {
    super.initState();
    _memoController = TextEditingController();
  }

  @override
  void dispose() {
    _memoController.dispose();
    super.dispose();
  }

  void _loadInspection(InspectionProvider provider) {
    _inspection ??= provider.findById(widget.inspectionId);
    if (_inspection != null) {
      _status = _inspection!.status;
      _memoController.text = _inspection!.memo ?? '';
    }
  }

  void _save(InspectionProvider provider) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final inspection = (_inspection ??
            Inspection(
              id: widget.inspectionId,
              assetUid: 'UNKNOWN',
              status: _status,
              memo: _memoController.text,
              scannedAt: DateTime.now(),
              synced: false,
            ))
        .copyWith(
      status: _status,
      memo: _memoController.text,
      scannedAt: DateTime.now(),
      synced: false,
    );
    provider.addOrUpdate(inspection);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('저장되었습니다.')),
    );
  }

  void _delete(InspectionProvider provider) async {
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
    provider.remove(widget.inspectionId);
    if (!mounted) return;
    context.go('/assets');
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        _loadInspection(provider);
        final inspection = _inspection;
        final asset = inspection != null ? provider.assetOf(inspection.assetUid) : null;
        return AppScaffold(
          title: '실사 상세',
          selectedIndex: 1,
          body: inspection == null
              ? const Center(child: Text('실사 데이터를 찾을 수 없습니다.'))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        Card(
                          child: ListTile(
                            title: Text(inspection.assetUid),
                            subtitle: Text(provider.formatDateTime(inspection.scannedAt)),
                            trailing: asset != null ? Text(asset.model) : null,
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              onPressed: () => _delete(provider),
                              icon: const Icon(Icons.delete),
                              label: const Text('삭제'),
                              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
