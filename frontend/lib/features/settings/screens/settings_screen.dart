import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final user = authState.user;
    final roleDisplay = (user?.roleName.isNotEmpty == true ? user!.roleName : 'Staff').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Profile & Hospital Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Profile Header Card
          OpdCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor:
                              AppColors.primaryBlue.withValues(alpha: 0.15),
                          child: Text(
                            user?.fullName.isNotEmpty == true
                                ? user!.fullName[0].toUpperCase()
                                : 'D',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.accentTeal,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName : 'Hospital User',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? 'dr.chen@opdconnect.com',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryBlue
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  roleDisplay,
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              if (user?.email != null && user!.email.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    user.email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: const Icon(Icons.edit_note_rounded, size: 18),
                        label: const Text('Edit Profile & Credentials'),
                        onPressed: () => context.push('/profile-setup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // App Appearance
          const Text(
            'Appearance & Display',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          OpdCard(
            child: SwitchListTile(
              secondary: Icon(
                isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: AppColors.primaryBlue,
              ),
              title: const Text(
                'Dark Mode',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                isDark
                    ? 'Midnight Slate Theme (High Contrast)'
                    : 'Clinical Clean White & Blue Theme',
                style: const TextStyle(fontSize: 12),
              ),
              value: isDark,
              onChanged: (val) {
                ref
                    .read(themeModeProvider.notifier)
                    .setTheme(val ? ThemeMode.dark : ThemeMode.light);
              },
            ),
          ),
          const SizedBox(height: 24),

          // Clinical Data Protection & Privacy
          const Text(
            'Security & Data Governance',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          OpdCard(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.shield_rounded, color: AppColors.primaryBlue),
                  title: Text('Clinical Data Protection',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('TLS 1.3 / AES-256 encrypted OPD health records',
                      style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.verified_user_rounded, color: Colors.green, size: 20),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.sync_rounded, color: AppColors.accentTeal),
                  title: Text('Offline-First Smart Sync Engine',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Immediate offline caching with resilient cloud background sync',
                      style: TextStyle(fontSize: 12)),
                  trailing: Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 20),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.health_and_safety_rounded, color: Color(0xFF8B5CF6)),
                  title: Text('Compliance Standards',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('NABH & HIPAA compliant clinical audit logging',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // About Hospital & Application
          const Text(
            'Hospital System Details',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          OpdCard(
            child: Column(
              children: [
                const ListTile(
                  leading: SmvmchHospitalLogo(size: 28),
                  title: Text('Facility Name', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('Sri Manakula Vinayagar Medical College and Hospital (SMVMCH), Puducherry', style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded, color: Colors.grey),
                  title: const Text('Application Version', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('v1.2.0 (Enterprise Production Build)', style: TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('PRODUCTION READY',
                        style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w800,
                            fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Log Out Button with Confirmation Dialog
          OpdButton(
            label: 'Sign Out of OPD Connect+',
            isOutlined: true,
            icon: Icons.logout_rounded,
            onPressed: () async {
              final confirmed = await showOpdConfirmDialog(
                context: context,
                title: 'Confirm Sign Out',
                message:
                    'Are you sure you want to end your active session on OPD Connect+? Any unsaved consultation draft will be saved locally.',
                confirmText: 'Sign Out',
                isDestructive: true,
              );
              if (confirmed == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.go('/welcome');
                }
              }
            },
          ),
          const SizedBox(height: 24),

          // Hospital Branding Footer
          Center(
            child: Column(
              children: [
                Text(
                  AppStrings.appName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.primaryBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.tagline,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Build v2.4.0 • Enterprise Clinical Edition',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                        : AppColors.lightTextSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
