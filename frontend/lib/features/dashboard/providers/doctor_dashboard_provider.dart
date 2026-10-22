import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/doctor_dashboard_model.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../auth/providers/auth_provider.dart';

final doctorDashboardProvider = FutureProvider<DoctorDashboardModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);
  final currentUser = ref.watch(authProvider).user;

  // 1. Fetch official doctor dashboard from backend (strictly isolated per doctor on backend)
  if (DioClient.isHostReachable) {
    try {
      final response = await dioClient.dio.get(ApiEndpoints.doctorMyDashboard);
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

  final myVisits = allVisits.where((v) {
    if (currentUser == null) return false;
    final vDocId = v.doctorId.toLowerCase();
    final vDocName = v.doctorName?.toLowerCase() ?? '';
    final vDept = v.departmentName?.toLowerCase() ?? '';

    // Direct ID match
    if (vDocId.isNotEmpty && (vDocId == docId || vDocId.contains(docId) || docId.contains(vDocId))) {
      return true;
    }

    // Name match
    if (vDocName.isNotEmpty && docName.isNotEmpty) {
      final cleanV = vDocName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();
      final cleanU = docName.replaceAll(RegExp(r'^(dr\.?|doctor)\s*', caseSensitive: false), '').trim();
      if (cleanV.isNotEmpty && cleanU.isNotEmpty && (cleanU.contains(cleanV) || cleanV.contains(cleanU))) {
        return true;
      }
    }

    // Department match based on doctor specialty
    if (docEmail.contains('pulmon') && vDept.contains('pulmon')) return true;
    if (docEmail.contains('cardio') && vDept.contains('cardio')) return true;
    if (docEmail.contains('pediatric') && vDept.contains('pediatric')) return true;
    if (docEmail.contains('ortho') && vDept.contains('ortho')) return true;
    if (docEmail.contains('derma') && vDept.contains('derma')) return true;
    if (docEmail.contains('gastro') && vDept.contains('gastro')) return true;
    if (docEmail.contains('neuro') && vDept.contains('neuro')) return true;
    if (docEmail.contains('onco') && vDept.contains('onco')) return true;
    if (docEmail.contains('nephro') && vDept.contains('nephro')) return true;
    if (docEmail.contains('gynec') && vDept.contains('gynec')) return true;
    if (docEmail.contains('dent') && vDept.contains('dent')) return true;
    if (docEmail.contains('ent') && vDept.contains('ent')) return true;
    if (docEmail == 'doctor@smvmch.ac.in' && (vDept.contains('general') || vDept.isEmpty)) return true;

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
