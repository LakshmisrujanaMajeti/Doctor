import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../doctors/models/doctor_model.dart';
import '../../doctors/repositories/doctor_repository.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../../dashboard/providers/doctor_dashboard_provider.dart';
import '../models/visit_model.dart';
import '../providers/visit_provider.dart';
import '../repositories/visit_repository.dart';

/// Shows an interactive bottom sheet allowing Receptionists and Staff to
/// retrieve an outpatient token and reassign them to the correct consulting doctor and department.
Future<void> showReassignDoctorDialog(
  BuildContext context,
  WidgetRef ref,
  OPDVisitModel visit,
) {
  final providerDocs = ref.read(doctorListProvider).value;
  final allDoctors = (providerDocs != null && providerDocs.isNotEmpty)
      ? providerDocs
      : DoctorRepository.cachedDoctors;

  final deptNames = <String>{};
  for (final doc in allDoctors) {
    if (doc.departmentName.isNotEmpty) {
      deptNames.add(doc.departmentName);
    }
  }
  // Ensure primary hospital departments are represented
  const standardDepts = [
    'General Medicine',
    'Pulmonology',
    'Cardiology',
    'Pediatrics',
    'Orthopedics',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'Neurology',
    'Oncology',
    'Nephrology',
    'Gynecology & Obstetrics',
    'Dental / Maxillofacial Surgery',
    'ENT (Otorhinolaryngology)',
    'General Surgery',
    'Psychiatry',
    'Emergency Medicine',
    'Anesthesiology',
    'Radiology',
    'Ophthalmology',
  ];
  for (final d in standardDepts) {
    deptNames.add(d);
  }
  final sortedDepts = deptNames.toList()..sort();

  // Find initial department match
  String selectedDept = visit.departmentName ?? 'General Medicine';
  if (!sortedDepts.contains(selectedDept)) {
    final match = sortedDepts.firstWhere(
      (d) => d.toLowerCase().contains(selectedDept.toLowerCase()) ||
             selectedDept.toLowerCase().contains(d.toLowerCase()),
      orElse: () => sortedDepts.first,
    );
    selectedDept = match;
  }

  String? selectedDoctorId = visit.doctorId.isNotEmpty ? visit.doctorId : null;
  bool isSaving = false;

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        // Filter available doctors by selected department
        final deptDoctors = allDoctors.where((d) =>
          d.departmentName.toLowerCase().contains(selectedDept.toLowerCase()) ||
          selectedDept.toLowerCase().contains(d.departmentName.toLowerCase()) ||
          d.specialization.toLowerCase().contains(selectedDept.toLowerCase())
        ).toList();

        final availableDocs = deptDoctors.isNotEmpty ? deptDoctors : allDoctors;
        if (selectedDoctorId == null || !availableDocs.any((d) => d.id == selectedDoctorId || d.userId == selectedDoctorId)) {
          selectedDoctorId = availableDocs.first.id;
        }

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon & close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.swap_horiz_rounded, color: Colors.amber.shade900, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Reassign Consulting Doctor',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Retrieve and reallocate outpatient encounter',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Patient & Current Token Info Summary Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Round Token Circle
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.hospitalMaroon.withValues(alpha: 0.12),
                          border: Border.all(color: AppColors.hospitalMaroon.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'TOKEN',
                              style: TextStyle(fontSize: 6.5, fontWeight: FontWeight.w800, color: AppColors.hospitalMaroon),
                            ),
                            Text(
                              '#${visit.queueToken}',
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: AppColors.hospitalMaroon, height: 1.0),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit.patient?.fullName ?? 'Outpatient ${visit.visitNumber}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${visit.patient?.uhid ?? "UHID Pending"} • Currently: ${visit.departmentName ?? "OPD"} (${visit.doctorName ?? "Doctor"})',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? Colors.grey[400] : Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Department Selection
                const Text(
                  '1. Select Target Department',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: sortedDepts.contains(selectedDept) ? selectedDept : sortedDepts.first,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.apartment_rounded, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: sortedDepts.map((dept) => DropdownMenuItem(
                    value: dept,
                    child: Text(dept, style: const TextStyle(fontSize: 13.5)),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() {
                        selectedDept = val;
                        final newDocs = allDoctors.where((d) =>
                          d.departmentName.toLowerCase().contains(val.toLowerCase()) ||
                          val.toLowerCase().contains(d.departmentName.toLowerCase()) ||
                          d.specialization.toLowerCase().contains(val.toLowerCase())
                        ).toList();
                        selectedDoctorId = newDocs.isNotEmpty ? newDocs.first.id : allDoctors.first.id;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Doctor Selection
                const Text(
                  '2. Select Consulting Specialist Doctor',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedDoctorId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.medical_services_rounded, size: 20, color: AppColors.hospitalMaroon),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: availableDocs.map((doc) => DropdownMenuItem(
                    value: doc.id,
                    child: Text(
                      '${doc.name} • ${doc.specialization} (${doc.roomNumber})',
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => selectedDoctorId = val);
                    }
                  },
                ),
                const SizedBox(height: 22),

                // Confirm Reassignment Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade800,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 19),
                    label: Text(
                      isSaving ? 'Reassigning Encounter...' : 'Reassign & Update OPD Queue',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isSaving ? null : () async {
                      setSheetState(() => isSaving = true);
                      try {
                        final assignedDoc = allDoctors.firstWhere(
                          (d) => d.id == selectedDoctorId || d.userId == selectedDoctorId,
                          orElse: () => availableDocs.first,
                        );

                        await ref.read(visitRepositoryProvider).reassignVisit(
                          visitId: visit.id,
                          doctorId: assignedDoc.id,
                          departmentId: assignedDoc.departmentId.isNotEmpty
                              ? assignedDoc.departmentId
                              : selectedDept,
                          doctorName: assignedDoc.name,
                          departmentName: assignedDoc.departmentName.isNotEmpty
                              ? assignedDoc.departmentName
                              : selectedDept,
                        );

                        ref.invalidate(visitListProvider);
                        ref.invalidate(doctorDashboardProvider);
                        ref.invalidate(dashboardStatsProvider);

                        if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.triageNormal,
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Retrieved Token #${visit.queueToken} and allotted to ${assignedDoc.name} (${selectedDept})!',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setSheetState(() => isSaving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red.shade700,
                              content: Text('Failed to reassign: $e'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
