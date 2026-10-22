import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/responsive.dart';
import '../../../routing/route_names.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/opd_card.dart';
import '../../../shared/widgets/stat_metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../auth/models/auth_state.dart';
import '../../auth/providers/auth_provider.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../models/dashboard_stats.dart';
import '../providers/dashboard_provider.dart';
import 'doctor_dashboard_view.dart';
import '../providers/doctor_dashboard_provider.dart';
import '../../laboratory/screens/laboratory_workspace_view.dart';
import '../../laboratory/providers/laboratory_provider.dart';
import '../../pharmacy/screens/pharmacy_workspace_view.dart';
import '../../pharmacy/providers/pharmacy_provider.dart';
import '../../billing/screens/billing_workspace_view.dart';
import '../../billing/providers/billing_provider.dart';
import '../../doctors/repositories/doctor_repository.dart';
import '../../doctors/models/doctor_model.dart';

class RoleDashboardShell extends ConsumerStatefulWidget {
  const RoleDashboardShell({super.key});

  @override
  ConsumerState<RoleDashboardShell> createState() => _RoleDashboardShellState();
}

class _RoleDashboardShellState extends ConsumerState<RoleDashboardShell> {
  int _currentTabIndex = 0;
  Timer? _realtimeRefreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh realtime OPD queue metrics and clinical consultations periodically
    _realtimeRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        final role = ref.read(authProvider).user?.roleName.toLowerCase() ?? 'receptionist';
        if (role != 'patient') {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(visitListProvider);
          ref.invalidate(doctorDashboardProvider);
        } else {
          ref.invalidate(visitListProvider);
        }
      }
    });
  }

  @override
  void dispose() {
    _realtimeRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final currentRole = user?.roleName.toLowerCase() ?? 'receptionist';
    final statsAsync = ref.watch(dashboardStatsProvider);
    final visitsAsync = ref.watch(visitListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentTabIndex != 0) {
          setState(() => _currentTabIndex = 0);
        } else {
          final shouldExit = await showOpdConfirmDialog(
            context: context,
            title: 'Close Application?',
            message:
                'Do you want to exit OPD Connect+? Your clinical session remains securely saved.',
            confirmText: 'Exit App',
          );
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 10,
          title: Row(
            children: [
              const SmvmchHospitalLogo(size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            AppStrings.appName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Colors.green, size: 5),
                              SizedBox(width: 2.5),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Text(
                      AppStrings.hospitalFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          actions: [
            // Role Badge (Pill) - Only staff can tap to view profile options; Patient has dedicated read-only badge
            if (currentRole != 'patient')
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _showUserProfileSheet(context, ref, authState, currentRole),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getRoleIcon(currentRole),
                        size: 13,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentRole.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 15,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.teal.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 13,
                      color: Colors.teal,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PATIENT PORTAL',
                      style: TextStyle(
                        color: Colors.teal,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(width: 2),

            // Notifications Icon with Badge
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Hospital Notifications',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, size: 21),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.triageEmergency,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              onPressed: () => context.push('/notifications'),
            ),

            // Settings Icon
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Settings & Profile',
              icon: const Icon(Icons.settings_outlined, size: 21),
              onPressed: () => context.push('/settings'),
            ),

            // Top Right Corner Logout Button
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: 'Log Out',
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 21),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Row(
                      children: [
                        Icon(Icons.logout_rounded, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Confirm Logout'),
                      ],
                    ),
                    content: const Text('Are you sure you want to log out of the OPD Connect portal?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.goNamed(RouteNames.welcome);
                  }
                }
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: MedicalIllustratorBackground(
          variant: MedicalBackgroundVariant.dashboard,
          child: RefreshIndicator(

          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(visitListProvider);
            ref.invalidate(doctorDashboardProvider);
            ref.invalidate(labOrdersListProvider);
            ref.invalidate(labDashboardStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            padding: EdgeInsets.only(
              left: Responsive.horizontalPadding(context),
              right: Responsive.horizontalPadding(context),
              top: 16,
              bottom: 96,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Personalized Role Welcome Banner
                _buildRoleWelcomeBanner(
                  context: context,
                  userName: user?.fullName ?? _getDefaultNameForRole(currentRole),
                  role: currentRole,
                  isDark: isDark,
                ),
                const SizedBox(height: 20),

                if (currentRole == 'doctor') ...[
                  const DoctorDashboardView(),
                ] else if (currentRole == 'laboratory' || currentRole == 'lab_tech') ...[
                  const LaboratoryWorkspaceView(),
                ] else if (currentRole == 'pharmacist') ...[
                  const PharmacyWorkspaceView(),
                ] else if (currentRole == 'billing') ...[
                  const BillingWorkspaceView(),
                ] else ...[
                  // 2. Role-Aware KPI Metrics Grid
                  if (currentRole == 'patient') ...[
                    _buildRoleMetricsGrid(
                      context: context,
                      role: currentRole,
                      stats: const DashboardStatsModel(),
                      visitsAsync: visitsAsync,
                    ),
                  ] else ...[
                    statsAsync.when(
                      skipLoadingOnReload: true,
                      data: (stats) => _buildRoleMetricsGrid(
                        context: context,
                        role: currentRole,
                        stats: stats,
                        visitsAsync: visitsAsync,
                      ),
                      loading: () => statsAsync.hasValue
                          ? _buildRoleMetricsGrid(
                              context: context,
                              role: currentRole,
                              stats: statsAsync.value!,
                              visitsAsync: visitsAsync,
                            )
                          : const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                      error: (err, stack) => statsAsync.hasValue
                          ? _buildRoleMetricsGrid(
                              context: context,
                              role: currentRole,
                              stats: statsAsync.value!,
                              visitsAsync: visitsAsync,
                            )
                          : const SizedBox(),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // 3. Role-Aware Quick Action Hub
                  _buildRoleQuickActions(
                    context: context,
                    role: currentRole,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 24),

                  // 4. Role-Specific Main Workflow Section
                  _buildRoleMainContent(
                    context: context,
                    role: currentRole,
                    visitsAsync: visitsAsync,
                    isDark: isDark,
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        ),
        bottomNavigationBar: _buildRoleBottomNavigationBar(context, currentRole, isDark),
      ),
    );
  }

  Widget _buildRoleBottomNavigationBar(BuildContext context, String role, bool isDark) {
    List<NavigationDestination> destinations;
    ValueChanged<int> onSelect;

    switch (role) {
      case 'patient':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_rounded),
            label: 'My Health',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_rounded),
            label: 'My Token',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_shared_rounded),
            label: 'Records',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Bills',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/patient/portal');
          if (idx == 3) context.push('/patient/portal');
          if (idx == 4) context.push('/settings');
        };
        break;

      case 'doctor':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.medical_services_rounded),
            label: 'Doctor OPD',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/patients');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'nurse':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_rounded),
            label: 'Nursing',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'Triage Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/patients');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'receptionist':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.desk_rounded),
            label: 'Front Desk',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_add_alt_1_rounded),
            label: 'Intake / Reg',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/patients');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'pharmacist':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_rounded),
            label: 'Pharmacy',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'OPD Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_rounded),
            label: 'Formulary',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/pharmacy');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'laboratory':
      case 'lab_tech':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.biotech_rounded),
            label: 'Laboratory',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.science_rounded),
            label: 'Worklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/laboratory');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'billing':
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_rounded),
            label: 'Cashier',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'OPD Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_rounded),
            label: 'Billing Counter',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/billing');
          if (idx == 3) context.push('/settings');
        };
        break;

      case 'admin':
      default:
        destinations = const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_rounded),
            label: 'Queue',
          ),
          NavigationDestination(
            icon: Icon(Icons.admin_panel_settings_rounded),
            label: 'Admin Portal',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_rounded),
            label: 'Patients',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ];
        onSelect = (idx) {
          setState(() => _currentTabIndex = idx);
          if (idx == 1) context.push('/queue');
          if (idx == 2) context.push('/admin/portal');
          if (idx == 3) context.push('/patients');
          if (idx == 4) context.push('/settings');
        };
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 60,
            indicatorColor: AppColors.primaryBlue.withValues(alpha: 0.14),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final isSelected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: 22,
                color: isSelected
                    ? AppColors.primaryBlue
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              );
            }),
          ),
          child: NavigationBar(
            height: 60,
            elevation: 0,
            backgroundColor: Colors.transparent,
            selectedIndex: _currentTabIndex.clamp(0, destinations.length - 1),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: onSelect,
            destinations: destinations,
          ),
        ),
      ),
    );
  }

  // Welcome Banner customized per role
  Widget _buildRoleWelcomeBanner({
    required BuildContext context,
    required String userName,
    required String role,
    required bool isDark,
  }) {
    final roleTaglines = {
      'doctor': 'Consultations Active • OPD Room 104 • Next patient ready',
      'receptionist': 'Registration & Token Desk • Waiting hall queue active',
      'nurse': 'Triage Station • Vital checks and priority escalation active',
      'admin': 'OPD Management Console • Hospital system health optimal',
      'patient': 'Personal Health Hub • Live OPD token and visit tracking',
      'laboratory': 'Diagnostic Pathology Desk • Automated analyzer queue ready',
      'lab_tech': 'Diagnostic Pathology Desk • Automated analyzer queue ready',
      'pharmacist': 'Outpatient Pharmacy Counter • Dispensing & stock active',
      'billing': 'Central Billing Counter • Invoices, payments & collections',
    };

    final roleGradients = {
      'doctor': [const Color(0xFF0F62FE), const Color(0xFF0043CE)],
      'receptionist': [const Color(0xFF007A6E), const Color(0xFF004D40)],
      'nurse': [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      'admin': [const Color(0xFF334155), const Color(0xFF0F172A)],
      'patient': [const Color(0xFF0F62FE), const Color(0xFF00A896)],
      'laboratory': [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      'lab_tech': [const Color(0xFF6366F1), const Color(0xFF4338CA)],
      'pharmacist': [const Color(0xFF0D9488), const Color(0xFF0F766E)],
      'billing': [const Color(0xFF15803D), const Color(0xFF166534)],
    };

    final colors = isDark
        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
        : (roleGradients[role] ?? [AppColors.primaryBlue, AppColors.primaryBlueDark]);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(
              _getRoleIcon(role),
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  roleTaglines[role] ?? 'Hospital Outpatient Services Active',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMetricRow(BuildContext context, List<Widget> cards) {
    final isTablet = MediaQuery.sizeOf(context).width >= 650;
    final isSmall = MediaQuery.sizeOf(context).width < 360;
    final gap = isSmall ? 8.0 : 12.0;

    if (isTablet && cards.length == 4) {
      return Row(
        children: [
          Expanded(child: cards[0]),
          SizedBox(width: gap),
          Expanded(child: cards[1]),
          SizedBox(width: gap),
          Expanded(child: cards[2]),
          SizedBox(width: gap),
          Expanded(child: cards[3]),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            SizedBox(width: gap),
            Expanded(child: cards[1]),
          ],
        ),
        SizedBox(height: gap),
        if (cards.length > 2)
          Row(
            children: [
              Expanded(child: cards[2]),
              SizedBox(width: gap),
              Expanded(child: cards.length > 3 ? cards[3] : const SizedBox()),
            ],
          ),
      ],
    );
  }

  // Role-Aware KPI Metrics
  Widget _buildRoleMetricsGrid({
    required BuildContext context,
    required String role,
    required DashboardStatsModel stats,
    required AsyncValue<List<OPDVisitModel>> visitsAsync,
  }) {
    switch (role) {
      case 'doctor':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Waiting for Me',
            value: stats.waiting.toString(),
            icon: Icons.hourglass_top_rounded,
            color: AppColors.triagePriority,
            subtitle: 'In Line',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'In Consultation',
            value: stats.triaged.toString(),
            icon: Icons.medical_services_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'Current Room',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Consulted Today',
            value: stats.completed.toString(),
            icon: Icons.task_alt_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Concluded',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Total OPD Today',
            value: stats.totalVisits.toString(),
            icon: Icons.people_alt_rounded,
            color: AppColors.accentTeal,
            subtitle: 'General Clinic',
            onTap: () => context.push('/queue'),
          ),
        ]);

      case 'nurse':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Awaiting Triage',
            value: stats.waiting.toString(),
            icon: Icons.monitor_heart_rounded,
            color: AppColors.triageEmergency,
            subtitle: 'Pending Vitals',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Triaged & Ready',
            value: stats.triaged.toString(),
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.accentTeal,
            subtitle: 'To Doctor',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Total Visits',
            value: stats.totalVisits.toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: AppColors.primaryBlue,
            subtitle: "Today's Intake",
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Doctors Active',
            value: stats.activeDoctors.toString(),
            icon: Icons.medical_services_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: 'In Clinic Rooms',
            onTap: () => _showDoctorRosterDialog(context),
          ),
        ]);

      case 'patient':
        final allVisits = visitsAsync.asData?.value ?? [];
        final myVisit = allVisits.isNotEmpty ? allVisits.first : null;
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Your UHID',
            value: myVisit?.patient?.uhid ?? 'Active Record',
            icon: Icons.badge_outlined,
            color: AppColors.primaryBlue,
            subtitle: myVisit?.departmentName ?? 'OPD Patient',
            onTap: () => context.push('/patient/portal'),
          ),
          StatMetricCard(
            title: 'Queue Status',
            value: myVisit?.status ?? 'READY',
            icon: Icons.timer_outlined,
            color: AppColors.accentTeal,
            subtitle: myVisit != null ? 'Slip: ${myVisit.visitNumber}' : 'Visit Slip Not Issued',
            onTap: () => context.push('/patient/portal'),
          ),
          StatMetricCard(
            title: 'Assigned Physician',
            value: myVisit?.doctorName ?? 'Consultation Desk',
            icon: Icons.meeting_room_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: myVisit?.departmentName ?? 'Outpatient Clinic',
            onTap: () => context.push('/patient/portal'),
          ),
          StatMetricCard(
            title: 'Health Services',
            value: 'Patient Portal',
            icon: Icons.health_and_safety_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Rx, Labs & Invoices',
            onTap: () => context.push('/patient/portal'),
          ),
        ]);

      case 'admin':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Hospital OPD Total',
            value: stats.totalPatients.toString(),
            icon: Icons.groups_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'Active UHIDs',
            onTap: () => context.push('/patients'),
          ),
          StatMetricCard(
            title: "Today's Footfall",
            value: stats.totalVisits.toString(),
            icon: Icons.assessment_rounded,
            color: AppColors.accentTeal,
            subtitle: 'Visits Registered',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Active Clinics',
            value: '${stats.departments} Depts',
            icon: Icons.domain_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: 'Operational',
            onTap: () => _showActiveClinicsDialog(context),
          ),
          StatMetricCard(
            title: 'Doctor Roster',
            value: '${stats.activeDoctors} On Duty',
            icon: Icons.badge_outlined,
            color: AppColors.statusCompleted,
            subtitle: 'Consulting',
            onTap: () => _showDoctorRosterDialog(context),
          ),
        ]);


      case 'laboratory':
      case 'lab_tech':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Pending Tests',
            value: '${stats.triaged} Tests',
            icon: Icons.biotech_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'Awaiting Run',
            onTap: () => context.push('/laboratory'),
          ),
          StatMetricCard(
            title: 'Abnormal Results',
            value: '0 Flagged',
            icon: Icons.warning_amber_rounded,
            color: AppColors.triageEmergency,
            subtitle: 'Critical Alerts',
            onTap: () => context.push('/laboratory'),
          ),
          StatMetricCard(
            title: 'Completed Tests',
            value: '${stats.completed} Verified',
            icon: Icons.task_alt_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Verified & Sent',
            onTap: () => context.push('/laboratory'),
          ),
          StatMetricCard(
            title: 'Lab Turnaround',
            value: 'Active TAT',
            icon: Icons.timer_outlined,
            color: AppColors.accentTeal,
            subtitle: 'Average Turnaround',
            onTap: () => context.push('/laboratory'),
          ),
        ]);

      case 'billing':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Active Invoices',
            value: '${stats.waiting + stats.triaged}',
            icon: Icons.receipt_long_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'Pending Collection',
            onTap: () => context.push('/billing'),
          ),
          StatMetricCard(
            title: 'Settled Today',
            value: stats.completed.toString(),
            icon: Icons.check_circle_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Paid Invoices',
            onTap: () => context.push('/billing'),
          ),
          StatMetricCard(
            title: 'Patient Slips',
            value: stats.totalVisits.toString(),
            icon: Icons.assignment_turned_in_rounded,
            color: AppColors.accentTeal,
            subtitle: 'Counter Registrations',
            onTap: () => context.push('/billing'),
          ),
          StatMetricCard(
            title: 'Revenue Audit',
            value: 'Optimal',
            icon: Icons.account_balance_wallet_rounded,
            color: const Color(0xFF8B5CF6),
            subtitle: 'Daily Reconciliation',
            onTap: () => context.push('/billing'),
          ),
        ]);

      case 'pharmacist':
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Rx Dispensing Queue',
            value: '${stats.waiting + stats.triaged} Active',
            icon: Icons.medication_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'To Dispense',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Medicines Dispensed',
            value: '${stats.completed} Today',
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Fulfilled Visits',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Pending Payments',
            value: 'Counter Queue',
            icon: Icons.receipt_long_rounded,
            color: AppColors.triagePriority,
            subtitle: 'Billing Ready',
            onTap: () => context.push('/billing'),
          ),
          StatMetricCard(
            title: 'Formulary Status',
            value: 'Stock Optimal',
            icon: Icons.inventory_2_outlined,
            color: AppColors.statusCompleted,
            subtitle: 'Core Medications',
            onTap: () => context.push('/queue'),
          ),
        ]);

      case 'receptionist':
      default:
        return _buildResponsiveMetricRow(context, [
          StatMetricCard(
            title: 'Total Patients',
            value: stats.totalPatients.toString(),
            icon: Icons.people_alt_rounded,
            color: AppColors.primaryBlue,
            subtitle: 'Registered UHIDs',
            onTap: () => context.push('/patients'),
          ),
          StatMetricCard(
            title: "Today's Tokens",
            value: stats.totalVisits.toString(),
            icon: Icons.confirmation_number_rounded,
            color: AppColors.accentTeal,
            subtitle: 'Issued Slips',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Waiting in Hall',
            value: stats.waiting.toString(),
            icon: Icons.airline_seat_recline_normal_rounded,
            color: AppColors.triagePriority,
            subtitle: 'Queue Active',
            onTap: () => context.push('/queue'),
          ),
          StatMetricCard(
            title: 'Completed',
            value: stats.completed.toString(),
            icon: Icons.check_circle_rounded,
            color: AppColors.statusCompleted,
            subtitle: 'Visits Concluded',
            onTap: () => context.push('/queue'),
          ),
        ]);
    }
  }

  // Role-Aware Quick Actions
  Widget _buildRoleQuickActions({
    required BuildContext context,
    required String role,
    required bool isDark,
  }) {
    final title = 'Clinical Quick Actions • ${role.toUpperCase()}';

    List<Map<String, dynamic>> actions = [];

    if (role == 'doctor') {
      actions = [
        {
          'title': 'Call Next Patient',
          'desc': 'Summon top waiting token',
          'icon': Icons.campaign_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'OPD Queue List',
          'desc': 'Review triage priority',
          'icon': Icons.playlist_play_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'Patient Directory',
          'desc': 'Lookup past records',
          'icon': Icons.folder_shared_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/patients'),
        },
        {
          'title': 'Medical Documents & OCR',
          'desc': 'Capture & review booklets',
          'icon': Icons.document_scanner,
          'color': Colors.indigo,
          'onTap': () => context.push('/documents'),
        },
        {
          'title': 'Hospital Alerts',
          'desc': 'Urgent triage notices',
          'icon': Icons.warning_amber_rounded,
          'color': AppColors.triageEmergency,
          'onTap': () => context.push('/notifications'),
        },
      ];
    } else if (role == 'nurse') {
      actions = [
        {
          'title': 'Record Vitals',
          'desc': 'BP, SpO2, Pulse, Temp',
          'icon': Icons.monitor_heart_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'Triage Evaluation',
          'desc': 'Assign triage priority',
          'icon': Icons.emergency_rounded,
          'color': AppColors.triageEmergency,
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'Patient Intake',
          'desc': 'Lookup & verify UHID',
          'icon': Icons.person_search_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/patients'),
        },
        {
          'title': 'Waiting Hall Queue',
          'desc': 'Monitor token progression',
          'icon': Icons.queue_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/queue'),
        },
      ];
    } else if (role == 'patient') {
      actions = [
        {
          'title': 'Patient Health Portal',
          'desc': 'Complete health records & dependents',
          'icon': Icons.health_and_safety_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/patient/portal'),
        },
        {
          'title': 'My Prescriptions',
          'desc': 'Clinician-approved instructions',
          'icon': Icons.medication_liquid_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/patient/portal'),
        },
        {
          'title': 'Laboratory Reports',
          'desc': 'Released diagnostic test findings',
          'icon': Icons.biotech_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/patient/portal'),
        },
        {
          'title': 'Itemized Bills & Receipts',
          'desc': 'Counter invoices & payment history',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.green.shade700,
          'onTap': () => context.push('/patient/portal'),
        },
        {
          'title': 'Live Queue Status',
          'desc': 'Track your token in real-time',
          'icon': Icons.radar_rounded,
          'color': AppColors.triagePriority,
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'Support & Inquiries',
          'desc': 'Submit requests & hospital helpdesk',
          'icon': Icons.contact_support_rounded,
          'color': Colors.indigo.shade600,
          'onTap': () => context.push('/patient/portal'),
        },
      ];
    } else if (role == 'admin') {
      actions = [
        {
          'title': 'Hospital Admin Portal',
          'desc': 'Operations, metrics & system governance',
          'icon': Icons.admin_panel_settings_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/admin/portal'),
        },
        {
          'title': 'Add & Manage Staff',
          'desc': 'Doctors, Lab, Reception & Pharmacy roster',
          'icon': Icons.person_add_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/admin/portal?tab=1'),
        },
        {
          'title': 'Operational & Billing Reports',
          'desc': 'De-identified CSV exports & statistics',
          'icon': Icons.analytics_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/admin/portal'),
        },
        {
          'title': 'Compliance Audit Explorer',
          'desc': 'Security event logs & sensitive changes',
          'icon': Icons.security_rounded,
          'color': Colors.amber.shade800,
          'onTap': () => context.push('/admin/portal'),
        },
        {
          'title': 'Catalogues & Formulary',
          'desc': 'Medication stock, tariffs & tests',
          'icon': Icons.inventory_rounded,
          'color': Colors.teal.shade700,
          'onTap': () => context.push('/admin/portal'),
        },
        {
          'title': 'Hospital Billing Counter',
          'desc': 'Invoices, tariffs & collections',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.green.shade700,
          'onTap': () => context.push('/billing'),
        },
      ];
    } else if (role == 'laboratory' || role == 'lab_tech') {
      actions = [
        {
          'title': 'Laboratory Orders',
          'desc': 'Review test requests',
          'icon': Icons.biotech_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/laboratory'),
        },
        {
          'title': 'Enter Test Results',
          'desc': 'CBC, Blood Sugar, Urine',
          'icon': Icons.edit_note_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/laboratory'),
        },
        {
          'title': 'Flag Abnormal Value',
          'desc': 'Critical panic alert to MD',
          'icon': Icons.warning_amber_rounded,
          'color': AppColors.triageEmergency,
          'onTap': () => context.push('/laboratory'),
        },
        {
          'title': 'Patient Directory',
          'desc': 'Lookup UHID history',
          'icon': Icons.folder_shared_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/patients'),
        },
      ];
    } else if (role == 'pharmacist') {
      actions = [
        {
          'title': 'Dispense Prescriptions',
          'desc': 'Active e-prescriptions queue',
          'icon': Icons.medication_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/pharmacy'),
        },
        {
          'title': 'Medication Inventory',
          'desc': 'Formulary & stock levels',
          'icon': Icons.inventory_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/pharmacy'),
        },
        {
          'title': 'Pharmacy Billing',
          'desc': 'Medicine invoice & receipts',
          'icon': Icons.receipt_long_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/billing'),
        },
        {
          'title': 'Patient Directory',
          'desc': 'Dosage and allergy check',
          'icon': Icons.folder_shared_rounded,
          'color': const Color(0xFF0284C7),
          'onTap': () => context.push('/patients'),
        },
      ];
    } else if (role == 'billing') {
      actions = [
        {
          'title': 'Billing Counter',
          'desc': 'Issue receipts & invoices',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.green.shade700,
          'onTap': () => context.push('/billing'),
        },
        {
          'title': 'Process Payments',
          'desc': 'Cash, UPI, Card checkout',
          'icon': Icons.point_of_sale_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/billing'),
        },
        {
          'title': 'Financial Reports',
          'desc': 'Daily collection audit',
          'icon': Icons.analytics_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/billing'),
        },
        {
          'title': 'Patient Directory',
          'desc': 'Lookup UHID past slips',
          'icon': Icons.folder_shared_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/patients'),
        },
      ];
    } else {
      // Receptionist
      actions = [
        {
          'title': 'Register Patient',
          'desc': 'Generate new UHID booklet',
          'icon': Icons.person_add_alt_1_rounded,
          'color': AppColors.primaryBlue,
          'onTap': () => context.push('/patients/new'),
        },
        {
          'title': 'Issue OPD Token',
          'desc': 'Book outpatient visit slip',
          'icon': Icons.confirmation_number_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/visits/new'),
        },
        {
          'title': 'OPD Billing Counter',
          'desc': 'Bills, receipts & payments',
          'icon': Icons.receipt_long_rounded,
          'color': Colors.green.shade700,
          'onTap': () => context.push('/billing'),
        },
        {
          'title': 'Patient Directory',
          'desc': 'Lookup by phone / UHID',
          'icon': Icons.search_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/patients'),
        },
        {
          'title': 'Waiting Hall Queue',
          'desc': 'Monitor token display',
          'icon': Icons.monitor_rounded,
          'color': const Color(0xFF0284C7),
          'onTap': () => context.push('/queue'),
        },
        {
          'title': 'Scan Document / QR',
          'desc': 'Capture booklets & barcodes',
          'icon': Icons.document_scanner,
          'color': Colors.indigo,
          'onTap': () => context.push('/documents'),
        },
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                action: actions[0],
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context: context,
                action: actions[1],
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                context: context,
                action: actions[2],
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionButton(
                context: context,
                action: actions[3],
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required Map<String, dynamic> action,
    required bool isDark,
  }) {
    final Color color = action['color'] as Color;
    return OpdCard(
      padding: const EdgeInsets.all(13),
      onTap: action['onTap'] as VoidCallback,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(action['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action['title'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  action['desc'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Role-Specific Main Workflow Section
  Widget _buildRoleMainContent({
    required BuildContext context,
    required String role,
    required AsyncValue<List<OPDVisitModel>> visitsAsync,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                role == 'patient'
                    ? 'Your Active Outpatient Token'
                    : 'Active OPD Patient Stream',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
            role == 'patient'
                ? TextButton.icon(
                    onPressed: () => context.push('/patient/portal'),
                    icon: const Icon(Icons.folder_shared_rounded, size: 16),
                    label: const Text('My Health Records'),
                  )
                : TextButton.icon(
                    onPressed: () => context.push('/queue'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View All Queue'),
                  ),
          ],
        ),
        const SizedBox(height: 8),

        visitsAsync.when(
          data: (allVisits) {
            final user = ref.read(authProvider).user;
            final visits = role == 'patient'
                ? allVisits.where((v) {
                    final uid = user?.id ?? '';
                    final uPhone = user?.phone ?? '';
                    final uName = user?.fullName.toLowerCase() ?? '';
                    final pat = v.patient;
                    if (v.patientId == uid) return true;
                    if (pat != null) {
                      if (pat.id == uid || pat.uhid.toLowerCase() == uid.toLowerCase()) return true;
                      if (uPhone.isNotEmpty && pat.phone == uPhone) return true;
                      if (uName.isNotEmpty && pat.fullName.toLowerCase().contains(uName)) return true;
                    }
                    return false;
                  }).toList()
                : allVisits;

            if (visits.isEmpty) {
              return OpdCard(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        role == 'patient' ? Icons.confirmation_number_outlined : Icons.check_circle_outline_rounded,
                        size: 40,
                        color: AppColors.accentTeal,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        role == 'patient' ? 'No Active Outpatient Token Today' : 'No Patients In Active Queue',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        role == 'patient'
                            ? 'Your past consultations and digital booklet are saved in the Patient Portal.'
                            : 'All tokens have been triaged or attended.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (role == 'patient') ...[
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                          icon: const Icon(Icons.folder_shared_rounded, size: 16),
                          label: const Text('Open Patient Health Records'),
                          onPressed: () => context.push('/patient/portal'),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visits.length > 4 ? 4 : visits.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final v = visits[index];
                return OpdCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => context.push('/visits/${v.id}'),
                  child: Row(
                    children: [
                      // Token Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'TOKEN',
                              style: TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            Text(
                              v.formattedToken,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                            Text(
                              'Seq #${v.queueToken}',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.patient?.fullName ?? 'Patient ${v.visitNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${v.patient?.uhid ?? "UHID Pending"} • ${v.departmentName}',
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TriageChip(priority: v.triagePriority, compact: true),
                          const SizedBox(height: 4),
                          StatusBadge(status: v.status),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => OpdCard(
            padding: const EdgeInsets.all(16),
            child: Text('Live queue update: $err'),
          ),
        ),
      ],
    );
  }

  void _showUserProfileSheet(
    BuildContext context,
    WidgetRef ref,
    AuthState authState,
    String currentRole,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = authState.user;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                    child: Icon(_getRoleIcon(currentRole), color: AppColors.primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.fullName.isNotEmpty == true ? user!.fullName : 'Hospital User',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          user?.email.isNotEmpty == true ? user!.email : (user?.phone ?? 'Active Session'),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      currentRole.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note_rounded, color: AppColors.primaryBlue),
                title: const Text('Edit Profile & Credentials', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Update full name, phone number, and password', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/profile-setup');
                },
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.settings_outlined, color: Colors.grey),
                title: const Text('System Preferences', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Appearance, notifications, security', style: TextStyle(fontSize: 11)),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/settings');
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.triageEmergency,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out of Hospital Session', style: TextStyle(fontWeight: FontWeight.w700)),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authProvider.notifier).logout();
                  if (context.mounted) {
                    context.goNamed(RouteNames.welcome);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'nurse':
        return Icons.monitor_heart_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      case 'patient':
        return Icons.person_rounded;
      case 'laboratory':
      case 'lab_tech':
        return Icons.biotech_rounded;
      case 'pharmacist':
        return Icons.medication_rounded;
      case 'billing':
        return Icons.receipt_long_rounded;
      case 'receptionist':
      default:
        return Icons.desk_rounded;
    }
  }

  String _getDefaultNameForRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Consulting Physician';
      case 'nurse':
        return 'OPD Triage Nurse';
      case 'admin':
        return 'Hospital Administrator';
      case 'patient':
        return 'Patient';
      case 'laboratory':
      case 'lab_tech':
        return 'Laboratory Specialist';
      case 'pharmacist':
        return 'Pharmacy Specialist';
      case 'billing':
        return 'Billing Cashier';
      case 'receptionist':
      default:
        return 'OPD Receptionist';
    }
  }

  void _showActiveClinicsDialog(BuildContext context) {
    final clinics = [
      {'name': 'General Medicine', 'code': 'MED', 'room': 'Rooms 101, 104', 'desc': 'Internal medicine, acute infections & chronic care', 'doctors': 'Dr. Sarah Chen, MD'},
      {'name': 'Cardiology', 'code': 'CARD', 'room': 'Room 102', 'desc': 'Cardiac evaluation, hypertension & ECG diagnostics', 'doctors': 'Dr. R. Venkatesh, DM'},
      {'name': 'Pediatrics', 'code': 'PED', 'room': 'Room 103', 'desc': 'Neonatal, infant care & pediatric immunizations', 'doctors': 'Dr. Ananya Roy, MD'},
      {'name': 'Orthopedics', 'code': 'ORTH', 'room': 'Room 104', 'desc': 'Bone trauma, fracture reduction & joint pain', 'doctors': 'Dr. Vikram Mehta, MS'},
      {'name': 'Dermatology', 'code': 'DERM', 'room': 'Room 105', 'desc': 'Clinical dermatology, allergies & skin treatments', 'doctors': 'Dr. Ananya Rao, MD'},
      {'name': 'Endocrinology', 'code': 'ENDO', 'room': 'Room 106', 'desc': 'Diabetes mellitus, thyroid & metabolic health', 'doctors': 'Dr. S. Kulkarni, DM'},
      {'name': 'Gastroenterology', 'code': 'GASTRO', 'room': 'Room 107', 'desc': 'Digestive disorders, liver clinic & endoscopy', 'doctors': 'Dr. Pradeep Menon, DM'},
      {'name': 'Pulmonology', 'code': 'PULM', 'room': 'Room 108', 'desc': 'Respiratory medicine, asthma & pulmonary function', 'doctors': 'Dr. Harish Patel, MD • Dr. Uday Kumar, MD'},
      {'name': 'Neurology', 'code': 'NEURO', 'room': 'Room 109', 'desc': 'Neuro-diagnostics, epilepsy & migraine management', 'doctors': 'Dr. Vikram Seth, DM'},
      {'name': 'Oncology', 'code': 'ONCO', 'room': 'Room 110', 'desc': 'Medical oncology, chemo planning & screening', 'doctors': 'Dr. Malini Iyer, MD DM'},
      {'name': 'Nephrology', 'code': 'NEPH', 'room': 'Room 111', 'desc': 'Kidney health, dialysis consults & hypertension', 'doctors': 'Dr. Gautam Das, DM'},
      {'name': 'Gynecology', 'code': 'GYN', 'room': 'Room 112', 'desc': "Women's wellness, prenatal checks & gynecology", 'doctors': 'Dr. Radhika Nair, MS DGO'},
      {'name': 'Dental / Maxillofacial', 'code': 'DENT', 'room': 'Room 113', 'desc': 'Oral surgery, root canals & maxillofacial consults', 'doctors': 'Dr. M. Arunraj, MDS'},
      {'name': 'ENT (Ear, Nose, Throat)', 'code': 'ENT', 'room': 'Room 114', 'desc': 'Otolaryngology, audiometry & sinus care', 'doctors': 'Dr. Kavita Nair, MS ENT'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.domain_rounded, color: Color(0xFF8B5CF6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Clinical Departments',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${clinics.length} Hospital Outpatient Clinics Operational',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: clinics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final c = clinics[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              c['code']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6), fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c['name']!,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('OPERATIONAL', style: TextStyle(color: Colors.green, fontSize: 9.5, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(c['desc']!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.meeting_room_outlined, size: 13, color: AppColors.primaryBlue),
                                    const SizedBox(width: 4),
                                    Text(c['room']!, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                                    const SizedBox(width: 12),
                                    const Icon(Icons.person_outline, size: 13, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        c['doctors']!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoctorRosterDialog(BuildContext context) {
    final docs = DoctorRepository.cachedDoctors.isNotEmpty
        ? DoctorRepository.cachedDoctors
        : DoctorRepository.defaultDoctors;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.statusCompleted.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.badge_outlined, color: AppColors.statusCompleted, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'On-Duty Medical Specialists Roster',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${docs.length} Clinical Physicians & Specialists Available Today',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, idx) {
                    final d = docs[idx];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.withOpacity(0.18)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primaryBlue.withOpacity(0.12),
                            child: const Icon(Icons.person_rounded, color: AppColors.primaryBlue, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.circle, color: Colors.green, size: 6),
                                          SizedBox(width: 4),
                                          Text(
                                            'ON DUTY',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${d.specialization} • ${d.qualification}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.meeting_room_rounded, size: 13, color: AppColors.primaryBlue),
                                    const SizedBox(width: 4),
                                    Text(d.roomNumber, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                                    const Spacer(),
                                    Text('Fee: ₹${d.consultationFee.toStringAsFixed(0)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.teal)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

