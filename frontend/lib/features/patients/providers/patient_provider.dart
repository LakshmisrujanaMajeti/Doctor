import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../doctors/repositories/doctor_repository.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../visits/providers/visit_provider.dart';
import '../../dashboard/providers/doctor_dashboard_provider.dart';
import '../models/patient_model.dart';
import '../repositories/patient_repository.dart';

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return PatientRepository(dioClient);
});

class PatientSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

final patientSearchQueryProvider = NotifierProvider<PatientSearchNotifier, String>(PatientSearchNotifier.new);

final patientListProvider = FutureProvider<List<PatientModel>>((ref) async {
  final repository = ref.watch(patientRepositoryProvider);
  final query = ref.watch(patientSearchQueryProvider);
  return repository.getPatients(query: query);
});

/// Filtered patients list containing ONLY patients that the logged-in doctor should see
final doctorAssignedPatientsProvider = FutureProvider<List<PatientModel>>((ref) async {
  final query = ref.watch(patientSearchQueryProvider);
  final currentUser = ref.watch(authProvider).user;

  // Watch visits so doctor patient list updates automatically when consultations complete
  ref.watch(visitListProvider);

  final allPatients = await ref.watch(patientRepositoryProvider).getPatients();
  if (currentUser == null) return allPatients;

  final docId = currentUser.id.toLowerCase();
  final docName = currentUser.fullName.toLowerCase();
  final cleanDocName = docName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();

  // Look up doctor profile if exists
  final cachedDocs = DoctorRepository.cachedDoctors;
  final myDoc = cachedDocs.where((d) =>
    d.userId.toLowerCase() == docId ||
    d.id.toLowerCase() == docId ||
    (cleanDocName.isNotEmpty && d.name.toLowerCase().contains(cleanDocName))
  ).firstOrNull;

  final allVisits = VisitRepository.cachedVisits;
  final assignedPatientIds = <String>{};
  final assignedPatientsDirect = <PatientModel>[];

  for (final v in allVisits) {
    bool matches = false;
    final vDocId = v.doctorId.toLowerCase();
    final vDocName = (v.doctorName ?? '').toLowerCase();
    final cleanVName = vDocName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();

    if (vDocId.isNotEmpty && (vDocId == docId || vDocId.contains(docId) || docId.contains(vDocId))) {
      matches = true;
    } else if (myDoc != null && (vDocId == myDoc.id.toLowerCase() || vDocId.contains(myDoc.id.toLowerCase()))) {
      matches = true;
    } else if (cleanVName.isNotEmpty && cleanDocName.isNotEmpty && (cleanDocName.contains(cleanVName) || cleanVName.contains(cleanDocName))) {
      matches = true;
    } else if (vDocId.isEmpty && myDoc != null) {
      final vDept = (v.departmentName ?? '').toLowerCase();
      if (vDept.isNotEmpty && myDoc.departmentName.toLowerCase().contains(vDept)) {
        matches = true;
      }
    }

    if (matches) {
      if (v.patientId.isNotEmpty) assignedPatientIds.add(v.patientId);
      if (v.patient != null) {
        assignedPatientIds.add(v.patient!.id);
        assignedPatientIds.add(v.patient!.uhid);
        if (!assignedPatientsDirect.any((p) => p.id == v.patient!.id || p.uhid == v.patient!.uhid)) {
          assignedPatientsDirect.add(v.patient!);
        }
      }
    }
  }

  // Also include patients from doctorDashboardProvider
  final docDashboard = ref.watch(doctorDashboardProvider).value;
  if (docDashboard != null) {
    for (final appt in docDashboard.todayAppointments) {
      assignedPatientIds.add(appt.patientId);
      if (appt.patient != null) {
        assignedPatientIds.add(appt.patient!.id);
        assignedPatientIds.add(appt.patient!.uhid);
      }
    }
    for (final r in docDashboard.recentAuthorizedPatients) {
      assignedPatientIds.add(r.patientId);
      assignedPatientIds.add(r.uhid);
    }
  }

  // Filter full patient directory
  final filtered = allPatients.where((p) {
    return assignedPatientIds.contains(p.id) ||
           assignedPatientIds.contains(p.uhid) ||
           assignedPatientIds.contains(p.hospitalRegNum);
  }).toList();

  // Merge any patients from visits directly
  for (final p in assignedPatientsDirect) {
    if (!filtered.any((item) => item.id == p.id || item.uhid == p.uhid)) {
      filtered.add(p);
    }
  }

  // Apply search query if present
  if (query.trim().isNotEmpty) {
    final q = query.trim().toLowerCase();
    return filtered.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
             p.uhid.toLowerCase().contains(q) ||
             (p.hospitalRegNum != null && p.hospitalRegNum!.toLowerCase().contains(q)) ||
             p.phone.contains(q);
    }).toList();
  }

  return filtered;
});

final patientDetailProvider = FutureProvider.family<PatientModel?, String>((ref, patientId) async {
  final repository = ref.watch(patientRepositoryProvider);
  return repository.getPatientById(patientId);
});
