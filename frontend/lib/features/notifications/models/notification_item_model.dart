import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class NotificationItemModel {
  final String id;
  final String title;
  final String message;
  final String category;
  final String priority;
  final bool isRead;
  final DateTime? readAt;
  final String? targetRoute;
  final String? entityType;
  final String? entityId;
  final DateTime createdAt;

  const NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    this.category = 'general',
    this.priority = 'NORMAL',
    this.isRead = false,
    this.readAt,
    this.targetRoute,
    this.entityType,
    this.entityId,
    required this.createdAt,
  });

  factory NotificationItemModel.fromJson(Map<String, dynamic> json) {
    return NotificationItemModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Hospital Alert',
      message: json['message'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      priority: json['priority'] as String? ?? 'NORMAL',
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      targetRoute: json['target_route'] as String?,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'priority': priority,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'target_route': targetRoute,
      'entity_type': entityType,
      'entity_id': entityId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  NotificationItemModel copyWith({
    String? id,
    String? title,
    String? message,
    String? category,
    String? priority,
    bool? isRead,
    DateTime? readAt,
    String? targetRoute,
    String? entityType,
    String? entityId,
    DateTime? createdAt,
  }) {
    return NotificationItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      targetRoute: targetRoute ?? this.targetRoute,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  IconData get icon {
    switch (category.toLowerCase()) {
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'queue':
        return Icons.confirmation_number_rounded;
      case 'lab':
        return Icons.biotech_rounded;
      case 'pharmacy':
        return Icons.medication_rounded;
      case 'billing':
        return Icons.receipt_long_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color get color {
    if (priority.toUpperCase() == 'EMERGENCY') {
      return AppColors.triageEmergency;
    }
    if (priority.toUpperCase() == 'PRIORITY') {
      return AppColors.triagePriority;
    }
    switch (category.toLowerCase()) {
      case 'alert':
        return AppColors.triageEmergency;
      case 'queue':
        return AppColors.primaryBlue;
      case 'lab':
        return AppColors.accentTeal;
      case 'pharmacy':
        return const Color(0xFF8B5CF6);
      case 'billing':
        return Colors.green.shade700;
      default:
        return AppColors.primaryBlue;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}
