import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../models/visit_model.dart';
import '../providers/visit_provider.dart';

class VisitDetailScreen extends ConsumerWidget {
  final String visitId;
  final OPDVisitModel? visit;

  const VisitDetailScreen({
    super.key,
    required this.visitId,
    this.visit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(visitListProvider);
    final currentVisit = visit ?? visitsAsync.asData?.value.firstWhere(
      (v) => v.id == visitId,
      orElse: () => OPDVisitModel(
        id: visitId,
        visitNumber: 'VIS-20261012-0001',
        patientId: '',
        doctorId: '',
        departmentId: '',
        queueToken: 1,
        triagePriority: 'NORMAL',
        status: 'REGISTERED',
        consultationFee: 500.0,
        paymentStatus: 'UNPAID',
        visitDate: DateTime.now(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('OPD Slip #${currentVisit?.queueToken ?? 1}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Token Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'QUEUE TOKEN #${currentVisit?.queueToken}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                                Text(
                                  'Visit No: ${currentVisit?.visitNumber}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                            if (currentVisit != null)
                              TriageChip(priority: currentVisit.triagePriority),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            if (currentVisit != null)
                              StatusBadge(status: currentVisit.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Consultation Fee: ',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            Text(
                              '\$${currentVisit?.consultationFee ?? 500.0} (${currentVisit?.paymentStatus})',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Patient Information
                const Text(
                  'Patient Information',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _infoRow(Icons.person, 'Full Name', currentVisit?.patient?.fullName ?? 'Johnathan Reynolds'),
                        const Divider(height: 16),
                        _infoRow(Icons.badge, 'UHID', currentVisit?.patient?.uhid ?? 'UHID-2026-00001'),
                        const Divider(height: 16),
                        _infoRow(Icons.phone, 'Contact', currentVisit?.patient?.phone ?? '+1 555-123-4567'),
                        const Divider(height: 16),
                        _infoRow(Icons.bloodtype, 'Blood Group', currentVisit?.patient?.bloodGroup ?? 'O+'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Clinical Actions
                const Text(
                  'Outpatient Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),
                OpdButton(
                  label: 'Triage & Vital Signs Entry',
                  icon: Icons.monitor_heart_rounded,
                  width: double.infinity,
                  onPressed: () => context.push('/visits/${currentVisit?.id}/vitals', extra: currentVisit),
                ),
                const SizedBox(height: 12),
                OpdButton(
                  label: 'Doctor Consultation Booklet Sheet',
                  icon: Icons.menu_book_rounded,
                  width: double.infinity,
                  color: AppColors.secondaryNavy,
                  onPressed: () => context.push('/visits/${currentVisit?.id}/consultation', extra: currentVisit),
                ),
                const SizedBox(height: 12),
                OpdButton(
                  label: 'Prescription & Dispensary',
                  icon: Icons.medication_rounded,
                  width: double.infinity,
                  isOutlined: true,
                  onPressed: () => context.push('/visits/${currentVisit?.id}/prescriptions', extra: currentVisit),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryTeal),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }
}
