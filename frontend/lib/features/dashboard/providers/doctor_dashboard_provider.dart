import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/doctor_dashboard_model.dart';
import '../../visits/models/visit_model.dart';
import '../../visits/providers/visit_provider.dart';

final doctorDashboardProvider = FutureProvider<DoctorDashboardModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  try {
    final response = await dioClient.dio.get(ApiEndpoints.doctorMyDashboard);
    if (response.data['status'] == 'success') {
      return DoctorDashboardModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }
  } catch (e) {
    // If running in development/mock mode without active backend or offline, provide realistic fallback
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
