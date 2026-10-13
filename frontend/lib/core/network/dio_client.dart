import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_endpoints.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

class _CacheEntry {
  final dynamic data;
  final int statusCode;
  final Headers headers;
  final DateTime timestamp;
  final Duration ttl;

  _CacheEntry({
    required this.data,
    required this.statusCode,
    required this.headers,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired => DateTime.now().isAfter(timestamp.add(ttl));
  bool get isGraceExpired => DateTime.now().isAfter(timestamp.add(const Duration(hours: 1)));
}

class DioClient {
  late final Dio dio;
  static final Map<String, _CacheEntry> _cache = {};

  static void clearCache() {
    _cache.clear();
  }

  static void invalidatePath(String pathPrefix) {
    _cache.removeWhere((key, _) => key.contains(pathPrefix));
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
    clearCache();
  }

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Caching & Offline Resilience Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Invalidate cache on mutations
          if (options.method != 'GET') {
            _cache.clear();
            return handler.next(options);
          }

          // Check if cached entry is fresh
          final cacheKey = options.uri.toString();
          final cached = _cache[cacheKey];
          if (cached != null && !cached.isExpired && options.headers['Cache-Control'] != 'no-cache') {
            return handler.resolve(
              Response(
                requestOptions: options,
                data: cached.data,
                statusCode: cached.statusCode,
                headers: cached.headers,
              ),
            );
          }

          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (response.requestOptions.method == 'GET' && response.statusCode == 200) {
            final path = response.requestOptions.path;
            // Longer TTL for static catalogues and lists, shorter TTL for fast-moving queues
            Duration ttl = const Duration(seconds: 45);
            if (path.contains('/catalogue') || path.contains('/departments') || path.contains('/medicines')) {
              ttl = const Duration(minutes: 5);
            } else if (path.contains('/profile') || path.contains('/stats')) {
              ttl = const Duration(seconds: 30);
            }

            final cacheKey = response.requestOptions.uri.toString();
            _cache[cacheKey] = _CacheEntry(
              data: response.data,
              statusCode: response.statusCode ?? 200,
              headers: response.headers,
              timestamp: DateTime.now(),
              ttl: ttl,
            );
          }
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Offline fallback: if network failure or timeout occurs on a GET request, serve cached copy if available
          final isNetworkIssue = error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError;

          if (isNetworkIssue && error.requestOptions.method == 'GET') {
            final cacheKey = error.requestOptions.uri.toString();
            final cached = _cache[cacheKey];
            if (cached != null && !cached.isGraceExpired) {
              debugPrint('⚡ [DIO CACHE] Serving offline cached data for: $cacheKey');
              return handler.resolve(
                Response(
                  requestOptions: error.requestOptions,
                  data: cached.data,
                  statusCode: cached.statusCode,
                  headers: cached.headers,
                ),
              );
            }
          }

          return handler.next(error);
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Attempt automatic token refresh on 401 Unauthorized for non-auth requests
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/')) {
            final refreshed = await _attemptTokenRefresh();
            if (refreshed) {
              final newToken = await SecureStorageService.getAccessToken();
              final opts = error.requestOptions;
              opts.headers['Authorization'] = 'Bearer $newToken';

              try {
                final response = await dio.fetch(opts);
                return handler.resolve(response);
              } catch (e) {
                return handler.next(error);
              }
            }
          }
          return handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          logPrint: (obj) => debugPrint('🌐 [DIO] $obj'),
        ),
      );
    }
  }

  Future<bool> _attemptTokenRefresh() async {
    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) return false;

      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
      final res = await refreshDio.post(
        ApiEndpoints.refresh,
        data: {'refresh_token': refreshToken},
      );

      if (res.statusCode == 200 && res.data['status'] == 'success') {
        final data = res.data['data'];
        final newAccess = data['access_token'] as String;
        final newRefresh = data['refresh_token'] as String;

        await SecureStorageService.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
  }) async {
    await SecureStorageService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
    );
  }

  static Future<void> clearTokens() async {
    await SecureStorageService.clearTokens();
  }

  static Future<String?> getAccessToken() async {
    return await SecureStorageService.getAccessToken();
  }

  static Future<String?> getRefreshToken() async {
    return await SecureStorageService.getRefreshToken();
  }
}
