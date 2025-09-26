import 'package:flutter/material.dart';

import '../common/app_scaffold.dart';

class AssetVerificationDetailPage extends StatelessWidget {
  const AssetVerificationDetailPage({super.key, required this.assetUid});

  final String assetUid;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '자산 검증',
      selectedIndex: 2,
      body: Center(
        child: Text('자산 $assetUid 검증 상세는 추후 제공 예정입니다.'),
      ),
    );
  }
}
