import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../models/doctor_dashboard_model.dart';
import '../providers/doctor_dashboard_provider.dart';
import '../../visits/models/visit_model.dart';

class DoctorDashboardView extends ConsumerStatefulWidget {
  const DoctorDashboardView({super.key});

  @override
  ConsumerState<DoctorDashboardView> createState() => _DoctorDashboardViewState();
}

class _DoctorDashboardViewState extends ConsumerState<DoctorDashboardView> with SingleTickerProviderStateMixin {
  late TabController _queueTabController;

  @override
  void initState() {
    super.initState();
    _queueTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _queueTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(doctorDashboardProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return dashboardAsync.when(
      data: (data) => _buildDashboardContent(context, data, isDark),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              Text('Unable to load doctor dashboard: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(doctorDashboardProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, DoctorDashboardModel data, bool isDark) {
    final hasScrollableAncestor = Scrollable.maybeOf(context) != null;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. KPI Metrics Grid (6 Critical Doctor Metrics)
        _buildMetricsGrid(context, data.stats, isDark),
        const SizedBox(height: 24),

        // 2. Active Clinical Queue Hub (Waiting, In Consultation, Completed)
        _buildClinicalQueueCard(context, data, isDark),
        const SizedBox(height: 24),

        // 3. Pending Laboratory Investigations
        _buildPendingInvestigationsCard(context, data.pendingInvestigations, isDark),
        const SizedBox(height: 24),

        // 4. Follow-up Appointments
        _buildFollowUpsCard(context, data.followUpAppointments, isDark),
        const SizedBox(height: 24),

        // 5. Recent Authorized Patient Records
        _buildRecentAuthorizedPatientsCard(context, data.recentAuthorizedPatients, isDark),
      ],
    );

    if (hasScrollableAncestor) {
      return content;
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      child: content,
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DoctorDashboardStatsModel stats, bool isDark) {
    final isTablet = context.isTablet || context.isDesktop;

    final cards = [
      _MetricCard(
        title: "Today's Appointments",
        value: '${stats.todayAppointments}',
        icon: Icons.calendar_today_rounded,
        color: AppColors.primaryBlue,
        subtitle: 'Scheduled Visits',
      ),
      _MetricCard(
        title: 'Waiting Patients',
        value: '${stats.waitingPatients}',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFFF59E0B),
        subtitle: 'Ready in Queue',
      ),
      _MetricCard(
        title: 'In Consultation',
        value: '${stats.underConsultation}',
        icon: Icons.medical_services_rounded,
        color: const Color(0xFF3B82F6),
        subtitle: 'Active Chamber',
      ),
      _MetricCard(
        title: 'Completed',
        value: '${stats.completedConsultations}',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF10B981),
        subtitle: 'Concluded Today',
      ),
      _MetricCard(
        title: 'Pending Labs',
        value: '${stats.pendingInvestigations}',
        icon: Icons.biotech_rounded,
        color: const Color(0xFF8B5CF6),
        subtitle: 'Awaiting Results',
      ),
      _MetricCard(
        title: 'Follow-ups',
        value: '${stats.followUpAppointments}',
        icon: Icons.event_repeat_rounded,
        color: AppColors.primaryTeal,
        subtitle: 'Upcoming Reviews',
      ),
    ];

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 12),
              Expanded(child: cards[1]),
              const SizedBox(width: 12),
              Expanded(child: cards[2]),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: cards[3]),
              const SizedBox(width: 12),
              Expanded(child: cards[4]),
              const SizedBox(width: 12),
              Expanded(child: cards[5]),
            ],
          ),
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[4]),
            const SizedBox(width: 12),
            Expanded(child: cards[5]),
          ],
        ),
      ],
    );
  }

  Widget _buildClinicalQueueCard(BuildContext context, DoctorDashboardModel data, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.people_alt_rounded, color: AppColors.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Doctor Patient Queue',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                TextButton.icon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Full Queue'),
                  onPressed: () => context.push('/queue'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _queueTabController,
              labelColor: AppColors.primaryBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppColors.primaryBlue,
              tabs: [
                Tab(text: 'Waiting (${data.waitingPatients.length})'),
                Tab(text: 'Under Care (${data.underConsultation.length})'),
                Tab(text: 'Completed (${data.completedConsultations.length})'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _queueTabController,
                children: [
                  _buildQueueList(data.waitingPatients, isActionStart: true),
                  _buildQueueList(data.underConsultation, isActionResume: true),
                  _buildQueueList(data.completedConsultations, isActionView: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueList(List<OPDVisitModel> visits, {bool isActionStart = false, bool isActionResume = false, bool isActionView = false}) {
    if (visits.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.grey[400], size: 40),
            const SizedBox(height: 8),
            Text('No patients in this queue', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: visits.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final v = visits[i];
        final patName = v.patient?.fullName ?? 'Patient';
        final uhid = v.patient?.uhid ?? 'UHID';
        final ageSex = v.patient != null ? '${v.patient!.ageYears ?? ""}Y • ${v.patient!.gender}' : '';

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
            child: Text(
              '#${v.queueToken}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue, fontSize: 13),
            ),
          ),
          title: Text(patName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text('$uhid • $ageSex', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          trailing: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActionStart
                  ? AppColors.primaryBlue
                  : (isActionResume ? const Color(0xFF3B82F6) : Colors.grey[200]),
              foregroundColor: isActionView ? Colors.black87 : Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              context.push('/visits/${v.id}/consultation', extra: v);
            },
            child: Text(
              isActionStart ? 'Start' : (isActionResume ? 'Resume' : 'View Sheet'),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingInvestigationsCard(BuildContext context, List<PendingInvestigationModel> labs, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.biotech_rounded, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Pending Investigations',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${labs.length} Orders',
                    style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (labs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('No pending investigation orders', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: labs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final lab = labs[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF3E8FF),
                      child: Icon(Icons.science_rounded, color: Color(0xFF8B5CF6), size: 18),
                    ),
                    title: Text(lab.testName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${lab.patientName} (${lab.uhid}) • Indication: ${lab.clinicalIndication ?? "Standard"}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        lab.status,
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowUpsCard(BuildContext context, List<FollowUpAppointmentModel> followUps, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.event_repeat_rounded, color: AppColors.primaryTeal, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Follow-up Appointments',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  '${followUps.length} Scheduled',
                  style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (followUps.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('No follow-up appointments scheduled', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: followUps.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final fu = followUps[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: AppColors.primaryTeal, size: 18),
                    ),
                    title: Text(fu.patientName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Due: ${fu.followUpDate} • Dx: ${fu.finalDiagnosis ?? "Follow-up"}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
                    onTap: () {
                      context.push('/visits/${fu.visitId}/consultation');
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentAuthorizedPatientsCard(BuildContext context, List<RecentAuthorizedPatientModel> patients, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Recent Authorized Patients',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => context.push('/patients'),
                  child: const Text('Search All'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (patients.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text('No recent patients found', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: patients.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final p = patients[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEEF2FF),
                      child: Text(
                        p.fullName.isNotEmpty ? p.fullName[0] : 'P',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ),
                    title: Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('${p.uhid} • ${p.ageDisplay} • ${p.gender} • Last: ${p.lastDiagnosis ?? "OPD Consultation"}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    onTap: () {
                      context.push('/patients');
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: context.responsiveFont(20),
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: context.responsiveFont(11.5),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: context.responsiveFont(10),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
