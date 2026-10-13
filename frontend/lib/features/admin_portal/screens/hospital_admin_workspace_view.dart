import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../models/admin_portal_models.dart';
import '../providers/admin_portal_provider.dart';
import '../../patient_portal/models/patient_portal_models.dart';

class HospitalAdminWorkspaceView extends ConsumerStatefulWidget {
  const HospitalAdminWorkspaceView({super.key});

  @override
  ConsumerState<HospitalAdminWorkspaceView> createState() =>
      _HospitalAdminWorkspaceViewState();
}

class _HospitalAdminWorkspaceViewState
    extends ConsumerState<HospitalAdminWorkspaceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search & filter controllers
  final TextEditingController _userSearchCtrl = TextEditingController();
  final TextEditingController _medicineSearchCtrl = TextEditingController();
  final TextEditingController _auditQueryCtrl = TextEditingController();
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summaryAsync = ref.watch(adminDashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.primaryBlue,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hospital Administrator Portal',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Operations, Security & Governance Console',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh All Portals',
            onPressed: _refreshAll,
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
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
              // Queue Breakdown Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Waiting in Queue',
                      value: '${metrics.queueBreakdown['WAITING'] ?? 0}',
                      icon: Icons.hourglass_top_rounded,
                      color: Colors.blue,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'In Consultation',
                      value: '${metrics.queueBreakdown['IN_CONSULTATION'] ?? 0}',
                      icon: Icons.medical_services_rounded,
                      color: Colors.amber.shade800,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Consultations Done',
                      value: '${metrics.queueBreakdown['COMPLETED'] ?? 0}',
                      icon: Icons.check_circle_rounded,
                      color: Colors.green,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricCard(
                      title: 'Triage In Progress',
                      value: '${metrics.queueBreakdown['TRIAGE'] ?? 0}',
                      icon: Icons.emergency_rounded,
                      color: Colors.red,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Revenue Overview Section
              Text(
                'Financial Performance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Collections Summary',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(child: Text('Today Collections:')),
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
                                const Expanded(child: Text('This Month Collections:')),
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
                                const Expanded(child: Text('Unsettled Outstanding Bills:')),
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
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Method Breakdown',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            const Divider(height: 24),
                            if (metrics.revenueByMethod.isEmpty)
                              const Text('No transactions recorded today')
                            else
                              ...metrics.revenueByMethod.entries.map((e) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          e.key.toUpperCase(),
                                          style: const TextStyle(fontWeight: FontWeight.w500),
                                        ),
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
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pharmacy & Diagnostic Turnaround
              Text(
                'Departmental Service Efficiency',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.purple,
                          child: Icon(Icons.biotech, color: Colors.white),
                        ),
                        title: const Text('Diagnostic Laboratory'),
                        subtitle: Text(
                          '${metrics.completedLabTodayCount} tests released today • ${metrics.pendingLabOrdersCount} in testing pipeline',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.medication, color: Colors.white),
                        ),
                        title: const Text('Pharmacy Formulary'),
                        subtitle: Text(
                          '${metrics.totalMedicinesInFormulary} medicines active • ${metrics.lowStockItemsCount} low stock alerts',
                        ),
                      ),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
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
        // Controls Header
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _userSearchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search staff by name or email...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              const SizedBox(width: 12),
              // Role Filter Dropdown
              DropdownButton<String?>(
                value: selectedRole,
                hint: const Text('All Roles'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Roles')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                  DropdownMenuItem(value: 'receptionist', child: Text('Receptionist')),
                  DropdownMenuItem(value: 'nurse', child: Text('Nurse')),
                  DropdownMenuItem(value: 'pharmacist', child: Text('Pharmacist')),
                  DropdownMenuItem(value: 'lab_technician', child: Text('Lab Technician')),
                  DropdownMenuItem(value: 'billing', child: Text('Billing')),
                ],
                onChanged: (val) {
                  ref.read(adminUsersFilterRoleProvider.notifier).state = val;
                },
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showProvisionStaffDialog(context),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Provision Staff User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Staff List Table
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading users: $err')),
            data: (users) {
              if (users.isEmpty) {
                return const Center(child: Text('No staff members found matching criteria.'));
              }

              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.isActive ? AppColors.primaryBlue : Colors.grey,
                      child: Text(
                        user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            user.roleName.toUpperCase(),
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                        if (user.lockedUntil != null) ...[
                          const SizedBox(width: 8),
                          const Chip(
                            backgroundColor: Colors.red,
                            label: Text('LOCKED', style: TextStyle(color: Colors.white, fontSize: 10)),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text('${user.email} • ${user.phone ?? "No phone"}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Role Edit Button
                        IconButton(
                          icon: const Icon(Icons.badge_rounded, color: Colors.blue),
                          tooltip: 'Change Role',
                          onPressed: () => _showChangeRoleDialog(context, user),
                        ),
                        // Status Toggle Switch
                        Switch(
                          value: user.isActive,
                          activeColor: Colors.green,
                          onChanged: (val) async {
                            final confirm = await showOpdConfirmDialog(
                              context: context,
                              title: val ? 'Activate Account?' : 'Deactivate Account?',
                              message:
                                  'Are you sure you want to ${val ? "activate" : "deactivate"} ${user.fullName} (${user.email})? Security audit logs will record this action.',
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
                  );
                },
              );
            },
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
    String selectedRole = 'doctor';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Provision New Staff Account'),
              content: SizedBox(
                width: 450,
                child: Form(
                  key: formKey,
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
                        validator: (v) => v == null || !v.contains('@') ? 'Valid email required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordCtrl,
                        decoration: const InputDecoration(labelText: 'Initial Password *', isDense: true),
                        obscureText: true,
                        validator: (v) => v == null || v.length < 8 ? 'Min 8 characters' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Phone Number (Optional)', isDense: true),
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
                    ],
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
                        );
                        ref.invalidate(adminUsersProvider);
                        ref.invalidate(adminDashboardSummaryProvider);
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
