import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/stat_metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../auth/providers/auth_provider.dart';
import '../../visits/providers/visit_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final visitsAsync = ref.watch(visitListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;
    final userName = user?.fullName ?? 'Staff Member';
    final userRole = (user?.roleName ?? 'receptionist').toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SmvmchHospitalLogo(size: 30),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SMVMCH OPD Connect',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'Hospital Outpatient System • Puducherry',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings & Status',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardStatsProvider);
          ref.invalidate(visitListProvider);
        },
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.horizontalPadding(context),
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting Banner
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [AppColors.primaryTeal, const Color(0xFF00695C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryTeal.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: const Icon(Icons.medical_services_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Welcome, $userName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  userRole,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Active OPD Session • Token queues and clinical records live',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // KPI Stats Grid
              statsAsync.when(
                data: (stats) {
                  final isTablet = context.isTablet || context.isDesktop;
                  final cards = [
                    StatMetricCard(
                      title: 'Total Patients',
                      value: stats.totalPatients.toString(),
                      icon: Icons.people_alt_rounded,
                      color: AppColors.primaryTeal,
                      subtitle: 'All UHIDs',
                      onTap: () => context.push('/patients'),
                    ),
                    StatMetricCard(
                      title: "Today's Visits",
                      value: stats.totalVisits.toString(),
                      icon: Icons.assignment_turned_in_rounded,
                      color: AppColors.secondaryNavy,
                      subtitle: 'Active Queue',
                      onTap: () => context.push('/queue'),
                    ),
                    StatMetricCard(
                      title: 'Waiting Triage',
                      value: stats.waiting.toString(),
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.triagePriority,
                      subtitle: 'In Line',
                      onTap: () => context.push('/queue'),
                    ),
                    StatMetricCard(
                      title: 'Consulted',
                      value: stats.completed.toString(),
                      icon: Icons.check_circle_rounded,
                      color: AppColors.triageNormal,
                      subtitle: 'Concluded',
                      onTap: () => context.push('/queue'),
                    ),
                  ];

                  if (isTablet) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[1]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[2]),
                        const SizedBox(width: 12),
                        Expanded(child: cards[3]),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[1]),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 12),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const SizedBox(),
              ),
              const SizedBox(height: 24),

              // Quick Action Cards
              const Text(
                'Hospital Quick Actions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      context: context,
                      title: 'Register Patient',
                      desc: 'Generate new UHID',
                      icon: Icons.person_add_alt_1_rounded,
                      color: AppColors.primaryTeal,
                      onTap: () => context.push('/patients/new'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      context: context,
                      title: 'Book OPD Visit',
                      desc: 'Issue queue token',
                      icon: Icons.confirmation_number_rounded,
                      color: AppColors.secondaryNavy,
                      onTap: () => context.push('/visits/new'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      context: context,
                      title: 'Live OPD Queue',
                      desc: 'Triage & vital signs',
                      icon: Icons.queue_play_next_rounded,
                      color: const Color(0xFF8B5CF6),
                      onTap: () => context.push('/queue'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _actionButton(
                      context: context,
                      title: 'Patient Directory',
                      desc: 'Lookup by UHID',
                      icon: Icons.badge_outlined,
                      color: const Color(0xFF0284C7),
                      onTap: () => context.push('/patients'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Recent OPD Visits Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent OPD Queue Visits',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/queue'),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('View All Queue'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Recent Visits List
              visitsAsync.when(
                data: (visits) {
                  if (visits.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('No OPD visits booked yet today.'),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visits.length > 5 ? 5 : visits.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final v = visits[index];
                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/visits/${v.id}'),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                // Token Number Badge
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTeal.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '#${v.queueToken}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                      color: AppColors.primaryTeal,
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
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${v.patient?.uhid ?? "UHID Pending"} • ${v.departmentName}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
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
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading visits: $err'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (idx) {
            if (idx == 1) context.push('/queue');
            if (idx == 2) context.push('/patients');
            if (idx == 3) context.push('/settings');
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
            NavigationDestination(icon: Icon(Icons.queue_rounded), label: 'Queue'),
            NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Patients'),
            NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required BuildContext context,
    required String title,
    required String desc,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
