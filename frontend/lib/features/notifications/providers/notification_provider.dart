import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/dio_client.dart';
import '../models/notification_item_model.dart';
import '../repositories/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return NotificationRepository(dioClient);
});

class NotificationCategoryNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setCategory(String category) => state = category;
}

final notificationCategoryFilterProvider = NotifierProvider<NotificationCategoryNotifier, String>(NotificationCategoryNotifier.new);

final notificationsListProvider = FutureProvider.autoDispose<List<NotificationItemModel>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final category = ref.watch(notificationCategoryFilterProvider);
  return await repo.fetchNotifications(category: category);
});

final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return await repo.fetchUnreadCount();
});
