import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class TriageChip extends StatelessWidget {
  final String priority;
  final bool compact;

  const TriageChip({
    super.key,
    required this.priority,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData icon;
    String label = priority.toUpperCase();

    switch (label) {
      case 'EMERGENCY':
        bg = AppColors.triageEmergency.withValues(alpha: 0.12);
        fg = AppColors.triageEmergency;
        icon = Icons.warning_rounded;
        break;
      case 'PRIORITY':
        bg = AppColors.triagePriority.withValues(alpha: 0.15);
        fg = AppColors.triagePriority;
        icon = Icons.priority_high_rounded;
        break;
      default:
        bg = AppColors.triageNormal.withValues(alpha: 0.12);
        fg = AppColors.triageNormal;
        icon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
