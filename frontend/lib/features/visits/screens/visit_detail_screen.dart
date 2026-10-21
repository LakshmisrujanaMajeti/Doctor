import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/opd_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/triage_chip.dart';
import '../../auth/providers/auth_provider.dart';
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
    final authState = ref.watch(authProvider);
    final currentRole = authState.user?.roleName.toLowerCase() ?? 'patient';
    final isPatient = currentRole == 'patient';
    final isDoctor = currentRole == 'doctor';
    final isNurse = currentRole == 'nurse';
    final isPharmacist = currentRole == 'pharmacist';
    final isBilling = currentRole == 'billing';
    final isLab = currentRole == 'laboratory' || currentRole == 'lab_tech';
    final isAdminOrReceptionist = currentRole == 'admin' || currentRole == 'receptionist';

    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final todayTokenPrefix = 'SMVMCH$dd$mm$yy';

    final visitsAsync = ref.watch(visitListProvider);
    final currentVisit = visit ?? visitsAsync.asData?.value.cast<OPDVisitModel?>().firstWhere(
      (v) => v?.id == visitId || v?.visitNumber == visitId,
      orElse: () => null,
    ) ?? OPDVisitModel(
      id: visitId,
      visitNumber: visitId.toUpperCase().startsWith('SMVMCH') ? visitId.toUpperCase() : '$todayTokenPrefix-OPD',
      patientId: '',
      doctorId: '',
      departmentId: '',
      queueToken: 1,
      triagePriority: 'NORMAL',
      status: 'REGISTERED',
      consultationFee: 500.0,
      paymentStatus: 'UNPAID',
      visitDate: now,
    );

    final displayToken = currentVisit.formattedToken.isNotEmpty
        ? currentVisit.formattedToken
        : (currentVisit.visitNumber.isNotEmpty ? currentVisit.visitNumber : 'OPD Slip');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (Navigator.canPop(context)) {
              context.pop();
            } else {
              context.go('/queue');
            }
          },
        ),
        title: Text('OPD Slip: $displayToken'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPatient) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryTeal.withOpacity(0.25)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.shield_outlined, color: AppColors.primaryTeal, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Patient Access Mode: View-only access to your token, OPD clinical summary, prescriptions, and billing receipts.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Token Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOKEN: $displayToken',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primaryTeal,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Department Queue #${currentVisit.queueToken} • ${currentVisit.departmentName ?? "Outpatient Clinic"}',
                                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
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
                              '\$${currentVisit.consultationFee} (${currentVisit.paymentStatus})',
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
                        _infoRow(Icons.person, 'Full Name', currentVisit.patient?.fullName ?? 'Outpatient'),
                        const Divider(height: 16),
                        _infoRow(Icons.badge, 'UHID', currentVisit.patient?.uhid ?? '--'),
                        const Divider(height: 16),
                        _infoRow(Icons.phone, 'Contact', currentVisit.patient?.phone ?? '--'),
                        const Divider(height: 16),
                        _infoRow(Icons.bloodtype, 'Blood Group', currentVisit.patient?.bloodGroup ?? '--'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Actions Section - Strictly filtered by RBAC Role
                Text(
                  isPatient ? 'Patient Records & Documents (Read-Only)' : 'Authorized Outpatient Actions',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 10),

                // 1. Patient Role: View-only buttons
                if (isPatient) ...[
                  OpdButton(
                    label: 'Open Digital OPD Booklet & Vitals',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    color: AppColors.primaryBlue,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      } else {
                        context.push('/patient/portal');
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Prescriptions & Medications',
                    icon: Icons.medication_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () => context.push('/visits/${currentVisit.id}/prescriptions', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Patient Portal & Invoices',
                    icon: Icons.receipt_long_rounded,
                    width: double.infinity,
                    color: AppColors.secondaryNavy,
                    onPressed: () => context.push('/patient/portal'),
                  ),
                ],

                // 2. Doctor Role: Clinical Consultation Sheet & Prescriptions
                if (isDoctor) ...[
                  OpdButton(
                    label: 'Doctor Consultation Booklet Sheet',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    color: AppColors.secondaryNavy,
                    onPressed: () => context.push('/visits/${currentVisit.id}/consultation', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'Prescription & Dispensary',
                    icon: Icons.medication_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () => context.push('/visits/${currentVisit.id}/prescriptions', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Digital OPD Booklet',
                    icon: Icons.auto_stories_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      }
                    },
                  ),
                ],

                // 3. Nurse Role: Triage & Vital Signs Entry
                if (isNurse) ...[
                  OpdButton(
                    label: 'Triage & Vital Signs Entry',
                    icon: Icons.monitor_heart_rounded,
                    width: double.infinity,
                    color: AppColors.primaryTeal,
                    onPressed: () => context.push('/visits/${currentVisit.id}/vitals', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Digital OPD Booklet',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      }
                    },
                  ),
                ],

                // 4. Pharmacist Role: Dispensary Verification & Prescriptions
                if (isPharmacist) ...[
                  OpdButton(
                    label: 'Prescription & Dispensary Verification',
                    icon: Icons.medication_rounded,
                    width: double.infinity,
                    color: AppColors.primaryTeal,
                    onPressed: () => context.push('/visits/${currentVisit.id}/prescriptions', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'Pharmacy Dispensary Queue',
                    icon: Icons.local_pharmacy_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () => context.push('/pharmacy'),
                  ),
                ],

                // 5. Billing Role: Invoicing & Receipt
                if (isBilling) ...[
                  OpdButton(
                    label: 'Open Billing Counter & Receipt',
                    icon: Icons.receipt_long_rounded,
                    width: double.infinity,
                    color: Colors.green.shade700,
                    onPressed: () => context.push('/billing'),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Digital OPD Booklet',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      }
                    },
                  ),
                ],

                // 6. Lab Role: Laboratory Worklist
                if (isLab) ...[
                  OpdButton(
                    label: 'Laboratory Diagnostics Worklist',
                    icon: Icons.biotech_rounded,
                    width: double.infinity,
                    color: const Color(0xFF6366F1),
                    onPressed: () => context.push('/laboratory'),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'View Digital OPD Booklet',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      }
                    },
                  ),
                ],

                // 7. Admin & Receptionist: Full Clinical Operations
                if (isAdminOrReceptionist) ...[
                  OpdButton(
                    label: 'Triage & Vital Signs Entry',
                    icon: Icons.monitor_heart_rounded,
                    width: double.infinity,
                    onPressed: () => context.push('/visits/${currentVisit.id}/vitals', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'Doctor Consultation Booklet Sheet',
                    icon: Icons.menu_book_rounded,
                    width: double.infinity,
                    color: AppColors.secondaryNavy,
                    onPressed: () => context.push('/visits/${currentVisit.id}/consultation', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'Prescription & Dispensary',
                    icon: Icons.medication_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () => context.push('/visits/${currentVisit.id}/prescriptions', extra: currentVisit),
                  ),
                  const SizedBox(height: 12),
                  OpdButton(
                    label: 'Open Digital OPD Booklet',
                    icon: Icons.auto_stories_rounded,
                    width: double.infinity,
                    isOutlined: true,
                    onPressed: () {
                      final pid = currentVisit.patientId;
                      if (pid.isNotEmpty) {
                        context.push('/patients/$pid/booklet');
                      }
                    },
                  ),
                ],
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
