import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/responsive.dart';
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

  // Initialize Supabase client asynchronously in background (non-blocking for instant app boot)
  try {
    if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
      Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
      ).catchError((e) {
        debugPrint('Supabase initialisation note: $e');
        return Supabase.instance;
      });
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
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: Responsive.clampedTextScaler(context),
          ),
          child: child ?? const SizedBox(),
        );
      },
    );
  }
}
