import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/inspection_repository.dart';
import 'data/reference_repository.dart';
import 'providers/inspection_provider.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final inspectionRepository = InspectionRepository();
  final referenceRepository = ReferenceDataRepository();
  final inspectionProvider = InspectionProvider(inspectionRepository, referenceRepository);
  await inspectionProvider.initialize();
  final router = AppRouter(inspectionProvider).router;

  runApp(MyApp(inspectionProvider: inspectionProvider, router: router));
}

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
