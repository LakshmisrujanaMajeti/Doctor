import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'OPD Connect+';
  static const String appVersion = '1.0.0';

  // Supabase Configuration provided by project
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xxwidqatsxzsrulaxxal.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE3NzgwODgsImV4cCI6MjEwNzM1NDA4OH0.aPYCUJxHYwgYvTAjaiyYjD4G_s5dICLLjXLOYdkcXhE',
  );

  /// Mutable runtime server URL configured via server settings or storage
  static String? customServerUrl;

  /// Default API base URL for FastAPI backend
  /// Uses custom server URL if configured, 10.0.2.2 for Android emulators, 127.0.0.1 for desktop/iOS/web
  static String get apiBaseUrl {
    if (customServerUrl != null && customServerUrl!.trim().isNotEmpty) {
      return customServerUrl!.trim();
    }
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;

    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
