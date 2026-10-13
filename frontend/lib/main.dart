import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved custom server URL if configured
  try {
    final savedUrl = await SecureStorageService.getServerUrl();
    if (savedUrl != null && savedUrl.trim().isNotEmpty) {
      AppConfig.customServerUrl = savedUrl.trim();
    }
  } catch (e) {
    debugPrint('Server URL restore note: $e');
  }

  // Initialize Supabase client
  try {
    if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      );
    }
  } catch (e) {
    debugPrint('Supabase initialisation note: $e');
  }

  runApp(
    const ProviderScope(
      child: OpdConnectApp(),
    ),
  );
}

class OpdConnectApp extends ConsumerWidget {
  const OpdConnectApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
