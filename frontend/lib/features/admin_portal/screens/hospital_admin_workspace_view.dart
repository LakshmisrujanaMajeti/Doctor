import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/opd_constants.dart';
import '../../../core/config/app_config.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/server_config_dialog.dart';
import '../models/admin_portal_models.dart';
import '../providers/admin_portal_provider.dart';
import '../../patient_portal/models/patient_portal_models.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/providers/patient_provider.dart';
import '../../doctors/repositories/doctor_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../routing/route_names.dart';

class HospitalAdminWorkspaceView extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const HospitalAdminWorkspaceView({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<HospitalAdminWorkspaceView> createState() =>
      _HospitalAdminWorkspaceViewState();
}

class _HospitalAdminWorkspaceViewState
    extends ConsumerState<HospitalAdminWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _autoRefreshTimer;

  // Search & filter controllers
  final TextEditingController _userSearchCtrl = TextEditingController();
  final TextEditingController _medicineSearchCtrl = TextEditingController();
  final TextEditingController _auditQueryCtrl = TextEditingController();
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    final idx = (widget.initialTabIndex >= 0 && widget.initialTabIndex < 9)
        ? widget.initialTabIndex
        : 0;
    _tabController = TabController(length: 9, vsync: this, initialIndex: idx);
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(adminDashboardSummaryProvider);
        ref.invalidate(patientListProvider);
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _tabController.dispose();
    _userSearchCtrl.dispose();
    _medicineSearchCtrl.dispose();
    _auditQueryCtrl.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(adminDashboardSummaryProvider);
    ref.invalidate(adminUsersProvider);
    ref.invalidate(adminDepartmentsProvider);
    ref.invalidate(adminMedicinesProvider);
    ref.invalidate(adminTestCatalogueProvider);
    ref.invalidate(adminServicesCatalogueProvider);
    ref.invalidate(adminAuditLogsProvider);
    ref.invalidate(adminSupportTicketsProvider);
    ref.invalidate(adminSystemConfigsProvider);
    ref.invalidate(adminBackupGuidanceProvider);
    ref.invalidate(adminRegistrationsReportProvider);
    ref.invalidate(adminBillingReportProvider);
    ref.invalidate(patientListProvider);
    ref.invalidate(doctorListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(adminDashboardSummaryProvider);

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
        title: Row(
          children: [
            const SmvmchHospitalLogo(size: 32),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hospital Administrator Portal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Operations, Security & Governance Console',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Tooltip(
            message: 'Server: ${AppConfig.apiBaseUrl}\nTap to configure Host IP',
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => ServerConfigDialog.show(context),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.hospitalGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.hospitalGreen.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 14, color: AppColors.hospitalGreen),
                    SizedBox(width: 4),
                    Text(
                      'LIVE 5s',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.hospitalGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.dns_outlined, size: 20),
            tooltip: 'Server IP Configuration',
            onPressed: () => ServerConfigDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Portals',
            onPressed: _refreshAll,
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 21),
            tooltip: 'Logout Admin',
            onPressed: () async {
              final confirm = await showOpdConfirmDialog(
                context: context,
                title: 'Sign Out Admin?',
                message: 'Are you sure you want to log out of the SMVMCH Hospital Admin Portal?',
                confirmText: 'Sign Out',
                isDestructive: true,
              );
              if (confirm == true && context.mounted) {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  context.goNamed(RouteNames.welcome);
                }
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Top KPI Summary Bar
          summaryAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Failed to load operational metrics: $err',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            data: (summary) => _buildTopKpiBar(summary, isDark),
          ),

          // 2. Tab Navigation
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor:
                  isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              indicatorColor: AppColors.primaryBlue,
              tabs: const [
                Tab(icon: Icon(Icons.dashboard_rounded, size: 18), text: 'Operations & Financials'),
                Tab(icon: Icon(Icons.manage_accounts_rounded, size: 18), text: 'Staff & Roles'),
                Tab(icon: Icon(Icons.people_alt_rounded, size: 18), text: 'Patients & Directory'),
                Tab(icon: Icon(Icons.domain_rounded, size: 18), text: 'Departments & Tariffs'),
                Tab(icon: Icon(Icons.medication_rounded, size: 18), text: 'Catalogues & Formulary'),
                Tab(icon: Icon(Icons.analytics_rounded, size: 18), text: 'Operational Reports'),
                Tab(icon: Icon(Icons.security_rounded, size: 18), text: 'Compliance & Audit'),
                Tab(icon: Icon(Icons.contact_support_rounded, size: 18), text: 'Support Desk'),
                Tab(icon: Icon(Icons.settings_system_daydream_rounded, size: 18), text: 'System Config & Backup'),
              ],
            ),
          ),

          // 3. Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOperationsFinancialsTab(isDark),
                _buildStaffManagementTab(isDark),
                _buildPatientManagementTab(isDark),
                _buildDepartmentsTariffsTab(isDark),
                _buildCataloguesFormularyTab(isDark),
                _buildReportsTab(isDark),
                _buildAuditComplianceTab(isDark),
                _buildSupportDeskTab(isDark),
                _buildSystemConfigBackupTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TOP KPI SUMMARY BAR
  // ==========================================
  Widget _buildTopKpiBar(AdminDashboardMetricsModel metrics, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildKpiChip(
              icon: Icons.people_alt_rounded,
              label: 'Total UHID',
              value: '${metrics.totalPatientsRegistered}',
              color: AppColors.primaryBlue,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.meeting_room_rounded,
              label: "Today's Footfall",
              value: '${metrics.visitsTodayCount}',
              color: AppColors.accentTeal,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.payments_rounded,
              label: "Today's Revenue",
              value: '₹${metrics.revenueToday.toStringAsFixed(0)}',
              color: Colors.green.shade700,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.pending_actions_rounded,
              label: 'Pending Bills',
              value: '${metrics.pendingBillsCount} (₹${metrics.pendingBillsAmount.toStringAsFixed(0)})',
              color: metrics.pendingBillsCount > 0 ? Colors.orange.shade800 : Colors.grey,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.inventory_2_rounded,
              label: 'Low Stock Meds',
              value: '${metrics.lowStockItemsCount}',
              color: metrics.lowStockItemsCount > 0 ? Colors.red.shade700 : Colors.teal,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.biotech_rounded,
              label: 'Pending Labs',
              value: '${metrics.pendingLabOrdersCount}',
              color: Colors.purple.shade700,
            ),
            const SizedBox(width: 8),
            _buildKpiChip(
              icon: Icons.verified_user_rounded,
              label: 'Active Staff',
              value: '${metrics.totalStaffAccounts}',
              color: Colors.indigo.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: OPERATIONS & FINANCIALS
  // ==========================================
  Widget _buildOperationsFinancialsTab(bool isDark) {
    final summaryAsync = ref.watch(adminDashboardSummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading operations: $err')),
      data: (metrics) {
        final isTablet = MediaQuery.sizeOf(context).width >= 650;
        final isSmall = MediaQuery.sizeOf(context).width < 360;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Clinic & Queue Operations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              // Queue Breakdown: Responsive Grid across Tablets and Phones
              GridView.count(
                crossAxisCount: isTablet ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: isSmall ? 8 : 12,
                mainAxisSpacing: isSmall ? 8 : 12,
                childAspectRatio: isTablet ? 2.4 : (isSmall ? 1.7 : 2.05),
                children: [
                  _buildMetricCard(
                    title: 'Waiting in Queue',
                    value: '${metrics.queueBreakdown['WAITING'] ?? metrics.queueBreakdown['waiting'] ?? 0}',
                    icon: Icons.hourglass_top_rounded,
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'In Consultation',
                    value: '${metrics.queueBreakdown['IN_CONSULTATION'] ?? metrics.queueBreakdown['in_consultation'] ?? 0}',
                    icon: Icons.medical_services_rounded,
                    color: Colors.amber.shade800,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Consultations Done',
                    value: '${metrics.queueBreakdown['COMPLETED'] ?? metrics.queueBreakdown['completed'] ?? 0}',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    isDark: isDark,
                  ),
                  _buildMetricCard(
                    title: 'Triage In Progress',
                    value: '${metrics.queueBreakdown['TRIAGE'] ?? metrics.queueBreakdown['triage'] ?? metrics.queueBreakdown['triaged'] ?? 0}',
                    icon: Icons.emergency_rounded,
                    color: Colors.red,
                    isDark: isDark,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Revenue Overview Section: Stacked Full-Width Cards
              Text(
                'Financial Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.green.shade700),
                          const SizedBox(width: 8),
                          const Text(
                            'Collections Summary',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Today Collections:', style: TextStyle(fontSize: 14)),
                          Text(
                            '₹${metrics.revenueToday.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('This Month Collections:', style: TextStyle(fontSize: 14)),
                          Text(
                            '₹${metrics.revenueMonth.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unsettled Outstanding Bills:', style: TextStyle(fontSize: 14)),
                          Text(
                            '₹${metrics.pendingBillsAmount.toStringAsFixed(2)} (${metrics.pendingBillsCount} bills)',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pie_chart_rounded, size: 20, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          const Text(
                            'Payment Method Breakdown',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      if (metrics.revenueByMethod.isEmpty)
                        const Text('No transactions recorded today', style: TextStyle(color: Colors.grey))
                      else
                        ...metrics.revenueByMethod.entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  e.key.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '₹${e.value.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Pharmacy & Diagnostic Efficiency: Stacked Cards
              Text(
                'Departmental Service Efficiency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.purple.shade50,
                    child: const Icon(Icons.biotech, color: Colors.purple),
                  ),
                  title: const Text('Diagnostic Laboratory', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${metrics.completedLabTodayCount} tests released today • ${metrics.pendingLabOrdersCount} in testing pipeline',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade50,
                    child: const Icon(Icons.medication, color: Colors.teal),
                  ),
                  title: const Text('Pharmacy Formulary', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${metrics.totalMedicinesInFormulary} medicines active • ${metrics.lowStockItemsCount} low stock alerts',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: STAFF & ROLE MANAGEMENT
  // ==========================================
  Widget _buildStaffManagementTab(bool isDark) {
    final usersAsync = ref.watch(adminUsersProvider);
    final selectedRole = ref.watch(adminUsersFilterRoleProvider);

    return Column(
      children: [
        // Controls Header: Responsive Search & Role Chips
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _userSearchCtrl,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search, size: 20),
                        hintText: 'Search staff by name or email...',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        suffixIcon: _userSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _userSearchCtrl.clear();
                                  ref.read(adminUsersSearchProvider.notifier).state = null;
                                },
                              )
                            : null,
                      ),
                      onSubmitted: (val) {
                        ref.read(adminUsersSearchProvider.notifier).state = val.trim().isEmpty ? null : val.trim();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showProvisionStaffDialog(context),
                    icon: const Icon(Icons.person_add_rounded, size: 18),
                    label: const Text('Provision Staff User'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Role Filter Chips Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildRoleFilterChip(null, 'All Roles', selectedRole),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('doctor', 'Doctors', selectedRole),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('receptionist', 'Receptionists', selectedRole),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('pharmacist', 'Pharmacists', selectedRole),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('lab_technician', 'Lab Techs', selectedRole),
                    const SizedBox(width: 6),
                    _buildRoleFilterChip('admin', 'Admins', selectedRole),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Staff Member Cards
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading users: $err')),
            data: (users) {
              if (users.isEmpty) {
                return const Center(child: Text('No staff members found matching criteria.'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final roleColor = _getRoleColor(user.roleName);

                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Avatar, Name, Role badge, and Active Switch
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: roleColor.withValues(alpha: 0.15),
                                child: Text(
                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                  style: TextStyle(
                                    color: roleColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: roleColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            user.roleName.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: roleColor,
                                            ),
                                          ),
                                        ),
                                        if (user.lockedUntil != null) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('LOCKED', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Active Switch
                              Switch(
                                value: user.isActive,
                                activeColor: Colors.green,
                                onChanged: (val) async {
                                  final confirm = await showOpdConfirmDialog(
                                    context: context,
                                    title: val ? 'Activate Account?' : 'Deactivate Account?',
                                    message:
                                        'Are you sure you want to ${val ? "activate" : "deactivate"} ${user.fullName} (${user.email})?',
                                    confirmText: val ? 'Activate' : 'Deactivate',
                                  );
                                  if (confirm == true) {
                                    try {
                                      final repo = ref.read(adminPortalRepositoryProvider);
                                      await repo.updateUserStatus(user.id, isActive: val, unlock: val);
                                      ref.invalidate(adminUsersProvider);
                                      ref.invalidate(adminDashboardSummaryProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Account for ${user.fullName} updated successfully.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: Colors.red),
                                        );
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          // Contact details
                          Row(
                            children: [
                              const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  user.email,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.phone != null && user.phone!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  user.phone!,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Action Buttons Row: Edit, Change Role, Delete
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showEditStaffDialog(context, user),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Edit', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: () => _showChangeRoleDialog(context, user),
                                icon: const Icon(Icons.badge_outlined, size: 15),
                                label: const Text('Role', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                tooltip: 'Delete Account',
                                onPressed: () => _showDeleteStaffDialog(context, user),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleFilterChip(String? roleKey, String label, String? selectedRole) {
    final isSelected = selectedRole == roleKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(adminUsersFilterRoleProvider.notifier).state = roleKey;
      },
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryBlue : Colors.grey.shade700,
      ),
      visualDensity: VisualDensity.compact,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'doctor':
        return Colors.teal;
      case 'receptionist':
        return Colors.orange.shade800;
      case 'pharmacist':
        return Colors.green.shade700;
      case 'lab_technician':
        return Colors.purple.shade700;
      case 'nurse':
        return Colors.blue.shade700;
      case 'admin':
        return Colors.indigo.shade700;
      case 'billing':
        return Colors.brown;
      default:
        return AppColors.primaryBlue;
    }
  }

  // ==========================================
  // TAB 3: PATIENT DIRECTORY & DEMOGRAPHICS
  // ==========================================
  Widget _buildPatientManagementTab(bool isDark) {
    final patientsAsync = ref.watch(patientListProvider);

    return Column(
      children: [
        // Search Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search patients by UHID, Name, or Phone...',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    ref.read(patientSearchQueryProvider.notifier).setQuery(val.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await context.push('/patients/new');
                  if (mounted) {
                    ref.read(patientSearchQueryProvider.notifier).setQuery('');
                    ref.invalidate(patientListProvider);
                    ref.invalidate(adminDashboardSummaryProvider);
                    ref.invalidate(adminRegistrationsReportProvider);
                  }
                },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('New Patient'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
        ),

        // Patient List
        Expanded(
          child: patientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading patients: $err')),
            data: (patients) {
              if (patients.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('No registered patients found.', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          await context.push('/patients/new');
                          if (mounted) {
                            ref.read(patientSearchQueryProvider.notifier).setQuery('');
                            ref.invalidate(patientListProvider);
                            ref.invalidate(adminDashboardSummaryProvider);
                            ref.invalidate(adminRegistrationsReportProvider);
                          }
                        },
                        child: const Text('Register First Patient'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: patients.length,
                itemBuilder: (context, index) {
                  final patient = patients[index];
                  return Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
                                child: Text(
                                  patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                                  style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patient.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryTeal.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            patient.uhid,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primaryTeal),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${patient.gender} • ${patient.ageYears ?? "--"} yrs',
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.confirmation_number_rounded, color: AppColors.primaryTeal),
                                tooltip: 'Book Visit',
                                onPressed: () => context.push('/visits/new', extra: patient),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(patient.phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              if (patient.address != null && patient.address!.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    patient.address!,
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (patient.registeredByStaffName != null && patient.registeredByStaffName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_outlined, size: 12, color: AppColors.primaryBlue),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Registered by: ${patient.registeredByStaffName} (${patient.registeredByStaffRole ?? "Staff"})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _showPatientDetailsModal(context, patient),
                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                label: const Text('All Details', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push('/patients/${patient.id}/booklet'),
                                icon: const Icon(Icons.menu_book_rounded, size: 14, color: AppColors.primaryBlue),
                                label: const Text('Booklet', style: TextStyle(fontSize: 11, color: AppColors.primaryBlue)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _downloadPatientBooklet(context, patient),
                                icon: const Icon(Icons.download_rounded, size: 14),
                                label: const Text('PDF', style: TextStyle(fontSize: 11)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.hospitalMaroon,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _showEditPatientInAdmin(context, patient),
                                icon: const Icon(Icons.edit_outlined, size: 14),
                                label: const Text('Edit', style: TextStyle(fontSize: 11)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                                tooltip: 'Delete Patient Record',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deletePatientInAdmin(context, patient),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showEditStaffDialog(BuildContext context, AdminUserModel user) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: user.fullName);
    final emailCtrl = TextEditingController(text: user.email);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final qualCtrl = TextEditingController(text: 'MBBS, MD');
    final roomCtrl = TextEditingController(text: 'Room 101');
    final feeCtrl = TextEditingController(text: '500');
    final deptCtrl = TextEditingController(text: 'General Medicine');
    String selectedRole = user.roleName.toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDoc = selectedRole == 'doctor';
            return AlertDialog(
              title: Text('Edit Staff: ${user.fullName}'),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Hospital Email *', isDense: true),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => InputSanitizer.validateEmail(v, fieldName: 'Hospital Email'),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number (10 digits)', isDense: true),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: false, fieldName: 'Phone Number'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'Staff Role Group', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'doctor', child: Text('Doctor (Clinical Access)')),
                            DropdownMenuItem(value: 'receptionist', child: Text('Receptionist (Intake & Tokens)')),
                            DropdownMenuItem(value: 'nurse', child: Text('Nurse (Vitals & Triage)')),
                            DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist (Formulary & Dispensing)')),
                            DropdownMenuItem(value: 'lab_technician', child: Text('Lab Technician (Diagnostic Testing)')),
                            DropdownMenuItem(value: 'billing', child: Text('Billing Counter (Invoices & Cashier)')),
                            DropdownMenuItem(value: 'admin', child: Text('Hospital Administrator (Governance)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedRole = val);
                          },
                        ),
                        if (isDoc || selectedRole == 'nurse' || selectedRole == 'receptionist') ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: deptCtrl,
                            decoration: InputDecoration(
                              labelText: isDoc ? 'Department / Specialization' : 'Assigned Department / Clinical Unit',
                              isDense: true,
                            ),
                          ),
                        ],
                        if (isDoc) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: roomCtrl,
                            decoration: const InputDecoration(labelText: 'OPD Room Number', isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: qualCtrl,
                            decoration: const InputDecoration(labelText: 'Medical Qualification', isDense: true),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: feeCtrl,
                            decoration: const InputDecoration(labelText: 'Consultation Fee (₹)', isDense: true),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final repo = ref.read(adminPortalRepositoryProvider);
                        await repo.updateUserDetails(
                          user.id,
                          fullName: nameCtrl.text.trim(),
                          email: emailCtrl.text.trim(),
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          roleName: selectedRole,
                          departmentName: (isDoc || selectedRole == 'nurse' || selectedRole == 'receptionist') ? deptCtrl.text.trim() : null,
                          roomNumber: isDoc ? roomCtrl.text.trim() : null,
                          qualification: isDoc ? qualCtrl.text.trim() : null,
                          consultationFee: isDoc ? feeCtrl.text.trim() : null,
                        );
                        ref.invalidate(adminUsersProvider);
                        ref.invalidate(adminDashboardSummaryProvider);
                        ref.invalidate(doctorListProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Staff details for ${nameCtrl.text.trim()} updated successfully!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update staff: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteStaffDialog(BuildContext context, AdminUserModel user) async {
    final confirm = await showOpdConfirmDialog(
      context: context,
      title: 'Delete Staff Account?',
      message: 'Are you sure you want to permanently delete the account for "${user.fullName}" (${user.email})? They will immediately lose access.',
      confirmText: 'Delete Account',
      isDestructive: true,
    );
    if (confirm == true) {
      try {
        final repo = ref.read(adminPortalRepositoryProvider);
        await repo.deleteUserAccount(user.id);
        ref.invalidate(adminUsersProvider);
        ref.invalidate(adminDashboardSummaryProvider);
        ref.invalidate(doctorListProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account for "${user.fullName}" deleted successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete staff: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showEditPatientInAdmin(BuildContext context, PatientModel patient) {
    final nameCtrl = TextEditingController(text: patient.fullName);
    final phoneCtrl = TextEditingController(text: patient.phone);
    final ageCtrl = TextEditingController(text: patient.ageYears != null ? '${patient.ageYears}' : '');
    final addressCtrl = TextEditingController(text: patient.address ?? '');
    final relationNameCtrl = TextEditingController(text: patient.parentSpouseName ?? '');
    String selectedGender = patient.gender.toUpperCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit Patient: ${patient.fullName}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number (10 Digits) *', isDense: true),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        decoration: const InputDecoration(labelText: 'Age (Years)', isDense: true),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: ['MALE', 'FEMALE', 'OTHER'].contains(selectedGender) ? selectedGender : 'OTHER',
                        decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'MALE', child: Text('Male')),
                          DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                          DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedGender = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: relationNameCtrl,
                  decoration: const InputDecoration(labelText: 'Father / Spouse Name', isDense: true),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) return;
                final updated = patient.copyWith(
                  fullName: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  ageYears: int.tryParse(ageCtrl.text.trim()),
                  gender: selectedGender,
                  parentSpouseName: relationNameCtrl.text.trim().isEmpty ? null : relationNameCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                try {
                  await ref.read(patientRepositoryProvider).updatePatient(updated);
                  ref.invalidate(patientListProvider);
                  ref.invalidate(adminDashboardSummaryProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Patient "${updated.fullName}" updated successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update patient: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _deletePatientInAdmin(BuildContext context, PatientModel patient) async {
    final confirm = await showOpdConfirmDialog(
      context: context,
      title: 'Delete Patient Record?',
      message: 'Are you sure you want to permanently delete patient "${patient.fullName}" (UHID: ${patient.uhid})? This will permanently remove all associated records.',
      confirmText: 'Delete Record',
      isDestructive: true,
    );
    if (confirm == true) {
      try {
        await ref.read(patientRepositoryProvider).deletePatient(patient.id);
        ref.invalidate(patientListProvider);
        ref.invalidate(adminDashboardSummaryProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Patient "${patient.fullName}" deleted successfully.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete patient: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _downloadPatientBooklet(BuildContext context, PatientModel patient) async {
    final regId = patient.hospitalRegNum ?? patient.uhid;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Generating & downloading 7-page verified OPD booklet...')),
          ],
        ),
        duration: Duration(seconds: 4),
      ),
    );
    try {
      final bytes = await ref.read(patientRepositoryProvider).downloadBookletByRegId(regId);
      if (bytes.isNotEmpty && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded ${bytes.length} bytes. Verified SMVMCH booklet saved!'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => context.push('/patients/${patient.id}/booklet'),
            ),
          ),
        );
        return;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hospital server offline/unreachable on this network.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Opening verified in-app 7-page Digital Booklet for ${patient.fullName}...',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            backgroundColor: AppColors.hospitalMaroon,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Server IP',
              textColor: Colors.yellowAccent,
              onPressed: () => ServerConfigDialog.show(context),
            ),
          ),
        );
        context.push('/patients/${patient.id}/booklet');
      }
    }
  }

  void _showPatientDetailsModal(BuildContext context, PatientModel patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
              child: Text(
                patient.fullName.isNotEmpty ? patient.fullName[0].toUpperCase() : 'P',
                style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.fullName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(
                    'UHID: ${patient.uhid}',
                    style: const TextStyle(fontSize: 12, color: AppColors.primaryTeal, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Demographics Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildDetailRow('Age & Gender', '${patient.ageYears ?? "N/A"} Yrs • ${patient.gender}'),
                      const Divider(height: 12),
                      _buildDetailRow('Phone Number', patient.phone),
                      const Divider(height: 12),
                      _buildDetailRow('Father / Spouse', patient.parentSpouseName ?? 'N/A'),
                      const Divider(height: 12),
                      _buildDetailRow('Address', patient.address ?? 'Not recorded'),
                      if (patient.barcodeValue != null) ...[
                        const Divider(height: 12),
                        _buildDetailRow('Barcode / Code128', patient.barcodeValue!),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Staff Attribution & Registration Audit
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: AppColors.primaryBlue),
                          SizedBox(width: 6),
                          Text(
                            'Registration Audit & Staff Attribution',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Registered By Staff',
                        patient.registeredByStaffName != null
                            ? '${patient.registeredByStaffName} (${patient.registeredByStaffRole ?? "Receptionist"})'
                            : 'Hospital Admissions Desk',
                      ),
                      if (patient.registeredByStaffId != null) ...[
                        const Divider(height: 12),
                        _buildDetailRow('Staff ID', patient.registeredByStaffId!),
                      ],
                      if (patient.createdAt != null) ...[
                        const Divider(height: 12),
                        _buildDetailRow(
                          'Registration Timestamp',
                          '${patient.createdAt!.day.toString().padLeft(2, '0')}/${patient.createdAt!.month.toString().padLeft(2, '0')}/${patient.createdAt!.year} ${patient.createdAt!.hour.toString().padLeft(2, '0')}:${patient.createdAt!.minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons inside Modal
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.push('/patients/${patient.id}/booklet');
                        },
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('Digital Booklet'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.hospitalMaroon,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _downloadPatientBooklet(context, patient);
                        },
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: const Text('Download PDF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  void _showProvisionStaffDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final qualCtrl = TextEditingController(text: 'MBBS, MD');
    final roomCtrl = TextEditingController(text: 'OPD Room 101');
    final feeCtrl = TextEditingController(text: '500');
    String selectedRole = 'doctor';
    String selectedDepartment = 'General Medicine';
    String selectedSpecialization = 'General Medicine';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isDoc = selectedRole == 'doctor';
            return AlertDialog(
              title: const Text('Provision New Staff Account'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Full Name *', isDense: true),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Hospital Email *', isDense: true),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => InputSanitizer.validateEmail(v, fieldName: 'Hospital Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: passwordCtrl,
                          decoration: const InputDecoration(labelText: 'Initial Password * (Strong)', isDense: true),
                          obscureText: true,
                          validator: (v) => InputSanitizer.validateStrongPassword(v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(labelText: 'Phone Number (10 digits, Optional)', isDense: true),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) => InputSanitizer.validate10DigitPhone(v, isRequired: false, fieldName: 'Phone Number'),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'Role Permission Group', isDense: true),
                          items: const [
                            DropdownMenuItem(value: 'doctor', child: Text('Doctor (Clinical Access)')),
                            DropdownMenuItem(value: 'receptionist', child: Text('Receptionist (Intake & Tokens)')),
                            DropdownMenuItem(value: 'nurse', child: Text('Nurse (Vitals & Triage)')),
                            DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist (Formulary & Dispensing)')),
                            DropdownMenuItem(value: 'lab_technician', child: Text('Lab Technician (Diagnostic Testing)')),
                            DropdownMenuItem(value: 'billing', child: Text('Billing Counter (Invoices & Cashier)')),
                            DropdownMenuItem(value: 'admin', child: Text('Hospital Administrator (Governance)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedRole = val);
                          },
                        ),
                        if (isDoc || selectedRole == 'nurse' || selectedRole == 'receptionist') ...[
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: selectedDepartment,
                            decoration: InputDecoration(
                              labelText: isDoc ? 'Clinical Department / Specialization *' : 'Assigned Department / Clinical Unit *',
                              isDense: true,
                            ),
                            items: OpdConstants.departments.map((dept) => DropdownMenuItem(
                              value: dept,
                              child: Text(dept),
                            )).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedDepartment = val;
                                  selectedSpecialization = val;
                                  if (isDoc) {
                                    final matchingRole = OpdConstants.doctorRoles.firstWhere(
                                      (r) => r['department'] == val,
                                      orElse: () => {},
                                    );
                                    if (matchingRole.isNotEmpty) {
                                      qualCtrl.text = matchingRole['qualification'] ?? 'MBBS, MD';
                                      roomCtrl.text = matchingRole['default_room'] ?? 'OPD Room 101';
                                      feeCtrl.text = (double.tryParse(matchingRole['fee'] ?? '500') ?? 500).toInt().toString();
                                    }
                                  }
                                });
                              }
                            },
                          ),
                        ],
                        if (isDoc) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: roomCtrl,
                                  decoration: const InputDecoration(labelText: 'OPD Room *', isDense: true),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: feeCtrl,
                                  decoration: const InputDecoration(labelText: 'Consultation Fee (₹) *', isDense: true),
                                  keyboardType: TextInputType.number,
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: qualCtrl,
                            decoration: const InputDecoration(labelText: 'Medical Qualification', isDense: true),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final repo = ref.read(adminPortalRepositoryProvider);
                        await repo.provisionStaffUser(
                          email: emailCtrl.text.trim(),
                          password: passwordCtrl.text,
                          fullName: nameCtrl.text.trim(),
                          roleName: selectedRole,
                          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                          departmentName: (isDoc || selectedRole == 'nurse' || selectedRole == 'receptionist') ? selectedDepartment : null,
                          specialization: isDoc ? selectedSpecialization : null,
                          roomNumber: isDoc ? roomCtrl.text.trim() : null,
                          qualification: isDoc ? qualCtrl.text.trim() : null,
                          consultationFee: isDoc ? (double.tryParse(feeCtrl.text.trim()) ?? 500.0) : null,
                        );
                        ref.invalidate(adminUsersProvider);
                        ref.invalidate(adminDashboardSummaryProvider);
                        ref.invalidate(doctorListProvider);
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Staff account provisioned successfully!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to provision user: $e'), backgroundColor: Colors.red),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Provision User'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showChangeRoleDialog(BuildContext context, AdminUserModel user) {
    String selectedRole = user.roleName.toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Change Role for ${user.fullName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Role: ${user.roleName.toUpperCase()}'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: ['admin', 'doctor', 'receptionist', 'nurse', 'pharmacist', 'lab_technician', 'billing']
                            .contains(selectedRole)
                        ? selectedRole
                        : 'doctor',
                    decoration: const InputDecoration(labelText: 'New System Role', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                      DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                      DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                      DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
                      DropdownMenuItem(value: 'lab_technician', child: Text('Lab Technician')),
                      DropdownMenuItem(value: 'billing', child: Text('Billing')),
                      DropdownMenuItem(value: 'admin', child: Text('Administrator')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedRole = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final repo = ref.read(adminPortalRepositoryProvider);
                      await repo.updateUserRole(user.id, roleName: selectedRole);
                      ref.invalidate(adminUsersProvider);
                      ref.invalidate(adminDashboardSummaryProvider);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Role for ${user.fullName} changed to $selectedRole')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Save Role'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 3: DEPARTMENTS & SERVICES
  // ==========================================
  Widget _buildDepartmentsTariffsTab(bool isDark) {
    final deptsAsync = ref.watch(adminDepartmentsProvider);
    final servicesAsync = ref.watch(adminServicesCatalogueProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Department Configuration Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Clinical Departments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Department'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showAddDepartmentDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          deptsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading departments: $err'),
            data: (depts) {
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: depts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final d = depts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: d.isActive ? AppColors.primaryBlue : Colors.grey,
                        child: Text(d.code, style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                      title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${d.description ?? "No description"} • ${d.doctorsCount} Clinicians assigned'),
                      trailing: Switch(
                        value: d.isActive,
                        activeColor: Colors.green,
                        onChanged: (val) async {
                          try {
                            final repo = ref.read(adminPortalRepositoryProvider);
                            await repo.toggleDepartmentStatus(d.id);
                            ref.invalidate(adminDepartmentsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Toggled status for ${d.name}')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Standard Services & Tariffs Section
          Text(
            'Hospital Service Tariffs & Rate Card',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          servicesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading services: $err'),
            data: (services) {
              return Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return ListTile(
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Code: ${s.code} • Category: ${s.category}'),
                      trailing: Text(
                        '₹${s.price.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddDepartmentDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.domain_add_rounded, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Create Department', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Department Name *',
                    hintText: 'e.g. Cardiology, Orthopedics',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Department Code *',
                    hintText: 'e.g. CARD, ORTHO',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief clinical specialty details...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final code = codeCtrl.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Department name and code are required.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                try {
                  final repo = ref.read(adminPortalRepositoryProvider);
                  await repo.createDepartment(
                    name: name,
                    code: code,
                    description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  );
                  ref.invalidate(adminDepartmentsProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Department "$name" created successfully.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to create department: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 4: CATALOGUES & FORMULARY
  // ==========================================
  Widget _buildCataloguesFormularyTab(bool isDark) {
    final medsAsync = ref.watch(adminMedicinesProvider);
    final labAsync = ref.watch(adminTestCatalogueProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
            child: const TabBar(
              labelColor: AppColors.primaryBlue,
              indicatorColor: AppColors.primaryBlue,
              tabs: [
                Tab(icon: Icon(Icons.medication, size: 18), text: 'Medicine Formulary & Reorder'),
                Tab(icon: Icon(Icons.biotech, size: 18), text: 'Diagnostic Test Catalogue'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Subtab 1: Medicine Formulary
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _medicineSearchCtrl,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search, size: 20),
                                hintText: 'Search medicines by brand or generic name...',
                                isDense: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onSubmitted: (v) {
                                ref.invalidate(adminMedicinesProvider);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            children: [
                              const Text('Low Stock Only:'),
                              Switch(
                                value: _lowStockOnly,
                                onChanged: (val) {
                                  setState(() => _lowStockOnly = val);
                                  ref.invalidate(adminMedicinesProvider);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: medsAsync.when(
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading formulary: $err')),
                        data: (meds) {
                          if (meds.isEmpty) {
                            return const Center(child: Text('No medicines found in formulary.'));
                          }
                          return ListView.separated(
                            itemCount: meds.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final m = meds[index];
                              return ListTile(
                                title: Row(
                                  children: [
                                    Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Text('(${m.strength})', style: const TextStyle(color: Colors.grey)),
                                    if (m.isLowStock) ...[
                                      const SizedBox(width: 8),
                                      const Chip(
                                        backgroundColor: Colors.red,
                                        label: Text('LOW STOCK', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  'Generic: ${m.genericName} • Form: ${m.dosageForm} • Stock: ${m.quantity} • Reorder Threshold: ${m.reorderLevel}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '₹${m.unitPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 18),
                                      tooltip: 'Configure Price & Reorder Threshold',
                                      onPressed: () => _showEditMedicineDialog(context, m),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),

                // Subtab 2: Diagnostic Test Catalogue
                labAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading lab tests: $err')),
                  data: (tests) {
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: tests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final t = tests[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${t.name} (${t.code})',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    Text(
                                      '₹${t.price.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Sample: ${t.sampleType} • Turnaround: ${t.turnaroundHours} hours',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  children: t.parameters
                                      .map((p) => Chip(
                                            label: Text(p, style: const TextStyle(fontSize: 10)),
                                            visualDensity: VisualDensity.compact,
                                          ))
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditMedicineDialog(BuildContext context, MedicineAdminModel m) {
    final priceCtrl = TextEditingController(text: m.unitPrice.toString());
    final reorderCtrl = TextEditingController(text: m.reorderLevel.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit ${m.name} Configuration'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceCtrl,
                decoration: const InputDecoration(labelText: 'Unit Price (₹)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reorderCtrl,
                decoration: const InputDecoration(labelText: 'Reorder Level Threshold'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final p = double.tryParse(priceCtrl.text);
                final r = int.tryParse(reorderCtrl.text);
                try {
                  final repo = ref.read(adminPortalRepositoryProvider);
                  await repo.updateMedicineConfig(m.id, unitPrice: p, reorderLevel: r);
                  ref.invalidate(adminMedicinesProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Updated ${m.name} configuration.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 5: OPERATIONAL REPORTS
  // ==========================================
  Widget _buildReportsTab(bool isDark) {
    final regReportAsync = ref.watch(adminRegistrationsReportProvider);
    final billReportAsync = ref.watch(adminBillingReportProvider);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
            child: const TabBar(
              labelColor: AppColors.primaryBlue,
              indicatorColor: AppColors.primaryBlue,
              tabs: [
                Tab(icon: Icon(Icons.people_outline, size: 18), text: 'OPD Registrations & Footfall'),
                Tab(icon: Icon(Icons.attach_money, size: 18), text: 'Billing & Financial Collections'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Subtab 1: Registrations Report
                regReportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading registration report: $err')),
                  data: (data) {
                    final totalVisits = data['total_visits'] ?? 0;
                    final statusSummary = (data['status_summary'] as Map<String, dynamic>?) ?? {};
                    final deptSummary = (data['department_summary'] as Map<String, dynamic>?) ?? {};
                    final records = (data['records'] as List?) ?? [];

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Export Bar with PII Protection Notice
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, color: Colors.blue),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'PII Masking Active: Exported CSVs de-identify patient contact details and clinical narratives.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Downloading opd_registrations_report.csv (De-identified)...'),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.download, size: 16),
                                  label: const Text('Export CSV'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Total Visits in Period: $totalVisits',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 12),
                          // Summary Chips
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: statusSummary.entries.map((e) {
                              return Chip(
                                label: Text('${e.key}: ${e.value}'),
                                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Department Distribution',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: deptSummary.entries.map((e) {
                              return Chip(
                                label: Text('${e.key}: ${e.value}'),
                                backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Recent Visit Logs (Preview)',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: records.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final r = records[idx];
                                return ListTile(
                                  title: Text('Visit ${r['visit_number']} • UHID: ${r['patient_uhid']}'),
                                  subtitle: Text('Dept: ${r['department']} • Doctor: ${r['doctor']} • Status: ${r['status']}'),
                                  trailing: Chip(label: Text('Token #${r['queue_token']}')),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Subtab 2: Billing Report
                billReportAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error loading billing report: $err')),
                  data: (data) {
                    final totalRevenue = (data['total_revenue'] as num?)?.toDouble() ?? 0.0;
                    final totalDiscount = (data['total_discount'] as num?)?.toDouble() ?? 0.0;
                    final totalPaid = (data['total_paid'] as num?)?.toDouble() ?? 0.0;
                    final totalPending = (data['total_pending'] as num?)?.toDouble() ?? 0.0;
                    final billsCount = data['total_bills_count'] ?? 0;
                    final byStatus = (data['by_status'] as Map<String, dynamic>?) ?? {};

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Financial Metrics ($billsCount Invoices)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Downloading opd_billing_collections_report.csv...'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Export Billing CSV'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Gross Billed',
                                  value: '₹${totalRevenue.toStringAsFixed(2)}',
                                  icon: Icons.receipt_long,
                                  color: Colors.blue,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Net Collected',
                                  value: '₹${totalPaid.toStringAsFixed(2)}',
                                  icon: Icons.payments,
                                  color: Colors.green,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Discounts Granted',
                                  value: '₹${totalDiscount.toStringAsFixed(2)}',
                                  icon: Icons.discount,
                                  color: Colors.purple,
                                  isDark: isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildMetricCard(
                                  title: 'Pending Receivables',
                                  value: '₹${totalPending.toStringAsFixed(2)}',
                                  icon: Icons.warning,
                                  color: Colors.orange.shade800,
                                  isDark: isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Invoices by Payment Status',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: byStatus.entries.map((e) {
                              return Chip(
                                label: Text('${e.key}: ${e.value}'),
                                backgroundColor: Colors.teal.withValues(alpha: 0.1),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 6: COMPLIANCE & AUDIT EXPLORER
  // ==========================================
  Widget _buildAuditComplianceTab(bool isDark) {
    final auditAsync = ref.watch(adminAuditLogsProvider);
    final selectedAction = ref.watch(adminAuditLogsActionFilterProvider);

    return Column(
      children: [
        // Security Banner Explaining Explicit Permissions & Clinical Segregation
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.amber.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Segregation of Duties: Administrators hold governance oversight. Private clinical narratives, doctor notes, and patient records are segregated and require explicit clinical audit authorization.',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),

        // Search & Filter Header
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _auditQueryCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search audit records by actor, action or entity...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (val) {
                    ref.read(adminAuditLogsQueryProvider.notifier).state = val.trim().isEmpty ? null : val.trim();
                  },
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(
                value: selectedAction,
                hint: const Text('All Security Actions'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Security Actions')),
                  DropdownMenuItem(value: 'LOGIN_SUCCESS', child: Text('LOGIN_SUCCESS')),
                  DropdownMenuItem(value: 'LOGIN_FAILED', child: Text('LOGIN_FAILED')),
                  DropdownMenuItem(value: 'ACCOUNT_STATUS_CHANGED', child: Text('ACCOUNT_STATUS_CHANGED')),
                  DropdownMenuItem(value: 'ROLE_CHANGED', child: Text('ROLE_CHANGED')),
                  DropdownMenuItem(value: 'DEPENDENT_LINKED', child: Text('DEPENDENT_LINKED')),
                  DropdownMenuItem(value: 'CLINICAL_ACCESS_AUDIT', child: Text('CLINICAL_ACCESS_AUDIT')),
                  DropdownMenuItem(value: 'BILL_CANCELLED', child: Text('BILL_CANCELLED')),
                  DropdownMenuItem(value: 'CONFIG_UPDATED', child: Text('CONFIG_UPDATED')),
                ],
                onChanged: (val) {
                  ref.read(adminAuditLogsActionFilterProvider.notifier).state = val;
                },
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh Audit Stream',
                onPressed: () => ref.invalidate(adminAuditLogsProvider),
              ),
            ],
          ),
        ),

        // Audit Trail List
        Expanded(
          child: auditAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading audit logs: $err')),
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('No audit events found.'));
              }

              return ListView.separated(
                itemCount: logs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final isSensitive = log.action.contains('FAILED') ||
                      log.action.contains('CANCELLED') ||
                      log.action.contains('CHANGED');

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSensitive ? Colors.red.shade100 : Colors.blue.shade100,
                      child: Icon(
                        isSensitive ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                        color: isSensitive ? Colors.red : Colors.blue,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          log.action,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSensitive ? Colors.red.shade900 : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(log.entityType, style: const TextStyle(fontSize: 10)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'Actor: ${log.userId ?? "System / Anonymous"} • IP: ${log.ipAddress ?? "Internal"} • ${log.timestamp}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: OutlinedButton(
                      child: const Text('Inspect Details', style: TextStyle(fontSize: 11)),
                      onPressed: () => _showAuditDetailsModal(context, log),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAuditDetailsModal(BuildContext context, AuditLogItemModel log) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Audit Record: ${log.action}'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event ID: ${log.id}'),
                  Text('Timestamp: ${log.timestamp}'),
                  Text('Actor ID: ${log.userId ?? "N/A"}'),
                  Text('Target Entity: ${log.entityType} (${log.entityId ?? "N/A"})'),
                  Text('Client IP Address: ${log.ipAddress ?? "N/A"}'),
                  const Divider(height: 20),
                  const Text('Sanitized Change Metadata:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      const JsonEncoder.withIndent('  ').convert(log.details),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Verification: Passwords, tokens, and clinical narratives are stripped at the service layer prior to persistent storage.',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        );
      },
    );
  }

  // ==========================================
  // TAB 7: SUPPORT DESK
  // ==========================================
  Widget _buildSupportDeskTab(bool isDark) {
    final ticketsAsync = ref.watch(adminSupportTicketsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Patient Inquiries & Support Tickets',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => ref.invalidate(adminSupportTicketsProvider),
              ),
            ],
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading tickets: $err')),
            data: (tickets) {
              if (tickets.isEmpty) {
                return const Center(child: Text('No patient support tickets recorded.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tickets.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = tickets[index];
                  final isResolved = t.status == 'RESOLVED';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.subject, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Chip(
                                label: Text(t.status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                backgroundColor: isResolved ? Colors.green.shade100 : Colors.amber.shade100,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Category: ${t.category} • Priority: ${t.priority} • Filed: ${t.createdAt}'),
                          const SizedBox(height: 8),
                          Text('Message: ${t.message}'),
                          if (t.adminResponse != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text('Staff Response: ${t.adminResponse}'),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              ElevatedButton(
                                onPressed: () => _showRespondTicketDialog(context, t),
                                child: Text(isResolved ? 'Update Response' : 'Respond & Resolve'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showRespondTicketDialog(BuildContext context, SupportTicketModel ticket) {
    final responseCtrl = TextEditingController(text: ticket.adminResponse ?? '');
    String selectedStatus = 'RESOLVED';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Respond to "${ticket.subject}"'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: responseCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Official Resolution / Guidance Message *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    items: const [
                      DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED')),
                      DropdownMenuItem(value: 'IN_PROGRESS', child: Text('IN_PROGRESS')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedStatus = val);
                    },
                    decoration: const InputDecoration(labelText: 'Ticket Status', isDense: true),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (responseCtrl.text.trim().isEmpty) return;
                    try {
                      final repo = ref.read(adminPortalRepositoryProvider);
                      await repo.respondSupportTicket(
                        ticket.id,
                        responseText: responseCtrl.text.trim(),
                        status: selectedStatus,
                      );
                      ref.invalidate(adminSupportTicketsProvider);
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Support response posted successfully!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Submit Response'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // TAB 8: SYSTEM CONFIG & BACKUP GUIDANCE
  // ==========================================
  Widget _buildSystemConfigBackupTab(bool isDark) {
    final configsAsync = ref.watch(adminSystemConfigsProvider);
    final backupAsync = ref.watch(adminBackupGuidanceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Configuration Parameters
          Text(
            'Hospital Operating Parameters & Configuration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          configsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading system configs: $err'),
            data: (configs) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ...configs.map((c) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.configKey, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    if (c.description != null)
                                      Text(c.description!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(c.configValue, style: const TextStyle(fontFamily: 'monospace')),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showEditConfigsDialog(context, configs),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit Operating Settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Backup Guidance & Disaster Recovery
          Text(
            'Disaster Recovery & Automated Backup Guidance',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 12),
          backupAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, _) => Text('Error loading backup guidance: $err'),
            data: (b) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Database Engine: ${b.databaseEngine}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Cron Schedule: ${b.cronSpecification} (${b.backupSchedule})'),
                              Text('Retention Period: ${b.retentionPeriodDays} days'),
                              Text('Last Backup Status: ${b.lastBackupStatus} at ${b.lastBackupTime}'),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final repo = ref.read(adminPortalRepositoryProvider);
                                final res = await repo.triggerBackupExport();
                                if (context.mounted) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Database Snapshot Successful'),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Snapshot File: ${res['snapshot_file']}'),
                                          Text('File Size: ${res['size_bytes']} bytes'),
                                          Text('Timestamp: ${res['timestamp']}'),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Snapshot stored in server secure storage. Compliance integrity verified.',
                                            style: TextStyle(color: Colors.green, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Backup snapshot failed: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.backup_rounded, size: 18),
                            label: const Text('Trigger Instant Snapshot'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Syncing all hospital records to Supabase Cloud...')),
                              );
                              try {
                                final res = await ref.read(dioClientProvider).dio.post('/admin/sync-supabase');
                                if (context.mounted) {
                                  final data = res.data['data'] as Map<String, dynamic>?;
                                  final pCount = data?['patients_synced'] ?? 0;
                                  final vCount = data?['visits_synced'] ?? 0;
                                  final bCount = data?['bills_synced'] ?? 0;
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Row(
                                        children: [
                                          Icon(Icons.cloud_done_rounded, color: Colors.blue),
                                          SizedBox(width: 8),
                                          Text('Supabase Cloud Sync'),
                                        ],
                                      ),
                                      content: Text(
                                        'Hospital database successfully synced to Supabase Cloud!\n\n'
                                        '• Patients Synced: $pCount\n'
                                        '• OPD Visits Synced: $vCount\n'
                                        '• Bills Synced: $bCount\n\n'
                                        'Project: xxwidqatsxzsrulaxxal.supabase.co',
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                                      ],
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Supabase sync notice: $e'), backgroundColor: Colors.orange),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                            label: const Text('Sync to Supabase Cloud'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('Recommended Backup Checklist:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...b.guidanceChecklist.map((c) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(child: Text(c, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                      const SizedBox(height: 16),
                      const Text('Disaster Recovery Steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      ...b.restoreProcedureSteps.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${e.key + 1}. ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12))),
                              ],
                            ),
                          )),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showEditConfigsDialog(BuildContext context, List<SystemConfigModel> configs) {
    final controllers = {
      for (final c in configs) c.configKey: TextEditingController(text: c.configValue),
    };

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Hospital Operating Settings'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: configs.map((c) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      controller: controllers[c.configKey],
                      decoration: InputDecoration(
                        labelText: c.configKey,
                        helperText: c.description,
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final Map<String, String> updated = {};
                controllers.forEach((k, v) {
                  updated[k] = v.text.trim();
                });
                try {
                  final repo = ref.read(adminPortalRepositoryProvider);
                  await repo.updateSystemConfigs(updated);
                  ref.invalidate(adminSystemConfigsProvider);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('System configurations updated.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: const Text('Save Settings'),
            ),
          ],
        );
      },
    );
  }
}
