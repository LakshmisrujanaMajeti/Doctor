import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/data/mock_presentation_data.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<HospitalNotificationItem> _notifications;
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = const [
    {'key': 'all', 'label': 'All Updates'},
    {'key': 'alert', 'label': 'Triage Alerts'},
    {'key': 'queue', 'label': 'Queue Updates'},
    {'key': 'lab', 'label': 'Lab Reports'},
    {'key': 'pharmacy', 'label': 'Pharmacy'},
  ];

  @override
  void initState() {
    super.initState();
    _notifications = [];
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications.map((item) {
        return HospitalNotificationItem(
          id: item.id,
          title: item.title,
          message: item.message,
          timeAgo: item.timeAgo,
          category: item.category,
          isRead: true,
          icon: item.icon,
          color: item.color,
        );
      }).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('All notifications marked as read'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleRead(String id) {
    setState(() {
      _notifications = _notifications.map((item) {
        if (item.id == id) {
          return HospitalNotificationItem(
            id: item.id,
            title: item.title,
            message: item.message,
            timeAgo: item.timeAgo,
            category: item.category,
            isRead: !item.isRead,
            icon: item.icon,
            color: item.color,
          );
        }
        return item;
      }).toList();
    });
  }

  void _showNotificationDetail(HospitalNotificationItem item) {
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
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.14),
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
                      label: 'View in Queue',
                      icon: Icons.open_in_new_rounded,
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push('/queue');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      _toggleRead(item.id);
                      Navigator.pop(ctx);
                    },
                    child: Text(
                      item.isRead ? 'Mark Unread' : 'Mark Read',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filtered = _notifications.where((n) {
      if (_selectedCategory == 'all') return true;
      return n.category == _selectedCategory;
    }).toList();

    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
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
            icon: const Icon(Icons.done_all_rounded),
            onPressed: unreadCount > 0 ? _markAllAsRead : null,
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
                final isSelected = _selectedCategory == cat['key'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat['label']!),
                    selected: isSelected,
                    selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primaryBlue,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryBlue
                          : (isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _selectedCategory = cat['key']!;
                      });
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),

          // Notification List
          Expanded(
            child: _notifications.isEmpty
                ? const Center(
                    child: EmptyStateWidget(
                      icon: Icons.notifications_none_rounded,
                      title: 'No Notifications',
                      message:
                          'All clinical queues, triage alerts, and lab results are up to date.',
                    ),
                  )
                : (filtered.isEmpty
                    ? Center(
                        child: EmptyStateWidget(
                          icon: Icons.notifications_none_rounded,
                          title: 'No Alerts in this Category',
                          message:
                              'All outpatient updates for this category have been cleared or read.',
                          actionLabel: 'View All Notifications',
                          onAction: () {
                            setState(() {
                              _selectedCategory = 'all';
                            });
                          },
                        ),
                      )
                    : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      return OpdCard(
                        padding: const EdgeInsets.all(14),
                        onTap: () => _showNotificationDetail(item),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                item.icon,
                                color: item.color,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(
                                            color: AppColors.primaryBlue,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.timeAgo,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark
                                              ? AppColors.darkTextSecondary
                                                  .withValues(alpha: 0.7)
                                              : AppColors.lightTextSecondary
                                                  .withValues(alpha: 0.8),
                                        ),
                                      ),
                                      Text(
                                        item.category.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: item.color,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )),
          ),
        ],
      ),
    );
  }
}
