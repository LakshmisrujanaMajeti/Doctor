import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure token and session credentials storage.
/// Uses iOS Keychain and Android Keystore with an automatic memory/shared_prefs
/// fallback for headless testing environments.
class SecureStorageService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static const String keyAccessToken = 'opd_access_token';
  static const String keyRefreshToken = 'opd_refresh_token';
  static const String keyUserRole = 'opd_user_role';

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
  }) async {
    try {
      await _secureStorage.write(key: keyAccessToken, value: accessToken);
      await _secureStorage.write(key: keyRefreshToken, value: refreshToken);
      if (role != null) {
        await _secureStorage.write(key: keyUserRole, value: role);
      }
    } catch (_) {
      // Fallback for desktop or headless test platforms where keystore is unavailable
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyAccessToken, accessToken);
      await prefs.setString(keyRefreshToken, refreshToken);
      if (role != null) {
        await prefs.setString(keyUserRole, role);
      }
    }
  }

  static Future<String?> getAccessToken() async {
    try {
      return await _secureStorage.read(key: keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyAccessToken);
    }
  }

  static Future<String?> getRefreshToken() async {
    try {
      return await _secureStorage.read(key: keyRefreshToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyRefreshToken);
    }
  }

  static Future<String?> getUserRole() async {
    try {
      return await _secureStorage.read(key: keyUserRole);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(keyUserRole);
    }
  }

  static const String keyCustomServerUrl = 'opd_custom_server_url';

  static Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyCustomServerUrl, url);
  }

  static Future<String?> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyCustomServerUrl);
  }

  static Future<void> clearTokens() async {
    try {
      await _secureStorage.delete(key: keyAccessToken);
      await _secureStorage.delete(key: keyRefreshToken);
      await _secureStorage.delete(key: keyUserRole);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(keyAccessToken);
      await prefs.remove(keyRefreshToken);
      await prefs.remove(keyUserRole);
    }
  }
}
