import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../main.dart';
import '../../models/user.dart';
import '../../notifiers/auth_notifier.dart';
import '../../notifiers/menu_visibility_provider.dart';
import 'asset_uid_guide_dialog.dart';

/// 네비게이션 메뉴 항목 정의
class _NavItem {
  final String key;
  final String label;
  final IconData icon;
  final String path;

  const _NavItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.path,
  });
}

const _navItems = <_NavItem>[
  _NavItem(key: 'home', label: '홈', icon: Icons.home, path: '/'),
  _NavItem(key: 'scan', label: '스캔', icon: Icons.qr_code_scanner, path: '/scan'),
  _NavItem(key: 'assets', label: '자산목록', icon: Icons.list_alt, path: '/assets'),
  _NavItem(
      key: 'inspections',
      label: '실사목록',
      icon: Icons.fact_check,
      path: '/inspections'),
  _NavItem(key: 'drawings', label: '도면', icon: Icons.map, path: '/drawings'),
  _NavItem(
      key: 'receipts',
      label: '인수증',
      icon: Icons.receipt_long,
      path: '/receipts'),
];

/// 모든 화면에서 사용하는 공통 레이아웃 Scaffold.
///
/// 반응형:
/// - width < 600px  -> BottomNavigationBar
/// - width >= 600px -> NavigationRail
///
/// Drawer: 사용자 정보 헤더, 메뉴 항목, 다크모드 토글, 로그아웃
/// 앱바 오른쪽: ? 자산번호 부여 기준 (기본 내장) + 추가 actions
class AppScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final int? currentIndex;
  final List<Widget>? actions;
  final bool showPrimaryNav;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.currentIndex,
    this.actions,
    this.showPrimaryNav = true,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final authState = ref.watch(authNotifierProvider);
    final user = authState.valueOrNull?.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 600;

    // 메뉴권한 필터 (로딩/실패 시 기본 전부). 인수증은 운영자 그룹 게이트 병행.
    final visibleKeys =
        ref.watch(menuVisibilityProvider).valueOrNull ?? managedMenus.keys.toSet();
    final navItems = _navItems
        .where((i) =>
            visibleKeys.contains(i.key) &&
            (i.key != 'receipts' || (user?.isAdminGroup ?? false)))
        .toList();

    // 페이지가 넘긴 currentIndex(원본 기준) → 필터된 리스트 기준으로 재매핑
    final selIdx = (showPrimaryNav &&
            currentIndex != null &&
            currentIndex! >= 0 &&
            currentIndex! < _navItems.length)
        ? navItems.indexWhere((i) => i.path == _navItems[currentIndex!].path)
        : -1;
    final hasPrimarySelection = selIdx >= 0 && navItems.length >= 2;

    return Scaffold(
      floatingActionButton: floatingActionButton,
      appBar: AppBar(
        title: Text(title),
        actions: [
          // 추가 actions (각 페이지별)
          if (actions != null) ...actions!,
          // 공통: 자산번호 부여 기준
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '자산번호 부여 기준',
            onPressed: () => AssetUidGuideDialog.show(context),
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref, isDarkMode, user, visibleKeys),
      body: isNarrow || !showPrimaryNav || navItems.length < 2
          ? body
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: hasPrimarySelection ? selIdx : null,
                  onDestinationSelected: (index) =>
                      context.go(navItems[index].path),
                  labelType: NavigationRailLabelType.all,
                  destinations: navItems
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
      bottomNavigationBar: isNarrow && showPrimaryNav && hasPrimarySelection
          ? BottomNavigationBar(
              currentIndex: selIdx,
              onTap: (index) => context.go(navItems[index].path),
              type: BottomNavigationBarType.fixed,
              items: navItems
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

  Widget _buildDrawer(
    BuildContext context,
    WidgetRef ref,
    bool isDarkMode,
    User? user,
    Set<String> visibleKeys,
  ) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
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
          if (visibleKeys.contains('home'))
            _buildDrawerItem(context, Icons.home, '홈', '/'),
          if (visibleKeys.contains('assets'))
            _buildDrawerItem(context, Icons.list_alt, '자산목록', '/assets'),
          if (visibleKeys.contains('inspections'))
            _buildDrawerItem(
                context, Icons.fact_check, '실사목록', '/inspections'),
          if (visibleKeys.contains('drawings'))
            _buildDrawerItem(context, Icons.map, '도면관리', '/drawings'),
          if (visibleKeys.contains('receipts') &&
              user != null &&
              user.isAdminGroup)
            _buildDrawerItem(context, Icons.receipt_long, '인수증', '/receipts'),
          if (user != null && user.isAdminGroup) ...[
            const Divider(),
            _buildDrawerItem(
                context, Icons.storefront, '거래처', '/admin/vendors'),
            _buildDrawerItem(
                context, Icons.settings, '설정', '/admin/settings'),
          ],
          const Divider(),
          SwitchListTile(
            title: const Text('다크 모드'),
            secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: isDarkMode,
            onChanged: (value) {
              ref.read(isDarkModeProvider.notifier).state = value;
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('로그아웃'),
            onTap: () {
              Navigator.of(context).pop();
              ref.read(authNotifierProvider.notifier).logout();
              context.go('/login');
            },
          ),
        ],
      ),
    );
  }

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
        Navigator.of(context).pop();
        context.go(path);
      },
    );
  }
}
