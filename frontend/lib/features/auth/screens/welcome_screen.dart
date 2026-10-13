import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/opd_card.dart';
import '../../../shared/widgets/server_config_dialog.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Server Connection Settings',
            icon: const Icon(Icons.dns_rounded),
            onPressed: () => ServerConfigDialog.show(context),
          ),
        ],
      ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.auth,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand Medical Hero
                    Center(
                      child: Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primaryBlue, AppColors.accentTeal],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.local_hospital_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      AppStrings.tagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Primary Sign In & Register Buttons
                    OpdButton(
                      label: 'Sign In to Portal',
                      icon: Icons.login_rounded,
                      width: double.infinity,
                      onPressed: () => context.pushNamed(RouteNames.login),
                    ),
                    const SizedBox(height: 12),

                    OpdButton(
                      label: 'Register New Account',
                      icon: Icons.person_add_alt_1_rounded,
                      isOutlined: true,
                      width: double.infinity,
                      onPressed: () => context.pushNamed(RouteNames.profileSetup),
                    ),
                    const SizedBox(height: 32),

                    // Hospital Capabilities Highlights
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'ENTERPRISE OPD SERVICES',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.medical_services_rounded,
                      title: 'Doctor Portal',
                      subtitle: 'Consultation sheets, clinical diagnosis, investigations & follow-ups',
                      badge: 'Clinician Desk',
                      color: AppColors.primaryBlue,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildFeatureCard(
                      icon: Icons.confirmation_number_rounded,
                      title: 'Smart Queue & Triage',
                      subtitle: 'Real-time token generation, queue tracking, and emergency triage prioritization',
                      badge: 'Waiting Hall',
                      color: AppColors.accentTeal,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildFeatureCard(
                      icon: Icons.medication_rounded,
                      title: 'E-Prescriptions & Formulary',
                      subtitle: 'Allergy safety cross-checks, drug interactions, and hospital stock dispensing',
                      badge: 'Formulary',
                      color: Colors.teal.shade700,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),

                    _buildFeatureCard(
                      icon: Icons.biotech_rounded,
                      title: 'Diagnostic Laboratory',
                      subtitle: 'Specimen barcodes, verified pathology results, and printable reports',
                      badge: 'Diagnostics',
                      color: const Color(0xFF8B5CF6),
                      isDark: isDark,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color color,
    required bool isDark,
  }) {
    return OpdCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
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
                        title,
                        softWrap: true,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  softWrap: true,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
