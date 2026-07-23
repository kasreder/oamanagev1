import 'package:flutter/material.dart';

/// 자산 카테고리(constants.dart `assetCategories`) → IconData 매핑.
/// 미매칭 카테고리는 `Icons.devices_other`로 fallback.
const Map<String, IconData> assetCategoryIcons = {
  '데스크탑': Icons.desktop_windows,
  '모니터': Icons.monitor,
  '노트북': Icons.laptop,
  'IP전화기': Icons.phone_in_talk,
  '스캐너': Icons.scanner,
  '프린터': Icons.print,
  '태블릿': Icons.tablet_mac,
  '테스트폰': Icons.smartphone,
  '네트워크장비': Icons.router,
  '서버': Icons.dns,
  '웨어러블': Icons.watch,
  '특수목적장비': Icons.precision_manufacturing,
  '현장업무 태블릿': Icons.tablet_android,
  '법인폰': Icons.phone_iphone,
};

IconData iconForCategory(String? category) =>
    assetCategoryIcons[category ?? ''] ?? Icons.devices_other;
