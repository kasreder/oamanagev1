import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, inspectionProvider, _) {
        final recent = inspectionProvider.recent(limit: 5);
        return AppScaffold(
          title: '홈',
          selectedIndex: 0,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _HomeCard(
                    title: '스캔 시작',
                    subtitle: 'QR 스캔을 통해 자산 실사를 추가합니다.',
                    icon: Icons.qr_code,
                    onTap: () => context.go('/scan'),
                  ),
                  _HomeCard(
                    title: '최근 실사 (${inspectionProvider.totalCount})',
                    subtitle: '최근 등록된 실사 내역을 확인하세요.',
                    icon: Icons.history,
                    onTap: () => context.go('/inspections'),
                  ),
                  _HomeCard(
                    title: '미동기화 (${inspectionProvider.unsyncedCount})',
                    subtitle: '업로드 대기 중인 실사를 확인하세요.',
                    icon: Icons.cloud_upload_outlined,
                    onTap: () => context.go('/inspections'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('최근 실사', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('최근 실사 기록이 없습니다.'),
                  ),
                )
              else
                ...recent.map(
                  (inspection) {
                    final asset = inspectionProvider.assetOf(inspection.assetUid);
                    return Card(
                      child: ListTile(
                        title: Text(inspection.assetUid),
                        subtitle: Text(
                          '${inspection.status} • ${inspectionProvider.formatDateTime(inspection.scannedAt)}',
                        ),
                        trailing: asset != null ? Text(asset.model) : null,
                        onTap: () => context.go('/inspection/${inspection.id}'),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 40, color: colorScheme.primary),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
