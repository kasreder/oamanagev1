import 'package:flutter/material.dart';

/// 자산번호 부여 기준 안내 다이얼로그
/// 모든 화면의 앱바에서 ? 아이콘으로 접근 가능
class AssetUidGuideDialog extends StatelessWidget {
  const AssetUidGuideDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AssetUidGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.help_outline, size: 22),
          SizedBox(width: 8),
          Expanded(child: Text('자산번호 부여 기준')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '두 형식 모두 등록 가능합니다.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _formatBox(theme,
                  '① 현재기준: 문자 1자리 + 숫자 5자리  또는  문자 2자리 + 숫자 4자리'),
              const SizedBox(height: 8),
              _guideTable(theme, const [
                ['D', '데스크탑', 'D00001'],
                ['N', '노트북', 'N00001'],
                ['T', '태블릿', 'T00001'],
                ['M', '모니터', 'M00001'],
                ['S', '스캐너', 'S00001'],
                ['P', '프린터', 'P00001'],
                ['C', 'IP전화기', 'C00001'],
                ['TP', '테스트폰', 'TP0001'],
                ['EH', '법인폰', 'EH0001'],
                ['ET', '현장업무 태블릿', 'ET0001'],
              ]),
              const SizedBox(height: 20),
              _formatBox(theme, '② 변경후: 등록경로 1자리 + 장비코드 2자리 + 숫자 5자리'),
              const SizedBox(height: 8),
              _guideTable(theme, const [
                ['B', '구매', 'BDT00001'],
                ['R', '임대', 'RNB00001'],
                ['C', '도급', 'CMN00001'],
                ['L', '대여', 'LTB00001'],
                ['S', '지원', 'STP00001'],
              ]),
              const SizedBox(height: 8),
              Text(
                '장비코드: DT 데스크탑 · NB 노트북 · MN 모니터 · PR 프린터 · '
                'TB 태블릿 · SC 스캐너 · IP IP전화기 · NW 네트워크장비 · '
                'SV 서버 · WR 무선라우터 · SD 스토리지 · TP 테스트폰 · '
                'ET 현장업무 태블릿 · EH 법인폰',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                '예시: D00123, TP0012, BDT00001, STP22222',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
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

  Widget _formatBox(ThemeData theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
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
