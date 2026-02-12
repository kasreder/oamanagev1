import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_router.dart';
import 'theme.dart';

/// 다크 모드 상태 Provider (기본값: ON)
final isDarkModeProvider = StateProvider<bool>((ref) => true);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    ),
    anonKey: const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: '',
    ),
  );

  runApp(const ProviderScope(child: OAManagerApp()));
}

final supabase = Supabase.instance.client;

class OAManagerApp extends ConsumerWidget {
  const OAManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'OA Manager',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
