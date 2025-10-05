// lib/view/asset_verification/list_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/inspection_provider.dart';
import '../common/app_scaffold.dart';

class AssetVerificationListPage extends StatelessWidget {
  const AssetVerificationListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InspectionProvider>(
      builder: (context, provider, _) {
        final unsynced = provider.unsyncedItems;
        return AppScaffold(
          title: '미검증 자산',
          selectedIndex: 2,
          body: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: unsynced.isEmpty ? 1 : unsynced.length,
            itemBuilder: (context, index) {
              if (unsynced.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text('미검증 자산이 없습니다.'),
                  ),
                );
              }
              final inspection = unsynced[index];
              final asset = provider.assetOf(inspection.assetUid);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.qr_code),
                  title: Text(inspection.assetUid),
                  subtitle: Text('${inspection.status} • ${provider.formatDateTime(inspection.scannedAt)}'),
                  trailing: asset != null ? Text(asset.location) : null,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
