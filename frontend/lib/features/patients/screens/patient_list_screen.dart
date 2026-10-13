import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/input_sanitizer.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../../../shared/widgets/medical_illustrator_background.dart';
import '../models/patient_model.dart';
import '../providers/patient_provider.dart';

class PatientListScreen extends ConsumerWidget {
  const PatientListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientsAsync = ref.watch(patientListProvider);

    return Scaffold(
      appBar: AppBar(
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
        onPressed: () => context.push('/patients/new'),
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
                      onAction: () => context.push('/patients/new'),
                    );
                  }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          _showPatientOptions(context, patient);
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
                                    const SizedBox(height: 4),
                                    Text(
                                      patient.hospitalRegNum!,
                                      style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
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
              error: (err, _) => Center(child: Text('Error loading patients: $err')),
            ),
          ),
        ],
      ),
    ),
  );
  }

  void _showPatientOptions(BuildContext context, PatientModel patient) {
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
                        Text(
                          'UHID: ${patient.uhid} • Reg: ${patient.hospitalRegNum ?? "N/A"}',
                          style: const TextStyle(color: AppColors.primaryTeal, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
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
              const Divider(height: 24),
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
                title: const Text('View OPD Booklet Card'),
                subtitle: Text('${patient.parentSpouseRelation ?? "S/o"}: ${patient.parentSpouseName ?? "N/A"} • ${patient.phone}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBarcodeDialog(context, patient);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBarcodeDialog(BuildContext context, PatientModel patient) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Patient OPD Identifier Card', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  const Icon(Icons.qr_code, size: 100, color: AppColors.primaryTeal),
                  const SizedBox(height: 8),
                  Text(patient.barcodeValue ?? 'BAR-${patient.uhid}', style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  const Divider(),
                  Text(patient.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('${patient.gender} • ${patient.ageYears ?? "--"} yrs • Blood: ${patient.bloodGroup ?? "N/A"}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  if (patient.parentSpouseName != null)
                    Text('${patient.parentSpouseRelation ?? "S/o"}: ${patient.parentSpouseName}', style: const TextStyle(fontSize: 12)),
                  Text('UHID: ${patient.uhid}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryTeal)),
                  Text('Reg No: ${patient.hospitalRegNum ?? "N/A"}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
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
}
