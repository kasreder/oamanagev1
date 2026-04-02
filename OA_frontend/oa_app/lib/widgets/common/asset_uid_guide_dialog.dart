import 'package:flutter/material.dart';

/// 자산번호 부여 기준 안내 다이얼로그 (2페이지: 현재기준 / 변경후)
/// 모든 화면의 앱바에서 ? 아이콘으로 접근 가능
class AssetUidGuideDialog extends StatefulWidget {
  const AssetUidGuideDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AssetUidGuideDialog(),
    );
  }

  @override
  State<AssetUidGuideDialog> createState() => _AssetUidGuideDialogState();
}

class _AssetUidGuideDialogState extends State<AssetUidGuideDialog> {
  int _pageIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.help_outline, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('자산번호 부여 기준')),
          ToggleButtons(
            isSelected: [_pageIndex == 0, _pageIndex == 1],
            onPressed: (index) => setState(() => _pageIndex = index),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 32, minWidth: 72),
            textStyle: theme.textTheme.labelSmall,
            children: const [
              Text('현재기준'),
              Text('변경후'),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: _pageIndex == 0
              ? _buildCurrentStandard(theme)
              : _buildNewStandard(theme),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  Widget _buildCurrentStandard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '형식: 문자1자리 + 숫자5자리  또는  문자2자리 + 숫자4자리',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Text('코드 목록',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _guideTable(theme, [
          ['D', '데스크탑', 'D00001'],
          ['N', '노트북', 'N00001'],
          ['T', '태블릿', 'T00001'],
          ['M', '모니터', 'M00001'],
          ['S', '스캐너', 'S00001'],
          ['P', '프린터', 'P00001'],
          ['C', 'IP전화기', 'C00001'],
          ['TP', 'Test폰', 'TP0001'],
          ['EH', '법인폰, 테스트폰', 'EH0001'],
          ['ET', '현장업무 태블릿', 'ET0001'],
        ]),
        const SizedBox(height: 12),
        Text(
          '예시: D00123, N00045, TP0012, EH0003',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildNewStandard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.tertiaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '형식: 등록경로(1자리) + 장비코드(2자리) + 일련번호(5자리)\n총 8자리  예) BDT00001',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 16),
        Text('등록경로 코드',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _guideTable(theme, [
          ['B', 'Buy (구매)', ''],
          ['R', 'Rental (렌탈)', ''],
          ['C', 'Contact (도급)', ''],
          ['L', 'Lease (리스)', ''],
          ['S', 'Spot (현장)', ''],
        ]),
        const SizedBox(height: 16),
        Text('장비코드',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _guideTable(theme, [
          ['DT', '데스크탑', 'BDT00001'],
          ['NB', '노트북', 'BNB00001'],
          ['MN', '모니터', 'BMN00001'],
          ['PR', '프린터', 'BPR00001'],
          ['TB', '태블릿', 'BTB00001'],
          ['SC', '스캐너', 'BSC00001'],
          ['IP', 'IP전화기', 'BIP00001'],
          ['NW', '네트워크장비', 'BNW00001'],
          ['SV', '서버', 'BSV00001'],
          ['WR', '웨어러블', 'BWR00001'],
          ['SD', '특수목적장비', 'BSD00001'],
          ['TP', '테스트폰', 'BTP00001'],
          ['ET', '현장업무 태블릿', 'BET00001'],
          ['EH', '법인폰', 'BEH00001'],
        ]),
      ],
    );
  }

  Widget _guideTable(ThemeData theme, List<List<String>> rows) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(50),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(90),
      },
      border: TableBorder.all(
        color: theme.dividerColor,
        borderRadius: BorderRadius.circular(6),
      ),
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          children: [
            _tableCell('코드', theme, isHeader: true),
            _tableCell('설명', theme, isHeader: true),
            _tableCell('예시', theme, isHeader: true),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _tableCell(row[0], theme, isBold: true),
              _tableCell(row[1], theme),
              _tableCell(row[2], theme, color: theme.colorScheme.primary),
            ],
          ),
      ],
    );
  }

  Widget _tableCell(String text, ThemeData theme,
      {bool isHeader = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: (isHeader || isBold) ? FontWeight.w600 : null,
          color: color,
        ),
      ),
    );
  }
}
