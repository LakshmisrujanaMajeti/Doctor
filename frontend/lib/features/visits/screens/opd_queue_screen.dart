import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/smvmch_hospital_logo.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/visit_model.dart';
import '../providers/visit_provider.dart';
import '../widgets/reassign_doctor_dialog.dart';

class OpdQueueScreen extends ConsumerStatefulWidget {
  const OpdQueueScreen({super.key});

  @override
  ConsumerState<OpdQueueScreen> createState() => _OpdQueueScreenState();
}

class _OpdQueueScreenState extends ConsumerState<OpdQueueScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.invalidate(visitListProvider);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitListProvider);
    final currentFilter = ref.watch(visitStatusFilterProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authProvider);
    final currentRole = authState.user?.roleName.toLowerCase() ?? 'patient';
    final isPatient = currentRole == 'patient';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.goNamed(RouteNames.dashboard);
            }
          },
        ),
        title: Row(
          children: [
            const SmvmchHospitalLogo(size: 26),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Live OPD Queue',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'SMVMCH Puducherry',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 14),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.hospitalGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hospitalGreen.withOpacity(0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt_rounded, size: 13, color: AppColors.hospitalGreen),
                SizedBox(width: 2),
                Text(
                  '5s',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.hospitalGreen,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: 'Refresh Queue',
            onPressed: () => ref.invalidate(visitListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            visualDensity: VisualDensity.compact,
            tooltip: 'Logout',
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) {
                context.goNamed(RouteNames.welcome);
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: isPatient
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Book Visit'),
              onPressed: () => context.push('/visits/new'),
            ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.clinical,
        child: Column(
          children: [
            // Instant Search Bar by Token #, UHID, or Patient Name
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search Token # (e.g. 1), UHID, Phone, or Name...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryTeal),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                  ),
                ),
              ),
            ),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _filterChip(null, 'All Visits', currentFilter == null),
                  const SizedBox(width: 8),
                  _filterChip('REGISTERED', 'Waiting Triage', currentFilter == 'REGISTERED'),
                  const SizedBox(width: 8),
                  _filterChip('TRIAGED', 'Ready for Doctor', currentFilter == 'TRIAGED'),
                  const SizedBox(width: 8),
                  _filterChip('IN_CONSULTATION', 'In Consultation', currentFilter == 'IN_CONSULTATION'),
                  const SizedBox(width: 8),
                  _filterChip('COMPLETED', 'Completed', currentFilter == 'COMPLETED'),
                ],
              ),
            ),

            // Visits List
            Expanded(
              child: visitsAsync.when(
                data: (visits) {
                  final q = _searchCtrl.text.trim().toLowerCase();
                  final cleanDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
                  final queryNumber = cleanDigits.isNotEmpty ? int.tryParse(cleanDigits) : null;

                  final filteredVisits = q.isEmpty
                      ? visits
                      : visits.where((v) {
                          final token = v.queueToken;
                          final tokenStr = token.toString();
                          final tokenPrefixed = '#$tokenStr';
                          final uhid = (v.patient?.uhid ?? '').toLowerCase();
                          final reg = (v.patient?.hospitalRegNum ?? '').toLowerCase();
                          final barcode = (v.patient?.barcodeValue ?? '').toLowerCase();
                          final name = (v.patient?.fullName ?? '').toLowerCase();
                          final phone = (v.patient?.phone ?? '').toLowerCase();
                          final visitNum = v.visitNumber.toLowerCase();
                          final docName = (v.doctorName ?? '').toLowerCase();
                          final deptName = (v.departmentName ?? '').toLowerCase();

                          // Exact or prefixed token match
                          if (tokenStr == q || tokenPrefixed == q) return true;

                          // Formatted token match (e.g. SMVMCH1510260001 or substring)
                          if (v.formattedToken.toLowerCase().contains(q)) return true;

                          // Token number extracted from "token 1", "tok #1", "# 1", "T-1", "01" (tokens are < 1000)
                          if (queryNumber != null && queryNumber < 1000 && queryNumber == token) return true;

                          // Demographics and clinical metadata match (handles UHID, Reg No, Name, Phone)
                          final matchPhone = (q.length >= 4 && phone.contains(q)) || phone == q;
                          if (uhid.contains(q) ||
                              reg.contains(q) ||
                              barcode.contains(q) ||
                              name.contains(q) ||
                              matchPhone ||
                              visitNum.contains(q) ||
                              docName.contains(q) ||
                              deptName.contains(q)) {
                            return true;
                          }

                          return false;
                        }).toList();

                  if (filteredVisits.isEmpty) {
                    return EmptyStateWidget(
                      title: q.isNotEmpty ? 'No Matching Patient or Token' : 'No Visits in Queue',
                      message: q.isNotEmpty
                          ? 'No visit matched "$q". Check the Token # or UHID entered.'
                          : 'No patient visits found in this status queue. Select another filter or book a new visit.',
                      icon: Icons.queue_rounded,
                      actionLabel: q.isNotEmpty ? 'Clear Search' : 'Book Visit',
                      onAction: () {
                        if (q.isNotEmpty) {
                          _searchCtrl.clear();
                          setState(() {});
                        } else {
                          context.push('/visits/new');
                        }
                      },
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(visitListProvider);
                      try {
                        await ref.read(visitListProvider.future);
                      } catch (_) {}
                    },
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.horizontalPadding(context),
                      vertical: 8,
                    ),
                    itemCount: filteredVisits.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final visit = filteredVisits[index];
                      return Card(
                        elevation: 1.5,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row: Patient Name & Details on left, Small Round Token on right
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          visit.effectivePatientName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${visit.effectivePatientUhid} • ${visit.departmentName}' + ((visit.doctorName != null && visit.doctorName!.trim().isNotEmpty && visit.doctorName != 'Dr. Specialist') ? ' • ${visit.doctorName}' : ''),
                                          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            TriageChip(priority: visit.triagePriority),
                                            StatusBadge(status: visit.status),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Right Top: Small round token symbol as requested
                                  Tooltip(
                                    message: 'Queue Token #${visit.queueToken} (${visit.formattedToken})',
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.hospitalMaroon.withOpacity(0.08),
                                        border: Border.all(
                                          color: AppColors.hospitalMaroon.withOpacity(0.4),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.hospitalMaroon.withOpacity(0.06),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '#${visit.queueToken}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: AppColors.hospitalMaroon,
                                              height: 1.1,
                                            ),
                                          ),
                                          const Text(
                                            'TOKEN',
                                            style: TextStyle(
                                              fontSize: 6.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.3,
                                              color: AppColors.hospitalMaroon,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Doctor & Vitals Info with responsive Wrap
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.person_pin_rounded, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Allotted Doctor: ${visit.doctorName ?? "Consulting Doctor"}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.hospitalMaroon),
                                        softWrap: true,
                                      ),
                                    ],
                                  ),
                                  if (visit.vitals != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.teal.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'BP: ${visit.vitals!.bloodPressureDisplay} • SpO2: ${visit.vitals!.spo2Percent ?? "--"}%',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal),
                                      ),
                                    )
                                  else
                                    Text(
                                      'Vitals Pending',
                                      style: TextStyle(fontSize: 12, color: Colors.amber[800], fontWeight: FontWeight.w600),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Action Buttons Row: Patient view-only, Staff full action row
                              if (isPatient)
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.receipt_rounded, size: 15),
                                        label: const Text('View OPD Slip', overflow: TextOverflow.ellipsis),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => context.push('/visits/${visit.id}', extra: visit),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.auto_stories_rounded, size: 15),
                                        label: const Text('Digital Booklet', overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryTeal,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => context.push('/patients/${visit.patientId}/booklet'),
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.monitor_heart_rounded, size: 15),
                                        label: Text(
                                          visit.vitals == null ? 'Vitals' : 'Edit Vitals',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => context.push('/visits/${visit.id}/vitals', extra: visit),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                                        label: const Text('Consult', overflow: TextOverflow.ellipsis),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryTeal,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => context.push('/visits/${visit.id}/consultation', extra: visit),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(Icons.auto_stories_rounded, size: 15, color: AppColors.hospitalMaroon),
                                        label: const Text(
                                          'Booklet',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: AppColors.hospitalMaroon, fontWeight: FontWeight.bold),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: AppColors.hospitalMaroon),
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          context.push('/patients/${visit.patientId}/booklet');
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 48, color: AppColors.triagePriority),
                        const SizedBox(height: 12),
                        const Text(
                          'Unable to Load OPD Queue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Network connection or queue service error occurred.\nPlease check your connection and retry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                          icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                          label: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                          onPressed: () => ref.invalidate(visitListProvider),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String? status, String label, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(visitStatusFilterProvider.notifier).setFilter(status);
      },
    );
  }
}
