import 'dart:async';
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
  static DateTime? _hostUnreachableUntil;

  static bool get isHostReachable =>
      _hostUnreachableUntil == null || DateTime.now().isAfter(_hostUnreachableUntil!);

  static void markHostUnreachable() {
    _hostUnreachableUntil = DateTime.now().add(const Duration(seconds: 15));
  }

  static void resetCircuitBreaker() {
    _hostUnreachableUntil = null;
  }

  static void clearCache() {
    _cache.clear();
  }

  static void invalidatePath(String pathPrefix) {
    _cache.removeWhere((key, _) => key.contains(pathPrefix));
  }

  void updateBaseUrl(String newUrl) {
    dio.options.baseUrl = newUrl;
    resetCircuitBreaker();
    clearCache();
  }

  DioClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Caching & Ultra-Fast Offline Circuit Breaker Interceptor
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Invalidate cache immediately on mutations and reset breaker
          if (options.method != 'GET') {
            _cache.clear();
            resetCircuitBreaker();
            return handler.next(options);
          }

          final cacheKey = options.uri.toString();
          final cached = _cache[cacheKey];

          // Circuit breaker: if host recently failed on this physical device, resolve in 0ms
          if (!isHostReachable) {
            if (cached != null) {
              return handler.resolve(
                Response(
                  requestOptions: options,
                  data: cached.data,
                  statusCode: cached.statusCode,
                  headers: cached.headers,
                ),
              );
            }
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: 'Fast offline fallback (host unreachable circuit breaker active)',
              ),
            );
          }

          // Clinical endpoints (visits, queues, stats, orders, bills, prescriptions)
          // must fetch fresh when online to prevent sync delays, unless cached recently (<3s)
          final path = options.path;
          final isLiveClinicalData = path.contains('/visits') ||
              path.contains('/queue') ||
              path.contains('/stats') ||
              path.contains('/orders') ||
              path.contains('/bills') ||
              path.contains('/prescriptions') ||
              path.contains('/patients') ||
              path.contains('/patient-portal') ||
              path.contains('/doctors');

          if (isLiveClinicalData || options.headers['Cache-Control'] == 'no-cache') {
            // Bypass memory cache and query live server database
            return handler.next(options);
          }

          // Check if cached entry is fresh for static resources (e.g. static catalogues)
          if (cached != null && !cached.isExpired) {
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
            resetCircuitBreaker();
            final path = response.requestOptions.path;
            // Short TTL for clinical data, longer TTL for static catalogues
            Duration ttl = const Duration(seconds: 10);
            if (path.contains('/catalogue') || path.contains('/departments')) {
              ttl = const Duration(minutes: 5);
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
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.connectionError;

          if (isNetworkIssue) {
            markHostUnreachable();
            if (error.requestOptions.method == 'GET') {
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
            final refreshed = await attemptTokenRefresh();
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

  static Completer<bool>? _refreshCompleter;

  Future<bool> attemptTokenRefresh() async {
    // If a refresh is already in flight, wait for its completion rather than initiating a concurrent request
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      debugPrint('⚡ [DIO REFRESH] Concurrent 401 detected; awaiting existing refresh operation...');
      return await _refreshCompleter!.future;
    }

    final completer = Completer<bool>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await SecureStorageService.getRefreshToken();
      if (refreshToken == null) {
        completer.complete(false);
        return false;
      }

      final refreshDio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
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
        debugPrint('⚡ [DIO REFRESH] Access & refresh tokens rotated successfully.');
        completer.complete(true);
        return true;
      } else {
        completer.complete(false);
        return false;
      }
    } catch (e) {
      debugPrint('⚡ [DIO REFRESH ERROR] Failed to refresh token: $e');
      completer.complete(false);
      return false;
    } finally {
      // Clear completer reference after a short delay so subsequent 401s in future minutes start fresh
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_refreshCompleter == completer) {
          _refreshCompleter = null;
        }
      });
    }
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    String? role,
  }) async {
    clearCache();
    await SecureStorageService.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
    );
  }

  static Future<void> clearTokens() async {
    clearCache();
    await SecureStorageService.clearTokens();
  }

  static Future<String?> getAccessToken() async {
    return await SecureStorageService.getAccessToken();
  }

  static Future<String?> getRefreshToken() async {
    return await SecureStorageService.getRefreshToken();
  }
}
