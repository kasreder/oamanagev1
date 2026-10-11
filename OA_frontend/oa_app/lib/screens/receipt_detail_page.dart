import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../main.dart';
import '../constants.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/dropdown_options_provider.dart';
import '../models/receipt.dart';
import '../models/user.dart';
import '../models/vendor.dart';
import '../services/api_service.dart';
import '../widgets/common/app_scaffold.dart';
import '../widgets/common/loading_widget.dart';
import '../widgets/common/error_widget.dart';
import '../widgets/signature_pad.dart';
import '../widgets/receipt_items_editor.dart';
import '../utils/receipt_printer.dart';

/// 5.1.9 인수증 상세/편집 (/receipt/new · /receipt/:id)
class ReceiptDetailPage extends ConsumerStatefulWidget {
  final int? receiptId;
  const ReceiptDetailPage({super.key, this.receiptId});

  @override
  ConsumerState<ReceiptDetailPage> createState() => _State();
}

class _State extends ConsumerState<ReceiptDetailPage> {
  final _api = ApiService();
  final _dateFmt = DateFormat('yyyy-MM-dd');

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<Vendor> _vendors = [];
  Receipt? _receipt;

  int? _vendorId;
  DateTime _issuedAt = DateTime.now();
  final _receiverCtrl = TextEditingController();
  final _receiverDeptCtrl = TextEditingController();
  final _receiverCompanyCtrl = TextEditingController();
  // 인수자 = 서명 담당자와 동일 ('helpdesk' | 'it_plan' | null)
  String? _receiverSameAs;
  // 인쇄 옵션 (관리자·운영자만 변경, 세션 유지)
  ReceiptPrintOptions _printOptions = const ReceiptPrintOptions();
  final _senderCompanyCtrl = TextEditingController();
  final _senderDeptCtrl = TextEditingController();
  final _senderContactCtrl = TextEditingController();
  final _senderManagerCtrl = TextEditingController();
  final _memoCtrl = TextEditingController();
  String _status = 'draft';
  String? _signVendor;
  String? _signHelpdesk;
  String? _signItPlan;
  // 서명 메타
  final _signVendorNameCtrl = TextEditingController();
  bool _signVendorAsSender = false; // 거래처 = 발송업체 동일
  int? _signHelpdeskUserId;
  int? _signItPlanUserId;
  List<User> _teamUsers = [];
  List<ReceiptItem> _items = [const ReceiptItem()];

  Map<int, String> get _userNames =>
      {for (final u in _teamUsers) u.id: u.employeeName};

  bool get _isNew => widget.receiptId == null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _receiverCtrl.dispose();
    _receiverDeptCtrl.dispose();
    _receiverCompanyCtrl.dispose();
    _senderCompanyCtrl.dispose();
    _senderDeptCtrl.dispose();
    _senderContactCtrl.dispose();
    _senderManagerCtrl.dispose();
    _memoCtrl.dispose();
    _signVendorNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vendors = await _api.fetchVendors();
      final teamUsers = await _api.fetchReceiptTeamUsers();
      Receipt? r;
      if (!_isNew) r = await _api.fetchReceipt(widget.receiptId!);
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _teamUsers = teamUsers;
        _receipt = r;
        if (r != null) {
          _signVendorNameCtrl.text = r.signVendorName ?? '';
          _signVendorAsSender = r.signVendorAsSender;
          // 팀에서 빠진 사용자는 드롭다운 값 불일치 → null 처리
          bool inTeam(int? id) => id != null && teamUsers.any((u) => u.id == id);
          _signHelpdeskUserId =
              inTeam(r.signHelpdeskUserId) ? r.signHelpdeskUserId : null;
          _signItPlanUserId =
              inTeam(r.signItPlanUserId) ? r.signItPlanUserId : null;
          _vendorId = r.vendorId;
          _issuedAt = r.issuedAt;
          _receiverCtrl.text = r.receiverName ?? '';
          _receiverDeptCtrl.text = r.receiverDepartment ?? '';
          _receiverCompanyCtrl.text = r.receiverCompany ?? '';
          _receiverSameAs = r.receiverSameAs;
          _senderCompanyCtrl.text = r.senderCompany ?? '';
          _senderDeptCtrl.text = r.senderDepartment ?? '';
          _senderContactCtrl.text = r.senderContact ?? '';
          _senderManagerCtrl.text = r.senderManager ?? '';
          _memoCtrl.text = r.memo ?? '';
          _status = r.status;
          _signVendor = r.signVendor;
          _signHelpdesk = r.signHelpdesk;
          _signItPlan = r.signItPlan;
          _items = r.items.isEmpty ? [const ReceiptItem()] : List.of(r.items);
        }
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

  String? _t(TextEditingController c) {
    final v = c.text.trim();
    return v.isEmpty ? null : v;
  }

  Map<String, dynamic> _payload() => {
        'vendor_id': _vendorId,
        'issued_at': _dateFmt.format(_issuedAt),
        'receiver_name': _t(_receiverCtrl),
        'receiver_department': _t(_receiverDeptCtrl),
        'receiver_company': _t(_receiverCompanyCtrl),
        'receiver_same_as': _receiverSameAs,
        'sender_company': _t(_senderCompanyCtrl),
        'sender_department': _t(_senderDeptCtrl),
        'sender_contact': _t(_senderContactCtrl),
        'sender_manager': _t(_senderManagerCtrl),
        'memo': _t(_memoCtrl),
        'status': _status,
        'sign_vendor': _signVendor,
        'sign_helpdesk': _signHelpdesk,
        'sign_it_plan': _signItPlan,
        'sign_vendor_name': _signVendorAsSender
            ? _t(_senderManagerCtrl)
            : _t(_signVendorNameCtrl),
        'sign_vendor_as_sender': _signVendorAsSender,
        'sign_helpdesk_user_id': _signHelpdeskUserId,
        'sign_it_plan_user_id': _signItPlanUserId,
      };

  Future<void> _save() async {
    if (_vendorId == null) {
      _snack('거래처를 선택해 주세요.');
      return;
    }
    setState(() => _saving = true);
    try {
      Receipt r;
      if (_isNew) {
        r = await _api.createReceipt(_payload());
      } else {
        r = await _api.updateReceipt(widget.receiptId!, _payload());
      }
      // 항목은 별도 replace
      final valid = _items
          .where((i) =>
              (i.name?.trim().isNotEmpty ?? false) ||
              (i.sn?.trim().isNotEmpty ?? false) ||
              (i.category?.trim().isNotEmpty ?? false))
          .toList();
      await _api.replaceReceiptItems(r.id, valid);
      if (!mounted) return;
      _snack('저장 완료');
      if (_isNew) {
        context.go('/receipt/${r.id}');
      } else {
        await _load();
      }
    } catch (e) {
      _snack('저장 실패: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openSignatureDialog({
    required String label,
    required String bucketField, // sign_vendor / sign_helpdesk / sign_it_plan
    required ValueChanged<String> onSaved,
  }) async {
    if (_isNew) {
      _snack('먼저 저장한 뒤 서명하세요.');
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('$label 서명',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SignaturePadWidget(
                transparentBackground: true,
                onCompleted: (bytes) async {
                  Navigator.pop(ctx);
                  final path = await _uploadSignature(bytes, bucketField);
                  onSaved(path);
                  await _persistSignatureField(bucketField, path);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String> _uploadSignature(Uint8List bytes, String field) async {
    final id = widget.receiptId!;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = '$id/$field-$ts.png';
    await supabase.storage.from('receipt-signatures').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
        );
    return path;
  }

  Future<void> _persistSignatureField(String field, String path) async {
    // 재서명 시 이전 서명 파일 삭제 (고아 파일 방지)
    final oldPath = switch (field) {
      'sign_vendor' => _signVendor,
      'sign_helpdesk' => _signHelpdesk,
      _ => _signItPlan,
    };
    await _api.updateReceipt(widget.receiptId!, {field: path});
    if (oldPath != null && oldPath.isNotEmpty && oldPath != path) {
      try {
        await supabase.storage.from('receipt-signatures').remove([oldPath]);
      } catch (_) {} // 삭제 실패는 무시 — 참조는 이미 새 파일로 교체됨
    }
    if (!mounted) return;
    setState(() {
      if (field == 'sign_vendor') _signVendor = path;
      if (field == 'sign_helpdesk') _signHelpdesk = path;
      if (field == 'sign_it_plan') _signItPlan = path;
    });
    // 3개 모두 서명되면 자동 signed
    if (_signVendor != null && _signHelpdesk != null && _signItPlan != null) {
      await _api.updateReceipt(widget.receiptId!, {'status': 'signed'});
      if (!mounted) return;
      setState(() => _status = 'signed');
    }
  }

  /// 인수자 = 담당자와 동일 체크 (상호배타). 체크 시 담당자 이름을 인수자란에 반영.
  void _setReceiverSameAs(String? team) {
    setState(() {
      _receiverSameAs = team;
      _syncReceiverFromTeam();
    });
  }

  void _syncReceiverFromTeam() {
    if (_receiverSameAs == null) return;
    final id = _receiverSameAs == 'helpdesk'
        ? _signHelpdeskUserId
        : _signItPlanUserId;
    if (id == null) {
      _receiverSameAs = null; // 담당자 해제되면 동일함도 해제
      return;
    }
    User? u;
    for (final x in _teamUsers) {
      if (x.id == id) u = x;
    }
    // 인수업체/인수부서/인수자 3칸 모두 담당자 인원정보로 채움
    _receiverCompanyCtrl.text =
        _receiverSameAs == 'helpdesk' ? '헬프데스크' : 'IT기획팀';
    _receiverDeptCtrl.text = u?.organizationDept ?? '';
    _receiverCtrl.text = u?.employeeName ?? '';
  }

  /// 미리보기 — 앱 안 다이얼로그로 바로 표시 (다운로드/인쇄창 없음)
  Future<void> _preview() async {
    if (_vendorId == null) {
      _snack('거래처를 선택해 주세요.');
      return;
    }
    await ReceiptPrinter.showPreviewDialog(
      context,
      _currentDraft(),
      userNames: _userNames,
      options: _printOptions,
      title: '인수증 미리보기',
    );
  }

  /// 화면의 현재 입력값(미저장 포함)으로 즉시 인쇄/미리보기.
  /// 표시 옵션은 서명 카드 아래 체크박스(관리자·운영자)에서 설정.
  Future<void> _print() async {
    if (_vendorId == null) {
      _snack('거래처를 선택해 주세요.');
      return;
    }
    await ReceiptPrinter.printReceipt(context, _currentDraft(),
        userNames: _userNames, options: _printOptions);
  }

  /// 현재 폼 상태 → Receipt (인쇄 전용 드래프트)
  Receipt _currentDraft() {
    Vendor? vendor;
    for (final v in _vendors) {
      if (v.id == _vendorId) vendor = v;
    }
    final valid = _items
        .where((i) =>
            (i.name?.trim().isNotEmpty ?? false) ||
            (i.sn?.trim().isNotEmpty ?? false) ||
            (i.category?.trim().isNotEmpty ?? false))
        .toList();
    return Receipt(
      id: widget.receiptId ?? 0,
      vendorId: _vendorId,
      issuedAt: _issuedAt,
      receiverName: _t(_receiverCtrl),
      receiverDepartment: _t(_receiverDeptCtrl),
      receiverCompany: _t(_receiverCompanyCtrl),
      receiverSameAs: _receiverSameAs,
      senderCompany: _t(_senderCompanyCtrl),
      senderDepartment: _t(_senderDeptCtrl),
      senderContact: _t(_senderContactCtrl),
      senderManager: _t(_senderManagerCtrl),
      memo: _t(_memoCtrl),
      status: _status,
      signVendor: _signVendor,
      signHelpdesk: _signHelpdesk,
      signItPlan: _signItPlan,
      signVendorName: _signVendorAsSender
          ? _t(_senderManagerCtrl)
          : _t(_signVendorNameCtrl),
      signVendorAsSender: _signVendorAsSender,
      signHelpdeskUserId: _signHelpdeskUserId,
      signItPlanUserId: _signItPlanUserId,
      vendor: vendor,
      items: [
        for (var i = 0; i < valid.length; i++)
          valid[i].copyWith(rowNo: i + 1),
      ],
    );
  }

  void _snack(String s) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: SelectableText(s)));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: _isNew ? '새 인수증' : '인수증 #${widget.receiptId}',
      actions: [
        IconButton(
          tooltip: '미리보기 · 인쇄 / PDF (현재 입력값 기준)',
          icon: const Icon(Icons.print),
          onPressed: _print,
        ),
      ],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const LoadingWidget(message: '불러오는 중...');
    if (_error != null) {
      return AppErrorWidget(message: _error!, onRetry: _load);
    }
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 상단 카드 (거래처/날짜/상태)
          _card(
            title: '기본 정보',
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _vendorId,
                  decoration: const InputDecoration(
                    labelText: '거래처 *',
                    border: OutlineInputBorder(),
                  ),
                  items: _vendors
                      .map((v) => DropdownMenuItem(
                          value: v.id, child: Text(v.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _issuedAt,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _issuedAt = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '발행일',
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_dateFmt.format(_issuedAt)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '상태',
                          border: OutlineInputBorder(),
                        ),
                        child: Text(_status == 'signed'
                            ? '서명완료'
                            : _status == 'void'
                                ? '무효'
                                : '작성중'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _twoColRow([
                  TextField(
                    controller: _receiverCompanyCtrl,
                    decoration: const InputDecoration(
                      labelText: '인수업체',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: _receiverSameAs != null,
                  ),
                  TextField(
                    controller: _receiverDeptCtrl,
                    decoration: const InputDecoration(
                      labelText: '인수부서',
                      border: OutlineInputBorder(),
                    ),
                    readOnly: _receiverSameAs != null,
                  ),
                  TextField(
                    controller: _receiverCtrl,
                    decoration: InputDecoration(
                      labelText: '인수자',
                      helperText: _receiverSameAs == 'helpdesk'
                          ? '헬프데스크 담당자와 동일'
                          : _receiverSameAs == 'it_plan'
                              ? 'IT기획팀 담당자와 동일'
                              : null,
                      border: const OutlineInputBorder(),
                    ),
                    readOnly: _receiverSameAs != null,
                  ),
                ]),
                const SizedBox(height: 12),
                _twoColRow([
                  TextField(
                    controller: _senderCompanyCtrl,
                    decoration: InputDecoration(
                      labelText: '발송업체',
                      border: const OutlineInputBorder(),
                      suffixIcon: PopupMenuButton<String>(
                        tooltip: '거래처 목록에서 선택',
                        icon: const Icon(Icons.arrow_drop_down),
                        onSelected: (name) =>
                            setState(() => _senderCompanyCtrl.text = name),
                        itemBuilder: (_) => _vendors
                            .map((v) => PopupMenuItem(
                                value: v.name, child: Text(v.name)))
                            .toList(),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _senderDeptCtrl,
                    decoration: const InputDecoration(
                      labelText: '발송부서',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextField(
                    controller: _senderManagerCtrl,
                    decoration: const InputDecoration(
                      labelText: '발송담당자',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 항목 편집기
          _card(
            title: '항목',
            child: ReceiptItemsEditor(
              items: _items,
              categoryOptions: ref
                      .watch(dropdownOptionsProvider(
                          const DropdownKey('asset_detail', 'category')))
                      .valueOrNull ??
                  assetCategories,
              onChanged: (v) => setState(() => _items = v),
            ),
          ),
          const SizedBox(height: 16),

          // 메모
          _card(
            title: '비고',
            child: TextField(
              controller: _memoCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '자유 메모',
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 서명 3칸
          _card(
            title: '서명',
            child: Column(
              children: [
                _signRow(
                    _signVendorAsSender ? '거래처(발송업체)' : '거래처',
                    _signVendor,
                    'sign_vendor',
                    (v) => _signVendor = v),
                _vendorSignExtras(),
                const Divider(),
                _signRow('헬프데스크', _signHelpdesk, 'sign_helpdesk',
                    (v) => _signHelpdesk = v),
                _teamPicker('helpdesk', _signHelpdeskUserId,
                    (v) => setState(() {
                      _signHelpdeskUserId = v;
                      if (_receiverSameAs == 'helpdesk') {
                        _syncReceiverFromTeam();
                      }
                    })),
                const Divider(),
                _signRow('IT기획팀', _signItPlan, 'sign_it_plan',
                    (v) => _signItPlan = v),
                _teamPicker('it_plan', _signItPlanUserId,
                    (v) => setState(() {
                      _signItPlanUserId = v;
                      if (_receiverSameAs == 'it_plan') {
                        _syncReceiverFromTeam();
                      }
                    })),
              ],
            ),
          ),

          // 인쇄 표시 옵션 — 관리자·운영자만
          // ✓ 보임 / – 값만 공란(수기 기입) / ☐ 항목 숨김 (3단 체크)
          if (ref.watch(authNotifierProvider).valueOrNull?.user?.isAdminGroup ??
              false) ...[
            const SizedBox(height: 16),
            _card(
              title: '인쇄 표시 옵션 (관리자·운영자)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _printOptCheck(
                        '발행일',
                        _printOptions.issuedAt,
                        (m) => ReceiptPrintOptions(
                            issuedAt: m,
                            confirmDate: _printOptions.confirmDate,
                            docNo: _printOptions.docNo),
                        guardOther: () => _printOptions.confirmDate,
                      ),
                      const SizedBox(width: 12),
                      _printOptCheck(
                        '확인일',
                        _printOptions.confirmDate,
                        (m) => ReceiptPrintOptions(
                            issuedAt: _printOptions.issuedAt,
                            confirmDate: m,
                            docNo: _printOptions.docNo),
                        guardOther: () => _printOptions.issuedAt,
                      ),
                      const SizedBox(width: 12),
                      _printOptCheck(
                        '문서번호',
                        _printOptions.docNo,
                        (m) => ReceiptPrintOptions(
                            issuedAt: _printOptions.issuedAt,
                            confirmDate: _printOptions.confirmDate,
                            docNo: m),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '✓ 보임 · – 값만 공란(수기 기입) · ☐ 항목 숨김\n'
                    '발행일·확인일 중 하나는 반드시 표시(✓ 또는 –)되어야 합니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          FilledButton.icon(
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: _saving ? null : _save,
            label: Text(_isNew ? '저장' : '수정 저장'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.visibility),
                  label: const Text('미리보기'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _print,
                  icon: const Icon(Icons.print),
                  label: const Text('인쇄 / PDF'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (_receipt != null)
            Text(
              '생성 ${_receipt!.createdAt}  ·  수정 ${_receipt!.updatedAt}',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
        ],
      ),
    );
  }

  /// 데스크탑: 한 줄 N열 / 모바일(<600px): 화면 절반씩 2열
  Widget _twoColRow(List<Widget> fields) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (!isMobile) {
      return Row(children: [
        for (int i = 0; i < fields.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: fields[i]),
        ],
      ]);
    }
    // Row+Expanded 고정 2열 (Wrap은 폭 오차로 1열로 무너질 수 있음)
    return Column(children: [
      for (int i = 0; i < fields.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(children: [
          Expanded(child: fields[i]),
          const SizedBox(width: 8),
          Expanded(
              child: i + 1 < fields.length
                  ? fields[i + 1]
                  : const SizedBox()),
        ]),
      ],
    ]);
  }

  Widget _card({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _signRow(
    String label,
    String? path,
    String field,
    ValueChanged<String> onSaved,
  ) {
    final signed = path != null && path.isNotEmpty;
    final row = Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Icon(
          signed ? Icons.check_circle : Icons.radio_button_unchecked,
          color: signed ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(signed ? '완료' : '미서명'),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _openSignatureDialog(
            label: label,
            bucketField: field,
            onSaved: onSaved,
          ),
          icon: const Icon(Icons.draw),
          label: Text(signed ? '재서명' : '서명'),
        ),
      ],
    );
    if (!signed) return row;
    // 서명 완료 시 펼치기로 저장된 서명 이미지 확인
    return ExpansionTile(
      key: ValueKey('$field:$path'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      shape: const Border(),
      title: row,
      children: [_signPreview(path)],
    );
  }

  /// 저장된 서명 이미지 미리보기 (private 버킷 → signed URL)
  Widget _signPreview(String path) {
    return FutureBuilder<String>(
      future: supabase.storage
          .from('receipt-signatures')
          .createSignedUrl(path, 300),
      builder: (ctx, snap) {
        if (snap.hasError) {
          return Text('서명 이미지를 불러올 수 없습니다.',
              style: Theme.of(ctx).textTheme.bodySmall);
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
                child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Image.network(snap.data!, fit: BoxFit.contain),
        );
      },
    );
  }

  /// 인쇄 옵션 3단 체크박스 — true=보임 / null(–)=값만 공란 / false=숨김.
  /// [guardOther]가 주어지면(발행일↔확인일) 둘 다 숨김이 되는 조작을 차단.
  Widget _printOptCheck(
    String label,
    PrintFieldMode value,
    ReceiptPrintOptions Function(PrintFieldMode) apply, {
    PrintFieldMode Function()? guardOther,
  }) {
    bool? toCheck(PrintFieldMode m) => switch (m) {
          PrintFieldMode.shown => true,
          PrintFieldMode.blank => null,
          PrintFieldMode.hidden => false,
        };
    PrintFieldMode toMode(bool? v) => switch (v) {
          true => PrintFieldMode.shown,
          null => PrintFieldMode.blank,
          false => PrintFieldMode.hidden,
        };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          tristate: true,
          visualDensity: VisualDensity.compact,
          value: toCheck(value),
          onChanged: (v) {
            final next = toMode(v);
            if (next == PrintFieldMode.hidden &&
                guardOther != null &&
                guardOther() == PrintFieldMode.hidden) {
              _snack('발행일·확인일 중 하나는 표시(✓ 또는 –)되어야 합니다.');
              return;
            }
            setState(() => _printOptions = apply(next));
          },
        ),
        Text(label),
      ],
    );
  }

  /// 거래처 서명 부가 옵션 — 거래처=발송업체 동일 체크 + 담당자명
  /// 체크 시 담당자명이 발송담당자로 자동 채워지고 인쇄에도 그 이름이 들어간다.
  Widget _vendorSignExtras() {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          Checkbox(
            value: _signVendorAsSender,
            onChanged: (v) =>
                setState(() => _signVendorAsSender = v ?? false),
          ),
          const Text('거래처와 발송업체가 동일할 경우'),
          // 체크되면 담당자명 = 발송담당자 자동 → 입력란 숨김
          if (!_signVendorAsSender)
            SizedBox(
              width: 200,
              child: TextField(
                controller: _signVendorNameCtrl,
                decoration: const InputDecoration(
                  labelText: '거래처 담당자명',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 헬프데스크/IT기획팀 담당자 드롭다운 (users.receipt_team 기준)
  Widget _teamPicker(String team, int? value, ValueChanged<int?> onChanged) {
    final theme = Theme.of(context);
    final users = _teamUsers.where((u) => u.receiptTeam == team).toList();
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        children: [
          const Text('담당자: '),
          const SizedBox(width: 4),
          DropdownButton<int?>(
            value: value,
            hint: const Text('선택 안 함'),
            isDense: true,
            items: [
              const DropdownMenuItem<int?>(
                  value: null, child: Text('선택 안 함')),
              ...users.map((u) => DropdownMenuItem<int?>(
                    value: u.id,
                    child: Text('${u.employeeName} (${u.employeeId})'),
                  )),
            ],
            onChanged: onChanged,
          ),
          const SizedBox(width: 8),
          // 인수자와 동일 (헬프데스크/IT기획팀 중 하나만 체크 가능)
          Checkbox(
            visualDensity: VisualDensity.compact,
            value: _receiverSameAs == team,
            onChanged: (v) {
              if (v == true) {
                if (value == null) {
                  _snack('먼저 담당자를 선택하세요.');
                  return;
                }
                _setReceiverSameAs(team);
              } else {
                setState(() => _receiverSameAs = null);
              }
            },
          ),
          const Text('인수자와 동일'),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '설정 › 유저 정보에서 서명팀을 지정하세요',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
