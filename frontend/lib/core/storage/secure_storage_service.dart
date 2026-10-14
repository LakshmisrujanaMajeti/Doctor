import 'dart:convert';
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

  // Fast in-memory cache to eliminate platform channel Keystore latency on every HTTP request
  static String? _memAccessToken;
  static String? _memRefreshToken;
  static String? _memUserRole;
  static Map<String, dynamic>? _memUserData;

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
  }) async {
    _memAccessToken = accessToken;
    _memRefreshToken = refreshToken;
    if (role != null) _memUserRole = role;

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
    if (_memAccessToken != null && _memAccessToken!.isNotEmpty) {
      return _memAccessToken;
    }
    try {
      _memAccessToken = await _secureStorage.read(key: keyAccessToken);
      return _memAccessToken;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _memAccessToken = prefs.getString(keyAccessToken);
      return _memAccessToken;
    }
  }

  static Future<String?> getRefreshToken() async {
    if (_memRefreshToken != null && _memRefreshToken!.isNotEmpty) {
      return _memRefreshToken;
    }
    try {
      _memRefreshToken = await _secureStorage.read(key: keyRefreshToken);
      return _memRefreshToken;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _memRefreshToken = prefs.getString(keyRefreshToken);
      return _memRefreshToken;
    }
  }

  static Future<String?> getUserRole() async {
    if (_memUserRole != null && _memUserRole!.isNotEmpty) {
      return _memUserRole;
    }
    try {
      _memUserRole = await _secureStorage.read(key: keyUserRole);
      return _memUserRole;
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      _memUserRole = prefs.getString(keyUserRole);
      return _memUserRole;
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

  static const String keyUserData = 'opd_user_data';
  static const String keyPatientsData = 'opd_patients_data';
  static const String keyVisitsData = 'opd_visits_data';

  static Future<void> saveUserData(Map<String, dynamic> data) async {
    _memUserData = Map<String, dynamic>.from(data);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyUserData, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    if (_memUserData != null) return _memUserData;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyUserData);
    if (raw == null || raw.isEmpty) return null;
    try {
      _memUserData = jsonDecode(raw) as Map<String, dynamic>;
      return _memUserData;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearUserData() async {
    _memUserData = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyUserData);
  }

  static Future<void> savePatientsJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyPatientsData, jsonStr);
  }

  static Future<String?> getPatientsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPatientsData);
  }

  static Future<void> saveVisitsJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyVisitsData, jsonStr);
  }

  static Future<String?> getVisitsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyVisitsData);
  }

  static const String keyStaffDirectoryData = 'opd_staff_directory_data';
  static const String keyBillsData = 'opd_bills_data';

  static Future<void> saveStaffDirectoryJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyStaffDirectoryData, jsonStr);
  }

  static Future<String?> getStaffDirectoryJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyStaffDirectoryData);
  }

  static Future<void> saveBillsJson(String jsonStr) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBillsData, jsonStr);
  }

  static Future<String?> getBillsJson() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyBillsData);
  }

  static Future<void> clearTokens() async {
    _memAccessToken = null;
    _memRefreshToken = null;
    _memUserRole = null;
    _memUserData = null;
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
    await clearUserData();
  }
}
