import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/doctor_dashboard_model.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';
import '../../visits/repositories/visit_repository.dart';

final doctorDashboardProvider = FutureProvider<DoctorDashboardModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  // 1. Instant 0-1ms calculation from RAM if pre-warmed cache has visits
  final cachedVisits = VisitRepository.cachedVisits;
  if (cachedVisits.isNotEmpty) {
    if (DioClient.isHostReachable) {
      Future.microtask(() async {
        try {
          await dioClient.dio.get(ApiEndpoints.doctorMyDashboard);
        } catch (_) {}
      });
    }

    final waiting = cachedVisits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED' || v.status == 'TRIAGED').toList();
    final underConsult = cachedVisits.where((v) => v.status == 'UNDER_CONSULTATION' || v.status == 'IN_CONSULTATION').toList();
    final completed = cachedVisits.where((v) => v.status == 'COMPLETED').toList();

    return DoctorDashboardModel(
      stats: DoctorDashboardStatsModel(
        todayAppointments: cachedVisits.length,
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
  }

  // 2. Cold launch with empty memory: query server or visit repository
  if (DioClient.isHostReachable) {
    try {
      final response = await dioClient.dio.get(ApiEndpoints.doctorMyDashboard);
      if (response.data['status'] == 'success') {
        return DoctorDashboardModel.fromJson(response.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
  }

  List<OPDVisitModel> visits = [];
  try {
    visits = await ref.watch(visitRepositoryProvider).getVisits();
  } catch (_) {}

  final waiting = visits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED' || v.status == 'TRIAGED').toList();
  final underConsult = visits.where((v) => v.status == 'UNDER_CONSULTATION' || v.status == 'IN_CONSULTATION').toList();
  final completed = visits.where((v) => v.status == 'COMPLETED').toList();

  return DoctorDashboardModel(
    stats: DoctorDashboardStatsModel(
      todayAppointments: visits.length,
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
