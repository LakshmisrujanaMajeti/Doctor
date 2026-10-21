import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String display = status.replaceAll('_', ' ').toUpperCase();

    switch (status.toUpperCase()) {
      case 'REGISTERED':
        color = AppColors.statusRegistered;
        break;
      case 'TRIAGED':
        color = AppColors.statusTriaged;
        break;
      case 'IN_CONSULTATION':
        color = AppColors.statusInConsult;
        break;
      case 'COMPLETED':
        color = AppColors.statusCompleted;
        break;
      case 'CANCELLED':
        color = AppColors.statusCancelled;
        break;
      default:
        color = Colors.blueGrey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        display,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
