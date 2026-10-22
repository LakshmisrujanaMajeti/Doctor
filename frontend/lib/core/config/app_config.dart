import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'SMVMCH OPD Connect';
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

  static const String supabaseServiceRoleKey = String.fromEnvironment(
    'SUPABASE_SERVICE_ROLE_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4d2lkcWF0c3h6c3J1bGF4eGFsIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTc3ODA4OCwiZXhwIjoyMTA3MzU0MDg4fQ.eayg90ZSOAT91ZA8c-mt28kRf3NkZOCvJDtTpRLHy8c',
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

    if (kIsWeb) {
      try {
        final host = Uri.base.host;
        if (host.isNotEmpty && host != 'localhost' && host != '127.0.0.1') {
          final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
          return '$scheme://$host:8000/api/v1';
        }
      } catch (_) {}
      return 'http://localhost:8000/api/v1';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.29.193:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  /// Fast fail-safe timeouts: prevents screen freezing on physical mobile devices
  /// when default emulator loopback (10.0.2.2) or unreachable Wi-Fi endpoints are queried.
  static const Duration connectTimeout = Duration(milliseconds: 1500);
  static const Duration receiveTimeout = Duration(milliseconds: 3000);
  static const Duration sendTimeout = Duration(milliseconds: 2000);
}
