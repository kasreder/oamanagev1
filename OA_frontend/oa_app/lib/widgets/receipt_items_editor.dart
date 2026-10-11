import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/receipt.dart';
import '../utils/label_ocr.dart';

/// 인수증 항목 편집기 — 카테고리 / 제품명 / SN / 수량 / 비고
/// - 행 추가/삭제
/// - 사진 촬영 → OCR로 SN/제품명 자동 채움
class ReceiptItemsEditor extends StatefulWidget {
  final List<ReceiptItem> items;
  final ValueChanged<List<ReceiptItem>> onChanged;

  /// 항목(카테고리) 드롭다운 옵션 — 설정›세부선택›자산종류
  final List<String> categoryOptions;

  const ReceiptItemsEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.categoryOptions = const [],
  });

  @override
  State<ReceiptItemsEditor> createState() => _State();
}

/// 행별 지속 컨트롤러 — build마다 새로 만들면 타이핑 중 커서가 앞으로 튄다.
class _RowCtrls {
  final name = TextEditingController();
  final sn = TextEditingController();
  final note = TextEditingController();
  final qty = TextEditingController();
  final amount = TextEditingController();

  void setFrom(ReceiptItem it) {
    name.text = it.name ?? '';
    sn.text = it.sn ?? '';
    note.text = it.note ?? '';
    qty.text = '${it.qty}';
    amount.text = it.amount?.toString() ?? '';
  }

  void dispose() {
    name.dispose();
    sn.dispose();
    note.dispose();
    qty.dispose();
    amount.dispose();
  }
}

class _State extends State<ReceiptItemsEditor> {
  final List<_RowCtrls> _ctrls = [];
  // 행별 펼침 상태 — 초기: 품목 3개 이하면 모두 펼침, 초과면 모두 접힘
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    for (final it in widget.items) {
      _ctrls.add(_RowCtrls()..setFrom(it));
    }
    if (widget.items.length <= 3) {
      _expanded.addAll(List.generate(widget.items.length, (i) => i));
    }
  }

  @override
  void didUpdateWidget(covariant ReceiptItemsEditor old) {
    super.didUpdateWidget(old);
    // 외부에서 행 수가 바뀐 경우만 뒤에서 맞춤 (내부 추가/삭제는 직접 처리됨)
    while (_ctrls.length < widget.items.length) {
      _ctrls.add(_RowCtrls()..setFrom(widget.items[_ctrls.length]));
    }
    while (_ctrls.length > widget.items.length) {
      _ctrls.removeLast().dispose();
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _update(int i, ReceiptItem Function(ReceiptItem) f) {
    final next = List.of(widget.items);
    next[i] = f(next[i]);
    widget.onChanged(next);
  }

  void _addRow() {
    _ctrls.add(_RowCtrls());
    _expanded.add(widget.items.length); // 새 행은 펼친 상태로
    final next = List.of(widget.items)..add(const ReceiptItem());
    widget.onChanged(next);
  }

  void _removeRow(int i) {
    if (widget.items.length == 1) {
      _ctrls[0].setFrom(const ReceiptItem());
      _expanded.add(0);
      widget.onChanged([const ReceiptItem()]);
      return;
    }
    _ctrls.removeAt(i).dispose();
    // 펼침 상태 인덱스 재매핑
    final remapped = <int>{
      for (final e in _expanded)
        if (e < i) e else if (e > i) e - 1,
    };
    _expanded
      ..clear()
      ..addAll(remapped);
    final next = List.of(widget.items)..removeAt(i);
    widget.onChanged(next);
  }

  /// 항목(카테고리) — 자산종류 드롭다운. 기존 값이 옵션에 없으면 임시로 포함.
  Widget _categoryField(int i) {
    final current = (widget.items[i].category ?? '').trim();
    final options = [
      ...widget.categoryOptions,
      if (current.isNotEmpty && !widget.categoryOptions.contains(current))
        current,
    ];
    return DropdownButtonFormField<String>(
      value: current.isEmpty ? null : current,
      isExpanded: true,
      decoration: const InputDecoration(
          labelText: '항목(자산종류)',
          border: OutlineInputBorder(),
          isDense: true),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('-')),
        ...options
            .map((c) => DropdownMenuItem<String>(value: c, child: Text(c))),
      ],
      onChanged: (v) => _update(i, (it) => it.copyWith(category: v ?? '')),
    );
  }

  Future<void> _openOcr(int i) async {
    final result = await showDialog<_OcrResult>(
      context: context,
      builder: (_) => const _OcrDialog(),
    );
    if (result == null) return;
    _update(
      i,
      (it) => it.copyWith(
        name: (result.name?.isNotEmpty ?? false) ? result.name : it.name,
        sn: (result.sn?.isNotEmpty ?? false) ? result.sn : it.sn,
      ),
    );
    // OCR 결과를 화면 컨트롤러에도 반영
    if (result.name?.isNotEmpty ?? false) _ctrls[i].name.text = result.name!;
    if (result.sn?.isNotEmpty ?? false) _ctrls[i].sn.text = result.sn!;
  }

  String _summaryOf(ReceiptItem it) {
    final parts = <String>[
      if ((it.category ?? '').trim().isNotEmpty) it.category!.trim(),
      if ((it.name ?? '').trim().isNotEmpty) it.name!.trim(),
    ];
    if (parts.isEmpty) return '(새 항목)';
    return '${parts.join(' · ')}  ×${it.qty}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < widget.items.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            // ExpansionTile은 내부 TextField 높이를 무한 팽창시키는 문제가
            // 있어 직접 만든 접기/펼치기 사용
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => setState(() {
                    if (!_expanded.remove(i)) _expanded.add(i);
                  }),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    child: Row(
                      children: [
                        Text('#${i + 1}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _summaryOf(widget.items[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: '사진 촬영 → OCR (SN / 제품명)',
                          icon: const Icon(Icons.camera_alt, size: 20),
                          onPressed: () => _openOcr(i),
                        ),
                        IconButton(
                          tooltip: '행 삭제',
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: theme.colorScheme.error),
                          onPressed: () => _removeRow(i),
                        ),
                        Icon(
                          _expanded.contains(i)
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_expanded.contains(i))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: _rowFields(i, isMobile),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _addRow,
          icon: const Icon(Icons.add),
          label: const Text('항목 추가'),
        ),
      ],
    );
  }

  Widget _rowFields(int i, bool isMobile) {
    final nameField = TextField(
      decoration: const InputDecoration(
          labelText: '제품명', border: OutlineInputBorder(), isDense: true),
      controller: _ctrls[i].name,
      onChanged: (v) => _update(i, (it) => it.copyWith(name: v)),
    );
    final snField = TextField(
      decoration: const InputDecoration(
          labelText: 'SN', border: OutlineInputBorder(), isDense: true),
      controller: _ctrls[i].sn,
      onChanged: (v) => _update(i, (it) => it.copyWith(sn: v)),
    );
    final qtyField = TextField(
      decoration: const InputDecoration(
          labelText: '수량', border: OutlineInputBorder(), isDense: true),
      keyboardType: TextInputType.number,
      controller: _ctrls[i].qty,
      onChanged: (v) =>
          _update(i, (it) => it.copyWith(qty: int.tryParse(v) ?? 1)),
    );
    final amountField = TextField(
      decoration: const InputDecoration(
          labelText: '금액(원)',
          hintText: '선택',
          border: OutlineInputBorder(),
          isDense: true),
      keyboardType: TextInputType.number,
      controller: _ctrls[i].amount,
      onChanged: (v) {
        final n = int.tryParse(v.trim());
        _update(i, (it) => it.copyWith(amount: n, clearAmount: n == null));
      },
    );
    final noteField = TextField(
      decoration: const InputDecoration(
          labelText: '비고', border: OutlineInputBorder(), isDense: true),
      controller: _ctrls[i].note,
      onChanged: (v) => _update(i, (it) => it.copyWith(note: v)),
    );

    if (isMobile) {
      // 모바일 — 자산종류 드롭다운 전체폭, 나머지는 Row+Expanded 고정 2열
      pw2(Widget a, Widget? b) => Row(children: [
            Expanded(child: a),
            const SizedBox(width: 8),
            Expanded(child: b ?? const SizedBox()),
          ]);
      return Column(children: [
        _categoryField(i),
        const SizedBox(height: 8),
        pw2(nameField, snField),
        const SizedBox(height: 8),
        pw2(qtyField, amountField),
        const SizedBox(height: 8),
        pw2(noteField, null),
      ]);
    }

    return Column(children: [
      Row(
        children: [
          Expanded(flex: 2, child: _categoryField(i)),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: nameField),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: snField),
          const SizedBox(width: 8),
          SizedBox(width: 70, child: qtyField),
          const SizedBox(width: 8),
          SizedBox(width: 110, child: amountField),
        ],
      ),
      const SizedBox(height: 8),
      noteField,
    ]);
  }
}

class _OcrResult {
  final String? name;
  final String? sn;
  const _OcrResult({this.name, this.sn});
}

class _OcrDialog extends StatefulWidget {
  const _OcrDialog();
  @override
  State<_OcrDialog> createState() => _OcrDialogState();
}

class _OcrDialogState extends State<_OcrDialog> {
  final _picker = ImagePicker();
  final _snCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _busy = false;
  String? _rawText;
  String? _error;

  // SN 후보: 대문자+숫자 6~24자, 최소 숫자 2 이상
  static final _snRegex = RegExp(r'\b[A-Z0-9]{6,24}\b');

  @override
  void dispose() {
    _snCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final x = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (x == null) {
        setState(() => _busy = false);
        return;
      }
      // 모바일: ML Kit, 웹: Tesseract.js 자동 분기 (label_ocr 통합)
      final lines = await LabelOcr.recognizeFromXFile(x);
      final text = lines.join('\n');
      // SN 자동 추출: 대문자·숫자 혼합 토큰 중 숫자 2개 이상 포함한 첫 매칭
      String? sn;
      for (final m in _snRegex.allMatches(text)) {
        final t = m.group(0)!;
        if (RegExp(r'[0-9].*[0-9]').hasMatch(t) &&
            RegExp(r'[A-Z]').hasMatch(t)) {
          sn = t;
          break;
        }
      }
      // 제품명 후보: 가장 긴 라인
      final nameLines = lines.where((l) => l.trim().length >= 3).toList()
        ..sort((a, b) => b.length.compareTo(a.length));
      final name = nameLines.isNotEmpty ? nameLines.first.trim() : null;

      setState(() {
        _rawText = text;
        _snCtrl.text = sn ?? '';
        _nameCtrl.text = name ?? '';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('사진 촬영 → OCR',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _busy ? null : _shoot,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label: const Text('촬영 & 인식'),
                style:
                    FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                SelectableText(_error!,
                    style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _snCtrl,
                decoration: const InputDecoration(
                    labelText: 'SN', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    labelText: '제품명', border: OutlineInputBorder()),
              ),
              if (_rawText != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _rawText!,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _OcrResult(
                          name: _nameCtrl.text.trim(),
                          sn: _snCtrl.text.trim()),
                    ),
                    child: const Text('적용'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
