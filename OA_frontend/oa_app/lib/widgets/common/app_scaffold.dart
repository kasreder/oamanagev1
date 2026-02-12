import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../notifiers/auth_notifier.dart';

/// 네비게이션 메뉴 항목 정의
class _NavItem {
  final String label;
  final IconData icon;
  final String path;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.path,
  });
}

const _navItems = <_NavItem>[
  _NavItem(label: '홈', icon: Icons.home, path: '/'),
  _NavItem(label: '스캔', icon: Icons.qr_code_scanner, path: '/scan'),
  _NavItem(label: '자산목록', icon: Icons.list_alt, path: '/assets'),
  _NavItem(label: '실사목록', icon: Icons.fact_check, path: '/inspections'),
  _NavItem(label: '도면', icon: Icons.map, path: '/drawings'),
];

/// 모든 화면에서 사용하는 공통 레이아웃 Scaffold.
///
/// 반응형:
/// - width < 600px  -> BottomNavigationBar
/// - width >= 600px -> NavigationRail
///
/// Drawer: 사용자 정보 헤더, 메뉴 항목, 다크모드 토글, 로그아웃
class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final int currentIndex;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentIndex = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull?.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      drawer: _buildDrawer(context, ref, isDarkMode, user),
      body: isNarrow
          ? body
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (index) =>
                      _onNavItemTapped(context, index),
                  labelType: NavigationRailLabelType.all,
                  destinations: _navItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: body),
              ],
            ),
      bottomNavigationBar: isNarrow
          ? BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => _onNavItemTapped(context, index),
              type: BottomNavigationBarType.fixed,
              items: _navItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            )
          : null,
    );
  }

  /// 네비게이션 항목 탭 시 라우팅
  void _onNavItemTapped(BuildContext context, int index) {
    if (index >= 0 && index < _navItems.length) {
      context.go(_navItems[index].path);
    }
  }

  /// Drawer 구성
  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    bool isDarkMode,
    dynamic user,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // 사용자 정보 헤더
          UserAccountsDrawerHeader(
            accountName: Text(user?.employeeName ?? '사용자'),
            accountEmail: Text(user?.employeeId ?? ''),
            currentAccountPicture: CircleAvatar(
              child: Text(
                (user?.employeeName ?? '?').substring(0, 1),
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),

          // 메뉴 항목들
          _buildDrawerItem(context, Icons.home, '홈', '/'),
          _buildDrawerItem(context, Icons.list_alt, '자산목록', '/assets'),
          _buildDrawerItem(context, Icons.fact_check, '실사목록', '/inspections'),
          _buildDrawerItem(context, Icons.map, '도면관리', '/drawings'),
          _buildDrawerItem(
              context, Icons.warning_amber, '미검증자산', '/unverified'),

          const Divider(),

          // 다크모드 토글
          SwitchListTile(
            title: const Text('다크 모드'),
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: isDarkMode,
            onChanged: (value) {
              ref.read(isDarkModeProvider.notifier).state = value;
            },
          ),

          const Divider(),

          // 로그아웃
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              Navigator.of(context).pop(); // Drawer 닫기
              ref.read(authNotifierProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

  /// Drawer 메뉴 항목 빌더
  Widget _buildDrawerItem(
    BuildContext context,
    IconData icon,
    String label,
    String path,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop(); // Drawer 닫기
        context.go(path);
      },
    );
  }
}
