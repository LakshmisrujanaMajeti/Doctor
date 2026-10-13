import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class ErrorBannerWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const ErrorBannerWidget({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.triageEmergency.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.triageEmergency.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.triageEmergency, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.triageEmergency,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.triageEmergency,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: onRetry,
              child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.triageEmergency),
              onPressed: onDismiss,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}
