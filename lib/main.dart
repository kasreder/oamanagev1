// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/api_client.dart';
import 'data/inspection_repository.dart';
import 'data/mock_data_loader.dart';
import 'providers/inspection_provider.dart';
import 'data/signature_storage.dart';
import 'router/app_router.dart';

/// 주요 기능:
/// - 앱 실행 전 실사 및 참조 더미 데이터를 초기화합니다.
/// - 전역 [InspectionProvider]를 주입하고 라우터를 구성합니다.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const backendBaseUrl = String.fromEnvironment(
    'OA_API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );
  final apiClient = ApiClient(baseUrl: backendBaseUrl);
  const mockDataLoader = MockDataLoader();
  final inspectionRepository = InspectionRepository(apiClient, mockDataLoader);
  final inspectionProvider = InspectionProvider(inspectionRepository, apiClient, mockDataLoader);

  await inspectionProvider.initialize();
  final router = AppRouter(inspectionProvider).router;

  runApp(MyApp(inspectionProvider: inspectionProvider, router: router));
}

/// Material 3 테마와 GoRouter를 사용하는 최상위 위젯.
class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.inspectionProvider, required this.router});

  final InspectionProvider inspectionProvider;
  final RouterConfig<Object> router;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: inspectionProvider,
      child: MaterialApp.router(
        title: 'OA Asset Manager',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        routerConfig: router,
      ),
    );
  }
}
