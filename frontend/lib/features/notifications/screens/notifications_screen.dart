import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';
import '../models/notification_item_model.dart';
import '../providers/notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'All Updates'},
    {'key': 'alert', 'label': 'Triage Alerts'},
    {'key': 'queue', 'label': 'Queue Updates'},
    {'key': 'lab', 'label': 'Lab Reports'},
    {'key': 'pharmacy', 'label': 'Pharmacy'},
    {'key': 'billing', 'label': 'Billing'},
  ];

  bool _isMarkingAll = false;

  Future<void> _handleMarkAllAsRead() async {
    if (_isMarkingAll) return;
    setState(() => _isMarkingAll = true);
    try {
      await ref.read(notificationRepositoryProvider).markAllAsRead();
      ref.invalidate(notificationsListProvider);
      ref.invalidate(unreadNotificationCountProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _handleItemTap(NotificationItemModel item) async {
    // 1. Mark as read on backend if not already read
    if (!item.isRead) {
      final success = await ref.read(notificationRepositoryProvider).markAsRead(item.id);
      if (success) {
        ref.invalidate(unreadNotificationCountProvider);
        ref.invalidate(notificationsListProvider);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.category.toUpperCase()} • ${item.timeAgo}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                item.message,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: OpdButton(
                      label: 'Dismiss',
                      isOutlined: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  if (item.targetRoute != null && item.targetRoute!.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: OpdButton(
                        label: 'View Details →',
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push(item.targetRoute!);
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory = ref.watch(notificationCategoryFilterProvider);
    final notificationsAsync = ref.watch(notificationsListProvider);
    final unreadCountAsync = ref.watch(unreadNotificationCountProvider);
    final unreadCount = unreadCountAsync.value ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.dashboard);
            }
          },
        ),
        title: Row(
          children: [
            const Text('Hospital Alerts'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.triageEmergency,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unreadCount NEW',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Mark all as read',
            icon: _isMarkingAll
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.done_all_rounded),
            onPressed: (unreadCount > 0 && !_isMarkingAll) ? _handleMarkAllAsRead : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue.withOpacity(0.15),
                    checkmarkColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primaryBlue
                          : (isDark ? Colors.white70 : Colors.black87),
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12.5,
                    ),
                    onSelected: (val) {
                      ref.read(notificationCategoryFilterProvider.notifier).setCategory(cat['key']!);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Main Notifications List with Real Pull-to-Refresh
          Expanded(
            child: notificationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.triageEmergency),
                      const SizedBox(height: 12),
                      Text('Error loading notifications: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        onPressed: () => ref.refresh(notificationsListProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (notifications) {
                if (notifications.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationCountProvider);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 100),
                        EmptyStateWidget(
                          icon: Icons.notifications_none_rounded,
                          title: 'No Notifications',
                          message: 'All caught up! You do not have any alerts in this category.',
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(notificationsListProvider);
                    ref.invalidate(unreadNotificationCountProvider);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return OpdCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => _handleItemTap(item),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(item.icon, color: item.color, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: item.isRead
                                                ? (isDark ? Colors.white70 : Colors.black87)
                                                : (isDark ? Colors.white : Colors.black),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        item.timeAgo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.message,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (item.targetRoute != null && item.targetRoute!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          'Tap to view details',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: item.color,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        Icon(Icons.arrow_forward_rounded, size: 12, color: item.color),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!item.isRead) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(top: 6),
                                decoration: BoxDecoration(
                                  color: item.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
