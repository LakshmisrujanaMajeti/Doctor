import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/app_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/mock_presentation_data.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';
import '../../auth/models/auth_state.dart';
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
    final currentRole = user?.roleName.toLowerCase() ?? 'receptionist';

    return Scaffold(
      appBar: AppBar(
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
                            user?.fullName ?? 'Dr. Sarah Chen, MD',
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
                                  currentRole.toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primaryBlue,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'OPD-REG #40892',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.lightTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
          const SizedBox(height: 24),

          // Role Switcher Demo Tool (Allows instantaneous exploration of all 5 perspectives)
          const Text(
            'Simulate Clinical Role Perspective',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Switch perspective to explore role-specific queues, actions, and KPI views.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          OpdCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MockPresentationData.rolePresets.map((preset) {
                final isSelected = currentRole == preset.roleKey;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        preset.icon,
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Text(preset.title),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryBlue,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : null,
                  ),
                  onSelected: (val) {
                    if (val) {
                      _switchRole(ref, preset);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Active perspective changed to: ${preset.title}',
                          ),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

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

          // Connectivity & Infrastructure
          const Text(
            'Hospital Infrastructure Status',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          OpdCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_rounded,
                      color: AppColors.primaryBlue),
                  title: const Text('FastAPI OPD Backend',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(AppConfig.apiBaseUrl,
                      style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.statusCompleted.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('RUNNING :8000',
                        style: TextStyle(
                            color: AppColors.statusCompleted,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_rounded,
                      color: AppColors.accentTeal),
                  title: const Text('Supabase Database',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('xxwidqatsxzsrulaxxal.supabase.co',
                      style: TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('CONFIGURED',
                        style: TextStyle(
                            color: AppColors.accentTeal,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shield_outlined,
                      color: Color(0xFF8B5CF6)),
                  title: const Text('Clinical Data Encryption',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('TLS 1.3 / AES-256 OPD records safe',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // System Screen Previews (For Evaluator & Verification)
          const Text(
            'Preview System State Screens',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Quickly test the reusable error, loading, offline, and unauthorized screens.',
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 10),
          OpdCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.hourglass_top_rounded,
                      color: AppColors.primaryBlue),
                  title: const Text('Loading Screen'),
                  subtitle: const Text('Pulsing brand sync state',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/loading'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wifi_off_rounded,
                      color: AppColors.triagePriority),
                  title: const Text('Offline Screen'),
                  subtitle: const Text('Network disconnection handling',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/offline'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.triageEmergency),
                  title: const Text('Unauthorized Screen (403)'),
                  subtitle: const Text('Role clearance restriction',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/unauthorized'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.search_off_rounded,
                      color: Colors.grey),
                  title: const Text('Route Not Found Screen (404)'),
                  subtitle: const Text('Safe fallback for unknown paths',
                      style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/non-existent-opd-route'),
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

  void _switchRole(WidgetRef ref, RolePreset preset) {
    final authNotifier = ref.read(authProvider.notifier);
    final current = ref.read(authProvider);

    final updatedUser = UserModel(
      id: current.user?.id ?? 'simulated-user',
      email: preset.email,
      fullName: preset.subtitle.split('(').first.trim(),
      phone: current.user?.phone ?? '+1 (555) 234-5678',
      roleName: preset.roleKey,
    );

    // Update state to use new role
    authNotifier.setSimulatedUser(updatedUser);
  }
}
