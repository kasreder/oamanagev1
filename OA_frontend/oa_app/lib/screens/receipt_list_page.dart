import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/receipt.dart';
import '../notifiers/auth_notifier.dart';
import '../services/api_service.dart';
import '../utils/receipt_printer.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/common/empty_state_widget.dart';

/// 5.1.9 인수증 목록 (/receipts)
class ReceiptListPage extends ConsumerStatefulWidget {
  const ReceiptListPage({super.key});

  @override
  ConsumerState<ReceiptListPage> createState() => _ReceiptListPageState();
}

class _ReceiptListPageState extends ConsumerState<ReceiptListPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');
  List<Receipt> _rows = [];
  Map<int, String> _userNames = {};
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
      final rows = await _api.fetchReceipts();
      // 인쇄 시 담당자명 표시용. 실패해도 목록은 보여줌.
      Map<int, String> names = {};
      try {
        final users = await _api.fetchReceiptTeamUsers();
        names = {for (final u in users) u.id: u.employeeName};
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _userNames = names;
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '인수증',
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/receipt/new');
          _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('새 인수증'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingWidget(message: '불러오는 중...');
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _load);
    }
    if (_rows.isEmpty) {
      return const EmptyStateWidget(message: '등록된 인수증이 없습니다.');
    }
    final theme = Theme.of(context);
    final isAdmin =
        ref.watch(authNotifierProvider).valueOrNull?.user?.isAdmin ?? false;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: _rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final r = _rows[i];
          final statusColor = switch (r.status) {
            'signed' => Colors.green,
            'void' => Colors.grey,
            _ => theme.colorScheme.tertiary,
          };
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Icon(Icons.receipt_long, color: statusColor, size: 20),
              ),
              title: Text(
                _titleOf(r),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${_dateFmt.format(r.issuedAt)}'
                '${(r.receiverName?.isNotEmpty ?? false) ? " · ${r.receiverName}" : ""}'
                ' · ${_statusLabel(r.status)}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '인쇄 / PDF',
                    icon: const Icon(Icons.print, size: 20),
                    onPressed: () => _printOne(r.id),
                  ),
                  if (isAdmin)
                    IconButton(
                      tooltip: '삭제 (관리자)',
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: theme.colorScheme.error),
                      onPressed: () => _deleteOne(r),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () async {
                await context.push('/receipt/${r.id}');
                _load();
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _printOne(int id) async {
    try {
      final r = await _api.fetchReceipt(id);
      if (!mounted) return;
      await ReceiptPrinter.printReceipt(context, r, userNames: _userNames);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: SelectableText('인쇄 준비 실패: $e')));
    }
  }

  /// 관리자 삭제 — 항목은 DB CASCADE, 서명 파일은 best-effort 정리
  Future<void> _deleteOne(Receipt r) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
        title: const Text('인수증 삭제'),
        content: Text(
          '${r.vendor?.name ?? "(거래처 없음)"} · ${_dateFmt.format(r.issuedAt)} 인수증을 삭제하시겠습니까?\n\n'
          '항목과 서명 이미지가 함께 삭제되며 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteReceipt(r.id);
      // 서명 파일 정리 — 실패해도 레코드 삭제는 유지
      final paths = [r.signVendor, r.signHelpdesk, r.signItPlan]
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isNotEmpty) {
        try {
          await supabase.storage.from('receipt-signatures').remove(paths);
        } catch (_) {}
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('삭제되었습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: SelectableText('삭제 실패: $e')));
    }
  }

  /// 업체명 - 항목 요약. 항목 3개 미만: 항목명 나열 / 3개 이상: "제품 N개"
  String _titleOf(Receipt r) {
    final vendor = r.vendor?.name ?? '(거래처 없음)';
    if (r.items.isEmpty) return vendor;
    if (r.items.length < 3) {
      final names = r.items
          .map((i) => (i.name?.trim().isNotEmpty ?? false)
              ? i.name!.trim()
              : (i.category ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (names.isEmpty) return vendor;
      return '$vendor - ${names.join(', ')}';
    }
    return '$vendor - 제품 ${r.items.length}개';
  }

  String _statusLabel(String s) => switch (s) {
        'signed' => '서명완료',
        'void' => '무효',
        _ => '작성중',
      };
}
