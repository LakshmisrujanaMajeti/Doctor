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

import '../../../shared/widgets/smvmch_hospital_logo.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                    // Brand Medical Hero: Official SMVMCH Crest
                    const Center(
                      child: SmvmchHospitalLogo(
                        size: 84,
                        layout: LogoLayout.vertical,
                        showTamilText: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.hospitalMaroon.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.hospitalMaroon.withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.hospitalMaroon,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dedicated Patient Token & UHID Check-In Button
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.hospitalMaroon.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.hospitalMaroon,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.confirmation_number_rounded, size: 22),
                        label: const Text(
                          'Patient Token & UHID Check-In',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => context.push('/patient/token-access'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Primary Staff & Clinician Sign In
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
                    const SizedBox(height: 28),

                    // Hospital Capabilities Highlights: Enterprise OPD Services
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
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'Tap any service icon to view clinical capabilities & workflows',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display ONLY service icons in the section
                    _buildServiceIconsRow(context, isDark),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceIconsRow(BuildContext context, bool isDark) {
    final services = _getEnterpriseServices();

    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 14,
      runSpacing: 16,
      children: services.map((service) {
        final Color color = service['color'] as Color;
        final IconData icon = service['icon'] as IconData;
        final String label = service['label'] as String;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showServiceDetailsSheet(context, service),
          child: SizedBox(
            width: 90,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[200] : AppColors.lightTextPrimary,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showServiceDetailsSheet(BuildContext context, Map<String, dynamic> service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = service['color'] as Color;
    final IconData icon = service['icon'] as IconData;
    final String title = service['title'] as String;
    final String badge = service['badge'] as String;
    final String description = service['description'] as String;
    final List<String> capabilities = (service['capabilities'] as List<String>?) ?? [];
    final String authorizedRoles = service['roles'] as String? ?? 'Authorized Hospital Staff';
    final String route = service['route'] as String? ?? '/login';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header Row
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Icon(icon, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Description
              Text(
                description,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(height: 18),

              // Capabilities List
              const Text(
                'Key Clinical & Operational Capabilities:',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...capabilities.map((cap) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          cap,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),

              // Authorized Roles Badge
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_rounded, size: 18, color: AppColors.hospitalMaroon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Authorized: $authorizedRoles',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.hospitalMaroon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text('Open $title'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.push(route);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getEnterpriseServices() {
    return [
      {
        'title': 'Doctor Portal',
        'label': 'Doctor Portal',
        'badge': 'Clinician Desk',
        'icon': Icons.medical_services_rounded,
        'color': AppColors.primaryBlue,
        'description':
            'Clinical examination suite with consultation sheets, differential diagnosis coding, vitals trending, and digital sign-off.',
        'capabilities': [
          'OPD consultation sheet drafting & amendments',
          'Clinical vital sign trends & patient history',
          'Biochemistry, Hematology & Radiology investigation orders',
          'Electronic signature and auditable medical logs',
        ],
        'roles': 'Doctors, Medical Specialists & Clinical Fellows',
        'route': '/login',
      },
      {
        'title': 'Smart Queue & Triage',
        'label': 'Smart Queue',
        'badge': 'Waiting Hall',
        'icon': Icons.confirmation_number_rounded,
        'color': AppColors.accentTeal,
        'description':
            'Real-time outpatient queue management with automated token generation, multi-department queuing, and 3-tier emergency triage.',
        'capabilities': [
          'Automated token generation and live waiting queue',
          '3-tier triage rating (Emergency, Priority, Normal)',
          'Estimated consultation wait time forecasting',
          'Doctor calling bell & visual queue display integration',
        ],
        'roles': 'Triage Nurses, Receptionists & Outpatients',
        'route': '/queue',
      },
      {
        'title': 'E-Prescriptions & Formulary',
        'label': 'Pharmacy & Rx',
        'badge': 'Hospital Pharmacy',
        'icon': Icons.medication_rounded,
        'color': const Color(0xFF0F766E),
        'description':
            'Digital prescription management with drug interaction cross-checking, dosage scheduling, and real-time hospital inventory verification.',
        'capabilities': [
          'Hospital formulary stock & batch tracking',
          'Allergy safety alerts and contraindication warnings',
          'Unit-I (24hr) & Unit-II dispensing confirmation',
          'Duplicate pharmacy cash bills with institutional DL numbers',
        ],
        'roles': 'Hospital Pharmacists & Attending Physicians',
        'route': '/pharmacy',
      },
      {
        'title': 'Diagnostic Laboratory',
        'label': 'Diagnostic Lab',
        'badge': 'Diagnostics',
        'icon': Icons.biotech_rounded,
        'color': const Color(0xFF8B5CF6),
        'description':
            'End-to-end diagnostic workflow with unique specimen barcoding, test verification, abnormal value panic flags, and printable pathology reports.',
        'capabilities': [
          'Unique specimen barcodes and chain of custody tracking',
          'Biochemistry, Hematology, Pathology, and Microbiology results',
          'Critical panic value alerts to consulting doctors',
          'Sri Manakula Vinayagar certified diagnostic report releases',
        ],
        'roles': 'Laboratory Technicians, Pathologists & Biochemists',
        'route': '/laboratory',
      },
      {
        'title': 'OPD Billing & Cash Counter',
        'label': 'Billing Counter',
        'badge': 'Billing & Invoicing',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF10B981),
        'description':
            'Centralized billing desk handling service tariffs, consultation slips, pharmacy charges, multiple payment channels, and GSTIN invoices.',
        'capabilities': [
          'Service tariff catalogue & itemized bill generation',
          'Cash, Card, UPI, and Insurance collection processing',
          'Automated GST & TIN duplicate cash bill receipts',
          'Audited invoice cancellations and refund management',
        ],
        'roles': 'Billing Staff, Cashiers & Finance Administrators',
        'route': '/billing',
      },
      {
        'title': 'Medical Documents & OCR',
        'label': 'Booklet & OCR',
        'badge': 'Medical Records',
        'icon': Icons.document_scanner_rounded,
        'color': const Color(0xFF6366F1),
        'description':
            'Document capture and optical character recognition for physical outpatient booklets, lab sheets, and patient archives.',
        'capabilities': [
          'Multi-page camera document capture & perspective crop',
          'On-device OCR text extraction & confidence scoring',
          'Handwritten safety badges and verification modal',
          'Non-sensitive barcode identifiers and patient record archive',
        ],
        'roles': 'Medical Records Staff & Consulting Doctors',
        'route': '/documents',
      },
    ];
  }
}
