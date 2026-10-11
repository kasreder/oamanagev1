import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'notifiers/auth_notifier.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/scan_page.dart';
import 'screens/asset_list_page.dart';
import 'screens/asset_detail_page.dart';
import 'screens/inspection_list_page.dart';
import 'screens/inspection_detail_page.dart';
import 'screens/signature_page.dart';
import 'screens/drawing_manager_page.dart';
import 'screens/drawing_viewer_page.dart';
import 'screens/receipt_list_page.dart';
import 'screens/receipt_detail_page.dart';
import 'screens/vendor_manager_page.dart';
import 'screens/change_password_page.dart';
import 'screens/admin_settings_page.dart';

/// GoRouter Provider (Riverpod)
/// GoRouter를 한 번만 생성하고, refreshListenable로 redirect만 재평가
final goRouterProvider = Provider<GoRouter>((ref) {
  // auth 상태 변경 시 GoRouter redirect를 재평가하기 위한 notifier
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authNotifierProvider, (_, __) {
    refreshNotifier.value++;
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refreshNotifier,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);

      if (authState.isLoading) return null;

      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      final isLoginPage = state.matchedLocation == '/login';

      // 미인증 상태에서 로그인 페이지가 아니면 → /login
      if (!isAuthenticated && !isLoginPage) {
        return '/login';
      }
      // 인증 상태에서 로그인 페이지면 → /
      if (isAuthenticated && isLoginPage) {
        return '/';
      }

      final user = authState.valueOrNull?.user;
      final loc = state.matchedLocation;

      // 관리자가 비번을 설정한 계정 → 강제 비번 변경 페이지로
      if (isAuthenticated &&
          (user?.mustChangePassword ?? false) &&
          loc != '/change-password') {
        return '/change-password';
      }

      // 인수증/거래처는 admin group(admin, operator1, operator2)만
      final adminGroupOnly =
          loc.startsWith('/receipt') || loc == '/admin/vendors';
      if (isAuthenticated && adminGroupOnly && !(user?.isAdminGroup ?? false)) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/scan',
        builder: (context, state) => const ScanPage(),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) {
          final col = state.uri.queryParameters['col'];
          final val = state.uri.queryParameters['val'];
          return AssetListPage(
            initialSearchColumnKey: col,
            initialSearchValue: val,
          );
        },
      ),
      GoRoute(
        path: '/asset/new',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final initialAssetUid = extra?['initialAssetUid'] as String?;
          return AssetDetailPage(
            isCreateMode: true,
            initialAssetUid: initialAssetUid,
          );
        },
      ),
      GoRoute(
        path: '/asset/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return AssetDetailPage(assetId: id);
        },
      ),
      GoRoute(
        path: '/inspections',
        builder: (context, state) => const InspectionListPage(),
      ),
      GoRoute(
        path: '/inspection/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return InspectionDetailPage(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/signature',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final inspectionId = extra?['inspectionId'] as int?;
          return SignaturePage(inspectionId: inspectionId);
        },
      ),
      GoRoute(
        path: '/drawings',
        builder: (context, state) => const DrawingManagerPage(),
      ),
      GoRoute(
        path: '/drawing/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return DrawingViewerPage(drawingId: id);
        },
      ),
      GoRoute(
        path: '/receipts',
        builder: (context, state) => const ReceiptListPage(),
      ),
      GoRoute(
        path: '/receipt/new',
        builder: (context, state) => const ReceiptDetailPage(),
      ),
      GoRoute(
        path: '/receipt/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ReceiptDetailPage(receiptId: id);
        },
      ),
      GoRoute(
        path: '/admin/vendors',
        builder: (context, state) => const VendorManagerPage(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: '/admin/settings',
        builder: (context, state) => const AdminSettingsPage(),
      ),
    ],
  );
});
