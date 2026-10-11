import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/vendor.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 거래처 관리 (/admin/vendors) — admin만
class VendorManagerPage extends ConsumerStatefulWidget {
  const VendorManagerPage({super.key});

  @override
  ConsumerState<VendorManagerPage> createState() => _State();
}

class _State extends ConsumerState<VendorManagerPage> {
  final _api = ApiService();
  List<Vendor> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.fetchVendors(includeInactive: true);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showForm({Vendor? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final variantCtrl =
        TextEditingController(text: existing?.templateVariant ?? 'default');
    final orderCtrl =
        TextEditingController(text: '${existing?.displayOrder ?? 0}');
    bool active = existing?.isActive ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(existing == null ? '거래처 등록' : '거래처 수정'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                      labelText: '거래처명 *', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: variantCtrl,
                  decoration: const InputDecoration(
                      labelText: '양식 변형 키',
                      helperText:
                          'default / aj(AJ네트웍스) / koffice(한국오피스) / iguard(아이가드) / ctok(씨토크) / boim(보임)',
                      helperMaxLines: 3,
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: orderCtrl,
                  decoration: const InputDecoration(
                      labelText: '표시 순서',
                      border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('활성'),
                  value: active,
                  onChanged: (v) => setSt(() => active = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('저장')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final name = nameCtrl.text.trim();
    if (name.isEmpty) return;
    try {
      final payload = {
        'name': name,
        'template_variant':
            variantCtrl.text.trim().isEmpty ? 'default' : variantCtrl.text.trim(),
        'display_order': int.tryParse(orderCtrl.text.trim()) ?? 0,
        'is_active': active,
      };
      if (existing == null) {
        await _api.createVendor(payload);
      } else {
        await _api.updateVendor(existing.id, payload);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: SelectableText('저장 실패: $e')));
    }
  }

  Future<void> _delete(Vendor v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('거래처 삭제'),
        content: Text('${v.name} 삭제하시겠습니까?\n연결된 인수증이 있으면 실패할 수 있습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteVendor(v.id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: SelectableText('삭제 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '거래처 관리',
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showForm(),
        icon: const Icon(Icons.add),
        label: const Text('새 거래처'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingWidget(message: '불러오는 중...');
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const EmptyStateWidget(message: '등록된 거래처가 없습니다.');
    }
    final theme = Theme.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (_, i) {
        final v = _rows[i];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              child: Icon(
                v.isActive ? Icons.storefront : Icons.storefront_outlined,
                color: v.isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
            title: Text(
              v.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                decoration:
                    v.isActive ? null : TextDecoration.lineThrough,
                color: v.isActive ? null : theme.colorScheme.outline,
              ),
            ),
            subtitle: Text(
              '양식: ${v.templateVariant} · 순서 ${v.displayOrder}'
              '${v.isActive ? "" : " · 비활성"}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '수정',
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showForm(existing: v),
                ),
                IconButton(
                  tooltip: '삭제',
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.colorScheme.error),
                  onPressed: () => _delete(v),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
