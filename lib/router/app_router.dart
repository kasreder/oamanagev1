import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../view/asset_verification/list_page.dart';
import '../view/home/home_page.dart';
import '../view/assets/detail_page.dart';
import '../view/assets/list_page.dart';
import '../view/assets/registration_page.dart';
import '../view/scan/scan_page.dart';
import '../providers/inspection_provider.dart';

class AppRouter {
  AppRouter(this._inspectionProvider);

  final InspectionProvider _inspectionProvider;

  late final GoRouter router = GoRouter(
    initialLocation: '/',
    refreshListenable: _inspectionProvider,
    routes: [
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
        builder: (context, state) => const AssetsListPage(),
      ),
      GoRoute(
        path: '/assets/register',
        builder: (context, state) => const AssetRegistrationPage(),
      ),
      GoRoute(
        path: '/assets/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return AssetsDetailPage(inspectionId: id);
        },
      ),
      GoRoute(
        path: '/asset_verification_list',
        builder: (context, state) => const AssetVerificationListPage(),
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(title: const Text('페이지를 찾을 수 없습니다.')),
        body: Center(child: Text(state.error?.toString() ?? '알 수 없는 경로입니다.')),
      );
    },
  );
}
