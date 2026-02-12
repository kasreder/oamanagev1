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
final goRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (BuildContext context, GoRouterState state) {
      final isAuthenticated = authState.valueOrNull?.isAuthenticated ?? false;
      final isLoginPage = state.matchedLocation == '/login';

      // 미인증 상태에서 로그인 페이지가 아니면 → /login 리다이렉트
      if (!isAuthenticated && !isLoginPage) {
        return '/login';
      }
      // 인증 상태에서 로그인 페이지면 → / 리다이렉트
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
