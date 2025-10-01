import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'scanned_footer.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.selectedIndex,
    this.showFooter = true,
  });

  final String title;
  final Widget body;
  final int selectedIndex;
  final bool showFooter;

  static const _destinations = <_NavigationDestination>[
    _NavigationDestination(
      label: '홈',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: '/',
    ),
    _NavigationDestination(
      label: '자산리스트',
      icon: Icons.list_alt,
      selectedIcon: Icons.fact_check,
      route: '/assets',
    ),
    _NavigationDestination(
      label: '미검증 자산',
      icon: Icons.inventory_outlined,
      selectedIcon: Icons.inventory,
      route: '/asset_verification_list',
    ),
    _NavigationDestination(
      label: '자산등록',
      icon: Icons.add_box_outlined,
      selectedIcon: Icons.add_box,
      route: '/assets/register',
    ),
  ];

  void _goTo(BuildContext context, int index) {
    final router = GoRouter.of(context);
    final route = _destinations[index].route;
    router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 450;

    final drawer = Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const DrawerHeader(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('OA 관리', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('메뉴를 선택하세요'),
                ],
              ),
            ),
            for (var i = 0; i < _destinations.length; i++)
              ListTile(
                leading: Icon(_destinations[i].icon),
                title: Text(_destinations[i].label),
                selected: selectedIndex == i,
                onTap: () {
                  Navigator.of(context).pop();
                  _goTo(context, i);
                },
              ),
          ],
        ),
      ),
    );

    final appBar = AppBar(
      title: Text(title),
      actions: [
        IconButton(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('설정은 추후 제공됩니다.')),
            );
          },
          icon: const Icon(Icons.settings),
        ),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        drawer: drawer,
        body: Row(
          children: [
            NavigationRail(
              destinations: [
                for (final dest in _destinations)
                  NavigationRailDestination(
                    icon: Icon(dest.icon),
                    selectedIcon: Icon(dest.selectedIcon),
                    label: Text(dest.label),
                  ),
              ],
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _goTo(context, index),
              labelType: NavigationRailLabelType.all,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: body),
                  if (showFooter) const ScannedFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: drawer,
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showFooter) const ScannedFooter(),
          NavigationBar(
            height: 58,
            selectedIndex: selectedIndex,
            destinations: [
              for (final dest in _destinations)
                NavigationDestination(
                  icon: Icon(dest.icon),
                  selectedIcon: Icon(dest.selectedIcon),
                  label: dest.label,
                ),
            ],
            onDestinationSelected: (index) => _goTo(context, index),
            // labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, // 텍스트 숨김
          ),
          // if (showFooter) const ScannedFooter(),
        ],
      ),
    );
  }
}

class _NavigationDestination {
  const _NavigationDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
