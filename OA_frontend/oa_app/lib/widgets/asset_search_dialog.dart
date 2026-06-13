import 'package:flutter/material.dart';

import '../models/search_condition.dart';

/// 자산 목록 고급 검색 다이얼로그.
/// 컬럼 + 값 + AND/OR 누적, chip으로 확인, [검색 적용]으로 결과 반환.
class AssetSearchDialog extends StatefulWidget {
  final List<SearchCondition> initial;
  const AssetSearchDialog({super.key, this.initial = const []});

  static Future<List<SearchCondition>?> show(
    BuildContext context, {
    List<SearchCondition> initial = const [],
  }) {
    return showDialog<List<SearchCondition>>(
      context: context,
      builder: (_) => AssetSearchDialog(initial: initial),
    );
  }

  @override
  State<AssetSearchDialog> createState() => _AssetSearchDialogState();
}

class _AssetSearchDialogState extends State<AssetSearchDialog> {
  late List<SearchCondition> _conditions;
  final _valueCtrl = TextEditingController();
  SearchableColumn _selectedColumn = kSearchableColumns.first;
  Joiner _nextJoiner = Joiner.and;

  @override
  void initState() {
    super.initState();
    _conditions = List.of(widget.initial);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  void _addCondition() {
    final v = _valueCtrl.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _conditions.add(SearchCondition(
        column: _selectedColumn,
        op: _selectedColumn.defaultOp,
        value: v,
        joiner: _conditions.isEmpty ? Joiner.and : _nextJoiner,
      ));
      _valueCtrl.clear();
    });
  }

  void _toggleJoiner(int index) {
    setState(() {
      final c = _conditions[index];
      _conditions[index] = c.copyWith(
        joiner: c.joiner == Joiner.and ? Joiner.or : Joiner.and,
      );
    });
  }

  void _removeAt(int index) {
    setState(() => _conditions.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context).size;
    final dialogWidth = media.width > 720 ? 640.0 : media.width * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: media.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Icon(Icons.tune, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '고급 검색',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 조건 추가 영역
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      // 컬럼 선택
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<SearchableColumn>(
                          initialValue: _selectedColumn,
                          isDense: true,
                          decoration: const InputDecoration(
                            labelText: '컬럼',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          items: kSearchableColumns
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.label),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedColumn = v);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 연산자 표시 (자동)
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _selectedColumn.defaultOp == SearchOp.eq ? '=' : '포함',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 값 입력
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _valueCtrl,
                          decoration: const InputDecoration(
                            labelText: '값',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 14),
                          ),
                          onSubmitted: (_) => _addCondition(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (_conditions.isNotEmpty) ...[
                        const Text('결합:',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 8),
                        SegmentedButton<Joiner>(
                          segments: const [
                            ButtonSegment(value: Joiner.and, label: Text('AND')),
                            ButtonSegment(value: Joiner.or, label: Text('OR')),
                          ],
                          selected: {_nextJoiner},
                          onSelectionChanged: (s) {
                            setState(() => _nextJoiner = s.first);
                          },
                        ),
                      ] else
                        Text(
                          '첫 번째 조건을 추가하세요',
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _addCondition,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('추가'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 누적 조건 영역
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: _conditions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off,
                                  size: 32,
                                  color:
                                      theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 8),
                              Text(
                                '추가된 조건이 없습니다',
                                style: TextStyle(
                                  color:
                                      theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < _conditions.length; i++)
                              _ConditionRow(
                                condition: _conditions[i],
                                isFirst: i == 0,
                                onToggleJoiner: () => _toggleJoiner(i),
                                onRemove: () => _removeAt(i),
                              ),
                          ],
                        ),
                      ),
              ),
            ),

            const Divider(height: 1),

            // 액션
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _conditions.isEmpty
                        ? null
                        : () => setState(() => _conditions.clear()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('모두 초기화'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _conditions),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('검색 적용'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 누적된 조건 1줄 — [AND/OR] [컬럼 like "값"] [×]
class _ConditionRow extends StatelessWidget {
  final SearchCondition condition;
  final bool isFirst;
  final VoidCallback onToggleJoiner;
  final VoidCallback onRemove;

  const _ConditionRow({
    required this.condition,
    required this.isFirst,
    required this.onToggleJoiner,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final opLabel = condition.op == SearchOp.eq ? '=' : '포함';
    final isOr = condition.joiner == Joiner.or;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // AND/OR 토글 (첫 조건은 자리만 유지)
          SizedBox(
            width: 56,
            child: isFirst
                ? Center(
                    child: Text(
                      'WHERE',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: onToggleJoiner,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isOr
                            ? Colors.deepOrange.withValues(alpha: 0.2)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          isOr ? 'OR' : 'AND',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isOr
                                ? Colors.deepOrange
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          // 조건 본문
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Text(
                    condition.column.label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      opLabel,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '"${condition.value}"',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
