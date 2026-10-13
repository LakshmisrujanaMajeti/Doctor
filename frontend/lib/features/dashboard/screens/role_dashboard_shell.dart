import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/data/mock_presentation_data.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
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

class RoleDashboardShell extends ConsumerStatefulWidget {
  const RoleDashboardShell({super.key});

  @override
  ConsumerState<RoleDashboardShell> createState() => _RoleDashboardShellState();
}

class _RoleDashboardShellState extends ConsumerState<RoleDashboardShell> {
  int _currentTabIndex = 0;

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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Text(
                    AppStrings.tagline,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            // Quick Role Switcher Pill (One tap to test any role)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showRoleSwitcherSheet(context, ref, currentRole),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                      size: 14,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      currentRole.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.arrow_drop_down,
                      size: 16,
                      color: AppColors.primaryBlue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Notifications Icon with Badge
            IconButton(
              tooltip: 'Hospital Notifications',
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.notifications_outlined, size: 22),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 8,
                      height: 8,
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
              tooltip: 'Settings & Profile',
              icon: const Icon(Icons.settings_outlined, size: 22),
              onPressed: () => context.push('/settings'),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(visitListProvider);
            ref.invalidate(doctorDashboardProvider);
            ref.invalidate(labOrdersListProvider);
            ref.invalidate(labDashboardStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
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
                ] else ...[
                  // 2. Role-Aware KPI Metrics Grid
                  statsAsync.when(
                    data: (stats) => _buildRoleMetricsGrid(
                      context: context,
                      role: currentRole,
                      stats: stats,
                    ),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, stack) => const SizedBox(),
                  ),
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
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentTabIndex = idx);
            if (idx == 1) context.push('/queue');
            if (idx == 2) context.push('/patients');
            if (idx == 3) context.push('/notifications');
            if (idx == 4) context.push('/settings');
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_play_next_rounded),
              label: 'OPD Queue',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_alt_rounded),
              label: 'Patients',
            ),
            NavigationDestination(
              icon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
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
    };

    final roleGradients = {
      'doctor': [const Color(0xFF0F62FE), const Color(0xFF0043CE)],
      'receptionist': [const Color(0xFF007A6E), const Color(0xFF004D40)],
      'nurse': [const Color(0xFF0284C7), const Color(0xFF0369A1)],
      'admin': [const Color(0xFF334155), const Color(0xFF0F172A)],
      'patient': [const Color(0xFF0F62FE), const Color(0xFF00A896)],
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

  // Role-Aware KPI Metrics
  Widget _buildRoleMetricsGrid({
    required BuildContext context,
    required String role,
    required DashboardStatsModel stats,
  }) {
    switch (role) {
      case 'doctor':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Waiting for Me',
                    value: stats.waiting.toString(),
                    icon: Icons.hourglass_top_rounded,
                    color: AppColors.triagePriority,
                    subtitle: 'In Line',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'In Consultation',
                    value: stats.triaged.toString(),
                    icon: Icons.medical_services_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'Current Room',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Consulted Today',
                    value: stats.completed.toString(),
                    icon: Icons.task_alt_rounded,
                    color: AppColors.statusCompleted,
                    subtitle: 'Concluded',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Total OPD Today',
                    value: stats.totalVisits.toString(),
                    icon: Icons.people_alt_rounded,
                    color: AppColors.accentTeal,
                    subtitle: 'General Clinic',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'nurse':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Awaiting Triage',
                    value: stats.waiting.toString(),
                    icon: Icons.monitor_heart_rounded,
                    color: AppColors.triageEmergency,
                    subtitle: 'Pending Vitals',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Triaged & Ready',
                    value: stats.triaged.toString(),
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.accentTeal,
                    subtitle: 'To Doctor',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Total Visits',
                    value: stats.totalVisits.toString(),
                    icon: Icons.assignment_turned_in_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: "Today's Intake",
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Doctors Active',
                    value: stats.activeDoctors.toString(),
                    icon: Icons.medical_services_rounded,
                    color: const Color(0xFF8B5CF6),
                    subtitle: 'In Clinic Rooms',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'patient':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Your Token',
                    value: '#12',
                    icon: Icons.confirmation_number_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'General OPD',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Est. Wait Time',
                    value: '~18 min',
                    icon: Icons.timer_outlined,
                    color: AppColors.accentTeal,
                    subtitle: '3 Ahead of You',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Assigned Room',
                    value: 'Room 104',
                    icon: Icons.meeting_room_rounded,
                    color: const Color(0xFF8B5CF6),
                    subtitle: 'Dr. Sarah Chen',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Active Rx',
                    value: '2 Meds',
                    icon: Icons.medication_rounded,
                    color: AppColors.statusCompleted,
                    subtitle: 'Pharmacy Ready',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'admin':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Hospital OPD Total',
                    value: stats.totalPatients.toString(),
                    icon: Icons.groups_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'Active UHIDs',
                    onTap: () => context.push('/patients'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: "Today's Footfall",
                    value: stats.totalVisits.toString(),
                    icon: Icons.assessment_rounded,
                    color: AppColors.accentTeal,
                    subtitle: 'Visits Registered',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Active Clinics',
                    value: '${stats.departments} Depts',
                    icon: Icons.domain_rounded,
                    color: const Color(0xFF8B5CF6),
                    subtitle: 'Operational',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Doctor Roster',
                    value: '${stats.activeDoctors} On Duty',
                    icon: Icons.badge_outlined,
                    color: AppColors.statusCompleted,
                    subtitle: 'Consulting',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'laboratory':
      case 'lab_tech':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Pending Tests',
                    value: '14 Orders',
                    icon: Icons.biotech_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'Awaiting Run',
                    onTap: () => context.push('/notifications'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Abnormal Results',
                    value: '3 Flagged',
                    icon: Icons.warning_amber_rounded,
                    color: AppColors.triageEmergency,
                    subtitle: 'Critical Alert',
                    onTap: () => context.push('/notifications'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Completed Tests',
                    value: '48 Today',
                    icon: Icons.task_alt_rounded,
                    color: AppColors.statusCompleted,
                    subtitle: 'Verified & Sent',
                    onTap: () => context.push('/notifications'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Lab Turnaround',
                    value: '32 mins',
                    icon: Icons.timer_outlined,
                    color: AppColors.accentTeal,
                    subtitle: 'Average TAT',
                    onTap: () => context.push('/notifications'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'pharmacist':
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Rx Dispensing Queue',
                    value: '9 Active',
                    icon: Icons.medication_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'To Dispense',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Medicines Dispensed',
                    value: '72 Today',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.statusCompleted,
                    subtitle: 'Fulfilled',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Pending Payments',
                    value: '4 Orders',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.triagePriority,
                    subtitle: 'Counter Billing',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Low Stock Alert',
                    value: '2 Items',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.triageEmergency,
                    subtitle: 'Paracetamol 650',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );

      case 'receptionist':
      default:
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Total Patients',
                    value: stats.totalPatients.toString(),
                    icon: Icons.people_alt_rounded,
                    color: AppColors.primaryBlue,
                    subtitle: 'Registered UHIDs',
                    onTap: () => context.push('/patients'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: "Today's Tokens",
                    value: stats.totalVisits.toString(),
                    icon: Icons.confirmation_number_rounded,
                    color: AppColors.accentTeal,
                    subtitle: 'Issued Slips',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatMetricCard(
                    title: 'Waiting in Hall',
                    value: stats.waiting.toString(),
                    icon: Icons.airline_seat_recline_normal_rounded,
                    color: AppColors.triagePriority,
                    subtitle: 'Queue Active',
                    onTap: () => context.push('/queue'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatMetricCard(
                    title: 'Completed',
                    value: stats.completed.toString(),
                    icon: Icons.check_circle_rounded,
                    color: AppColors.statusCompleted,
                    subtitle: 'Visits Concluded',
                    onTap: () => context.push('/queue'),
                  ),
                ),
              ],
            ),
          ],
        );
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
          'title': 'Staff, Roles & Permissions',
          'desc': 'User activation, roles & provisioning',
          'icon': Icons.manage_accounts_rounded,
          'color': const Color(0xFF8B5CF6),
          'onTap': () => context.push('/admin/portal'),
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
          'onTap': () => context.push('/notifications'),
        },
        {
          'title': 'Enter Test Results',
          'desc': 'CBC, Blood Sugar, Urine',
          'icon': Icons.edit_note_rounded,
          'color': AppColors.accentTeal,
          'onTap': () => context.push('/notifications'),
        },
        {
          'title': 'Flag Abnormal Value',
          'desc': 'Critical panic alert to MD',
          'icon': Icons.warning_amber_rounded,
          'color': AppColors.triageEmergency,
          'onTap': () => context.push('/notifications'),
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
            Text(
              role == 'patient'
                  ? 'Your Active Outpatient Token'
                  : 'Active OPD Patient Stream',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            TextButton.icon(
              onPressed: () => context.push('/queue'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('View All Queue'),
            ),
          ],
        ),
        const SizedBox(height: 8),

        visitsAsync.when(
          data: (visits) {
            if (visits.isEmpty) {
              return OpdCard(
                padding: const EdgeInsets.all(28),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 40,
                        color: AppColors.accentTeal,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No Patients In Active Queue',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All tokens have been triaged or attended.',
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '#${v.queueToken}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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

  void _showRoleSwitcherSheet(
    BuildContext context,
    WidgetRef ref,
    String currentRole,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const Text(
                'Switch Clinical Role Perspective',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Select a hospital role to instantly experience tailored dashboards, queues, and workflows.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ...MockPresentationData.rolePresets.map((preset) {
                final isSelected = currentRole == preset.roleKey;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    tileColor: isSelected
                        ? AppColors.primaryBlue.withValues(alpha: 0.1)
                        : (isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC)),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryBlue
                            : (isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0)),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        preset.icon,
                        size: 20,
                        color: isSelected ? Colors.white : AppColors.primaryBlue,
                      ),
                    ),
                    title: Text(
                      preset.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.primaryBlue : null,
                      ),
                    ),
                    subtitle: Text(
                      preset.subtitle,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded,
                            color: AppColors.primaryBlue)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      _applySimulatedRole(ref, preset);
                    },
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _applySimulatedRole(WidgetRef ref, RolePreset preset) {
    final authNotifier = ref.read(authProvider.notifier);
    final current = ref.read(authProvider);

    final updated = UserModel(
      id: current.user?.id ?? 'simulated-user',
      email: preset.email,
      fullName: preset.subtitle.split('(').first.trim(),
      phone: current.user?.phone ?? '+1 (555) 019-2831',
      roleName: preset.roleKey,
    );

    authNotifier.setSimulatedUser(updated);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to ${preset.title}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
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
      case 'receptionist':
      default:
        return Icons.desk_rounded;
    }
  }

  String _getDefaultNameForRole(String role) {
    switch (role) {
      case 'doctor':
        return 'Dr. Sarah Chen, MD';
      case 'nurse':
        return 'Nurse Station (East Wing)';
      case 'admin':
        return 'Hospital Admin Console';
      case 'patient':
        return 'Johnathan Reynolds';
      case 'laboratory':
      case 'lab_tech':
        return 'Marcus Vance (Lab Tech)';
      case 'pharmacist':
        return 'Elena Rostova (Pharmacist)';
      case 'receptionist':
      default:
        return 'Receptionist Desk (OPD)';
    }
  }
}
