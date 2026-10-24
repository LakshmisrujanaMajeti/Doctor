import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/notification_item_model.dart';

class NotificationRepository {
  final DioClient _dioClient;
  static final List<NotificationItemModel> _cachedNotifications = [];

  NotificationRepository(this._dioClient);

  static List<NotificationItemModel> get cachedList => List.unmodifiable(_cachedNotifications);

  Future<List<NotificationItemModel>> fetchNotifications({
    String? category,
    bool unreadOnly = false,
  }) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.notifications,
        queryParameters: {
          if (category != null && category.toLowerCase() != 'all') 'category': category,
          if (unreadOnly) 'unread_only': true,
        },
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );

      if (res.data is Map && res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        final items = list.map((m) => NotificationItemModel.fromJson(m as Map<String, dynamic>)).toList();
        _cachedNotifications.clear();
        _cachedNotifications.addAll(items);
        return items;
      }
    } catch (_) {}

    // Fallback: return cached list or filter locally
    var filtered = List<NotificationItemModel>.from(_cachedNotifications);
    if (category != null && category.toLowerCase() != 'all') {
      filtered = filtered.where((n) => n.category.toLowerCase() == category.toLowerCase()).toList();
    }
    if (unreadOnly) {
      filtered = filtered.where((n) => !n.isRead).toList();
    }
    return filtered;
  }

  Future<int> fetchUnreadCount() async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.notificationsUnreadCount,
        options: Options(headers: {'Cache-Control': 'no-cache'}),
      );
      if (res.data is Map && res.data['status'] == 'success') {
        return (res.data['data']?['unread_count'] as int?) ?? 0;
      }
    } catch (_) {}

    return _cachedNotifications.where((n) => !n.isRead).length;
  }

  Future<bool> markAsRead(String id) async {
    final idx = _cachedNotifications.indexWhere((n) => n.id == id);
    final previousState = idx != -1 ? _cachedNotifications[idx] : null;

    if (idx != -1) {
      _cachedNotifications[idx] = _cachedNotifications[idx].copyWith(isRead: true, readAt: DateTime.now());
    }

    try {
      final res = await _dioClient.dio.patch(
        ApiEndpoints.notificationMarkRead(id),
      );
      final isSuccess = res.data is Map && res.data['status'] == 'success';
      if (!isSuccess && idx != -1 && previousState != null) {
        _cachedNotifications[idx] = previousState;
      }
      return isSuccess;
    } catch (_) {
      if (idx != -1 && previousState != null) {
        _cachedNotifications[idx] = previousState;
      }
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    final previousList = List<NotificationItemModel>.from(_cachedNotifications);
    for (int i = 0; i < _cachedNotifications.length; i++) {
      _cachedNotifications[i] = _cachedNotifications[i].copyWith(isRead: true, readAt: DateTime.now());
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.notificationsMarkAllRead,
      );
      final isSuccess = res.data is Map && res.data['status'] == 'success';
      if (!isSuccess) {
        _cachedNotifications.clear();
        _cachedNotifications.addAll(previousList);
      }
      return isSuccess;
    } catch (_) {
      _cachedNotifications.clear();
      _cachedNotifications.addAll(previousList);
      return false;
    }
  }
}
