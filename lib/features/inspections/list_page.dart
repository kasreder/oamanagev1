import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class InspectionListPage extends StatelessWidget {
  const InspectionListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final items = provider.items;
        return AppScaffold(
          title: '실사 목록',
          selectedIndex: 1,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(value: false, label: Text('전체')),
                        ButtonSegment<bool>(value: true, label: Text('미동기화')),
                      ],
                      selected: <bool>{provider.onlyUnsynced},
                      onSelectionChanged: (value) {
                        provider.setOnlyUnsynced(value.first);
                      },
                    ),
                    const Spacer(),
                    Text('${items.length}건'),
                  ],
                ),
              ),
              // TODO: 검색(assetUid, memo) 기능 추가
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('표시할 실사 내역이 없습니다.'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final inspection = items[index];
                          final asset = provider.assetOf(inspection.assetUid);
                          final subtitleParts = [
                            inspection.status,
                            if ((inspection.memo ?? '').isNotEmpty) inspection.memo!,
                            provider.formatDateTime(inspection.scannedAt),
                          ];
                          return Dismissible(
                            key: ValueKey(inspection.id),
                            direction: DismissDirection.endToStart,
                            confirmDismiss: (direction) async {
                              return await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('삭제 확인'),
                                      content: const Text('선택한 실사를 삭제할까요?'),
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
                            },
                            onDismissed: (_) {
                              provider.remove(inspection.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${inspection.assetUid} 삭제됨')),
                              );
                            },
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              color: Colors.redAccent,
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            child: ListTile(
                              title: Text(inspection.assetUid),
                              subtitle: Text(subtitleParts.join(' • ')),
                              trailing: asset != null ? Text(asset.name) : null,
                              onTap: () => context.go('/inspection/${inspection.id}'),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
