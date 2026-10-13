import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/dashboard_stats.dart';

import '../../patients/providers/patient_provider.dart';
import '../../visits/providers/visit_provider.dart';

final dashboardStatsProvider = FutureProvider<DashboardStatsModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  try {
    final res = await dioClient.dio.get(ApiEndpoints.adminStats);
    if (res.data['status'] == 'success') {
      return DashboardStatsModel.fromJson(res.data['data'] as Map<String, dynamic>);
    }
  } catch (_) {}

  // Dynamic real-time calculation from active repositories
  int totalPatients = 0;
  int totalVisits = 0;
  int waiting = 0;
  int triaged = 0;
  int completed = 0;

  try {
    final patients = await ref.watch(patientRepositoryProvider).getPatients();
    totalPatients = patients.length;
  } catch (_) {}

  try {
    final visits = await ref.watch(visitRepositoryProvider).getVisits();
    totalVisits = visits.length;
    waiting = visits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED').length;
    triaged = visits.where((v) => v.status == 'TRIAGED').length;
    completed = visits.where((v) => v.status == 'COMPLETED').length;
  } catch (_) {}

  return DashboardStatsModel(
    totalPatients: totalPatients,
    totalVisits: totalVisits,
    activeDoctors: 1,
    departments: 5,
    waiting: waiting,
    triaged: triaged,
    completed: completed,
  );
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setTheme(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
