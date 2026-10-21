import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';

class NotFoundScreen extends StatelessWidget {
  final String? path;

  const NotFoundScreen({super.key, this.path});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Page Not Found'),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.search_off_rounded,
                      size: 52,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  '404 - Screen Not Found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The requested clinical route does not exist or has been relocated within the outpatient department workflow.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                        height: 1.5,
                      ),
                ),
                if (path != null && path!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  OpdCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.link_off_rounded,
                          size: 18,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            path!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 36),
                OpdButton(
                  label: 'Return to OPD Dashboard',
                  icon: Icons.dashboard_rounded,
                  onPressed: () => context.go('/dashboard'),
                ),
                const SizedBox(height: 12),
                OpdButton(
                  label: 'View Live OPD Queue',
                  isOutlined: true,
                  icon: Icons.queue_rounded,
                  onPressed: () => context.go('/queue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
