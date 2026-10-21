import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';

class OfflineScreen extends StatefulWidget {
  final VoidCallback? onRetry;

  const OfflineScreen({super.key, this.onRetry});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isRetrying = false;

  Future<void> _handleRetry() async {
    setState(() => _isRetrying = true);
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _isRetrying = false);

    if (widget.onRetry != null) {
      widget.onRetry!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checking hospital server connectivity...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.triagePriority.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    size: 46,
                    color: AppColors.triagePriority,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Hospital Network Offline',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                'Unable to reach OPD server at 127.0.0.1:8000 or Supabase cloud. Outpatient offline caching is protecting pending records.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 28),

              // Network Service Matrix Card
              OpdCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _serviceStatusRow(
                      icon: Icons.storage_rounded,
                      title: 'Local Outpatient Cache',
                      statusText: 'Synchronized & Secure',
                      color: AppColors.statusCompleted,
                      isDark: isDark,
                    ),
                    const Divider(height: 20),
                    _serviceStatusRow(
                      icon: Icons.dns_rounded,
                      title: 'FastAPI Backend Core',
                      statusText: 'Disconnected (Port 8000)',
                      color: AppColors.triageEmergency,
                      isDark: isDark,
                    ),
                    const Divider(height: 20),
                    _serviceStatusRow(
                      icon: Icons.cloud_queue_rounded,
                      title: 'Supabase PostgreSQL Cloud',
                      statusText: 'Pending Reconnect',
                      color: AppColors.triagePriority,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              OpdButton(
                label: 'Retry Network Connection',
                icon: Icons.refresh_rounded,
                isLoading: _isRetrying,
                onPressed: _handleRetry,
              ),
              const SizedBox(height: 12),
              OpdButton(
                label: 'Continue in Offline Cache Mode',
                isOutlined: true,
                icon: Icons.offline_pin_rounded,
                onPressed: () => context.go('/dashboard'),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                label: const Text('Open Infrastructure Settings'),
                onPressed: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _serviceStatusRow({
    required IconData icon,
    required String title,
    required String statusText,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
