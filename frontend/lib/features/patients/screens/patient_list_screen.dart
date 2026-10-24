import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/app_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../core/utils/responsive.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../../../shared/widgets/confirmation_dialog.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';
import '../widgets/patient_identifier_card_widget.dart';
import '../widgets/edit_patient_dialog.dart';

class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/dashboard');
            }
          },
        ),
        title: const Text('Patient Directory & OPD Records', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(patientListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Patient'),
        onPressed: () async {
          await context.push('/patients/new');
          ref.read(patientSearchQueryProvider.notifier).setQuery('');
          ref.invalidate(patientListProvider);
          ref.invalidate(dashboardStatsProvider);
        },
      ),
      body: MedicalIllustratorBackground(
        variant: MedicalBackgroundVariant.portal,
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by Name, UHID, Reg No, Phone, or Barcode...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => ref.read(patientSearchQueryProvider.notifier).setQuery(''),
                  ),
                ),
                onChanged: (value) {
                  final cleaned = InputSanitizer.sanitizeSearchQuery(value);
                  ref.read(patientSearchQueryProvider.notifier).setQuery(cleaned);
                },
              ),
            ),

            // Patients List
            Expanded(
              child: patientsAsync.when(
                data: (patients) {
                  if (patients.isEmpty) {
                    return EmptyStateWidget(
                      title: 'No Patients Found',
                      message: 'Try searching with a different UHID or register a new patient.',
                      icon: Icons.person_search_rounded,
                      actionLabel: 'Register Patient',
                      onAction: () async {
                        await context.push('/patients/new');
                        ref.read(patientSearchQueryProvider.notifier).setQuery('');
                        ref.invalidate(patientListProvider);
                        ref.invalidate(dashboardStatsProvider);
                      },
                    );
                  }

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(patientListProvider);
                    try {
                      await ref.read(patientListProvider.future);
                    } catch (_) {}
                  },
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.symmetric(
                    horizontal: Responsive.horizontalPadding(context),
                    vertical: 8,
                  ),
                  itemCount: patients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final patient = patients[index];
                    return Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          _showPatientOptions(context, ref, patient);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primaryTeal.withOpacity(0.12),
                                child: Text(
                                  patient.fullName.isNotEmpty
                                      ? patient.fullName[0].toUpperCase()
                                      : 'P',
                                  style: const TextStyle(
                                    color: AppColors.primaryTeal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
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
                                            patient.fullName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                        if (patient.bloodGroup != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              patient.bloodGroup!,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    if (patient.parentSpouseName != null && patient.parentSpouseName!.isNotEmpty)
                                      Text(
                                        '${patient.parentSpouseRelation ?? "S/o"}: ${patient.parentSpouseName}',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${patient.gender} • ${patient.ageYears ?? "--"} yrs • ${patient.phone}',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    if (patient.city != null && patient.city!.isNotEmpty)
                                      Text(
                                        '${patient.city}, ${patient.state ?? ""}',
                                        style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondaryNavy.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.secondaryNavy.withOpacity(0.2)),
                                    ),
                                    child: Text(
                                      patient.uhid,
                                      style: const TextStyle(
                                        color: AppColors.secondaryNavy,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),

                                  if (patient.hospitalRegNum != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      patient.hospitalRegNum!,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  if (patient.registrationDate != null || patient.createdAt != null) ...[
                                    const SizedBox(height: 3),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.event_note_rounded, size: 10.5, color: Colors.grey[600]),
                                        const SizedBox(width: 3),
                                        Text(
                                          _formatDateTime(patient.registrationDate ?? patient.createdAt),
                                          style: TextStyle(fontSize: 9.5, color: Colors.grey[600], fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error loading patients: $err')),
            ),
          ),
        ],
      ),
    ),
  );
  }

  static String _formatDateTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}, $hour:$minute $ampm';
  }

  void _showPatientOptions(BuildContext context, WidgetRef ref, PatientModel patient) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.fullName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'UHID: ${patient.uhid} • Reg: ${patient.hospitalRegNum ?? "N/A"}',
                          style: const TextStyle(color: AppColors.primaryTeal, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        if (patient.registrationDate != null || patient.createdAt != null) ...[
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 13, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                'Registered: ${_formatDateTime(patient.registrationDate ?? patient.createdAt)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.qr_code_2, size: 30, color: AppColors.primaryTeal),
                    onPressed: () {
                      _showBarcodeDialog(context, patient);
                    },
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.auto_stories_rounded, color: AppColors.hospitalMaroon),
                title: const Text('Digital Out Patient Book', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.hospitalMaroon)),
                subtitle: const Text('View 7-page official booklet: Cover, Barcodes, Assessment, Rx, Bill, Labs'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/patients/${patient.id}/booklet');
                },
              ),
              ListTile(
                leading: const Icon(Icons.confirmation_number_rounded, color: AppColors.primaryTeal),
                title: const Text('Book OPD Visit & Issue Token'),
                subtitle: const Text('Assign consulting department, doctor, and triage priority'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/visits/new', extra: patient);
                },
              ),
              ListTile(
                leading: const Icon(Icons.badge_outlined, color: AppColors.secondaryNavy),
                title: const Text('View OPD Barcode ID Card'),
                subtitle: Text('${patient.parentSpouseRelation ?? "S/o"}: ${patient.parentSpouseName ?? "N/A"} • ${patient.phone}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBarcodeDialog(context, patient);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primaryBlue),
                title: const Text('Edit Patient Demographics'),
                subtitle: const Text('Update full name, phone number, age, gender, address'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditPatientDialog(context, ref, patient);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.triageEmergency),
                title: const Text('Delete Patient Record', style: TextStyle(color: AppColors.triageEmergency, fontWeight: FontWeight.w600)),
                subtitle: const Text('Permanently remove this registration'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeletePatient(context, ref, patient);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditPatientDialog(BuildContext context, WidgetRef ref, PatientModel patient) async {
    final updated = await EditPatientDialog.show(context, patient);
    if (updated != null) {
      ref.invalidate(patientListProvider);
      ref.invalidate(dashboardStatsProvider);
    }
  }

  void _confirmDeletePatient(BuildContext context, WidgetRef ref, PatientModel patient) async {
    final confirm = await showOpdConfirmDialog(
      context: context,
      title: 'Delete Patient?',
      message: 'Are you sure you want to permanently delete patient "${patient.fullName}" (UHID: ${patient.uhid})? This will permanently remove the record and cannot be undone.',
      confirmText: 'Delete Record',
      isDestructive: true,
    );
    if (confirm == true) {
      try {
        await ref.read(patientRepositoryProvider).deletePatient(patient.id);
        ref.invalidate(patientListProvider);
        ref.invalidate(dashboardStatsProvider);
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

  void _showBarcodeDialog(BuildContext context, PatientModel patient, [WidgetRef? ref]) {
    PatientIdentifierCardWidget.showCardDialog(
      context,
      patient,
      repository: ref?.read(patientRepositoryProvider),
    );
  }
}
