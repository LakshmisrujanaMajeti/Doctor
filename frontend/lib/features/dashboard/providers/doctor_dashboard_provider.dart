import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/doctor_dashboard_model.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../doctors/models/doctor_model.dart';
import '../../doctors/repositories/doctor_repository.dart';

final doctorDashboardProvider = FutureProvider<DoctorDashboardModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final currentUser = ref.watch(authProvider).user;
  // Automatically re-evaluate whenever hospital visit list changes in real-time
  ref.watch(visitListProvider);

  // 1. Fetch official doctor dashboard from backend (strictly isolated per doctor on backend)
  if (DioClient.isHostReachable) {
    try {
      final response = await dioClient.dio
          .get(ApiEndpoints.doctorMyDashboard)
          .timeout(const Duration(milliseconds: 1500));
      if (response.data is Map && response.data['status'] == 'success') {
        return DoctorDashboardModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  // 2. Local fallback: strictly filter visits assigned to THIS doctor or their specialty
  List<OPDVisitModel> allVisits = VisitRepository.cachedVisits;
  if (allVisits.isEmpty) {
    try {
      allVisits = await ref.watch(visitRepositoryProvider).getVisits();
    } catch (_) {}
  }

  final docEmail = currentUser?.email.toLowerCase() ?? '';
  final docName = currentUser?.fullName.toLowerCase() ?? '';
  final docId = currentUser?.id.toLowerCase() ?? '';

  // Look up doctor profile from directory
  final cachedDocs = DoctorRepository.cachedDoctors;
  DoctorModel? myDocProfile;
  for (final d in cachedDocs) {
    if (d.userId.toLowerCase() == docId || d.id.toLowerCase() == docId) {
      myDocProfile = d;
      break;
    }
    final emailPrefix = docEmail.isNotEmpty ? docEmail.split('@')[0] : '';
    if (emailPrefix.isNotEmpty) {
      if (d.name.toLowerCase().contains(emailPrefix) ||
          d.departmentName.toLowerCase().contains(emailPrefix) ||
          d.specialization.toLowerCase().contains(emailPrefix)) {
        myDocProfile = d;
        break;
      }
    }
  }

  final myVisits = allVisits.where((v) {
    if (currentUser == null) return false;
    final vDocId = v.doctorId.toLowerCase();
    final vDocName = v.doctorName?.toLowerCase() ?? '';
    final vDept = v.departmentName?.toLowerCase() ?? '';
    final vDeptId = v.departmentId.toLowerCase();

    // Direct ID match against user or doctor ID
    if (vDocId.isNotEmpty) {
      if (vDocId == docId || vDocId.contains(docId) || docId.contains(vDocId)) return true;
      if (myDocProfile != null && (vDocId == myDocProfile.id.toLowerCase() || vDocId.contains(myDocProfile.id.toLowerCase()))) return true;
      // If visit is explicitly assigned to another doctor, do not steal it
      return false;
    }

    // Direct Doctor Name match
    if (vDocName.isNotEmpty && docName.isNotEmpty) {
      final cleanV = vDocName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();
      final cleanU = docName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();
      if (cleanV.isNotEmpty && cleanU.isNotEmpty && (cleanU.contains(cleanV) || cleanV.contains(cleanU))) {
        return true;
      }
    }

    // Only if unassigned to a specific doctor: match department
    if (vDocId.isEmpty && myDocProfile != null) {
      if (vDept.isNotEmpty && myDocProfile.departmentName.toLowerCase().contains(vDept)) return true;
      if (vDept.isNotEmpty && vDept.contains(myDocProfile.departmentName.toLowerCase())) return true;
      if (vDeptId.isNotEmpty && vDeptId == myDocProfile.departmentId.toLowerCase()) return true;
    }

    return false;
  }).toList();

  final waiting = myVisits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED' || v.status == 'TRIAGED').toList();
  final underConsult = myVisits.where((v) => v.status == 'UNDER_CONSULTATION' || v.status == 'IN_CONSULTATION').toList();
  final completed = myVisits.where((v) => v.status == 'COMPLETED').toList();

  return DoctorDashboardModel(
    stats: DoctorDashboardStatsModel(
      todayAppointments: myVisits.length,
      waitingPatients: waiting.length,
      underConsultation: underConsult.length,
      completedConsultations: completed.length,
      pendingInvestigations: 0,
      followUpAppointments: 0,
    ),
    waitingPatients: waiting,
    underConsultation: underConsult,
    completedConsultations: completed,
    pendingInvestigations: const [],
    followUpAppointments: const [],
    recentAuthorizedPatients: const [],
  );
});
