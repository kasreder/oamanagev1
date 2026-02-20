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
import 'screens/unverified_page.dart';

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

      // 인증이 필요한 페이지 (등록/수정/서명)
      const authRequiredPaths = [
        '/asset/new',
        '/signature',
      ];
      final location = state.matchedLocation;
      // 정확히 일치하거나, /asset/:id (수정 화면)인 경우
      final needsAuth = authRequiredPaths.contains(location) ||
          RegExp(r'^/asset/\d+$').hasMatch(location);

      // 미인증 상태에서 인증 필요 페이지 접근 시 → /login
      if (!isAuthenticated && needsAuth) {
        return '/login';
      }
      // 인증 상태에서 로그인 페이지면 → /
      if (isAuthenticated && isLoginPage) {
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
        builder: (context, state) => const AssetListPage(),
      ),
      GoRoute(
        path: '/asset/new',
        builder: (context, state) => const AssetDetailPage(isCreateMode: true),
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
        path: '/unverified',
        builder: (context, state) => const UnverifiedPage(),
      ),
    ],
  );
});
