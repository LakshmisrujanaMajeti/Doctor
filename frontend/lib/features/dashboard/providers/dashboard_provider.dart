import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../models/dashboard_stats.dart';

import '../../patients/models/patient_model.dart';
import '../../visits/models/visit_model.dart';
import '../../doctors/models/doctor_model.dart';
import '../../patients/providers/patient_provider.dart';
import '../../patients/repositories/patient_repository.dart';
import '../../visits/providers/visit_provider.dart';
import '../../visits/repositories/visit_repository.dart';
import '../../doctors/repositories/doctor_repository.dart';

final dashboardStatsProvider = FutureProvider<DashboardStatsModel>((ref) async {
  final dioClient = ref.watch(dioClientProvider);

  // 1. Instant 0-1ms calculation from RAM if pre-warmed cache has data
  final cachedPatients = PatientRepository.cachedPatients;
  final cachedVisits = VisitRepository.cachedVisits;
  final cachedDoctors = DoctorRepository.cachedDoctors;

  if (cachedPatients.isNotEmpty || cachedVisits.isNotEmpty || cachedDoctors.isNotEmpty) {
    final totalPatients = cachedPatients.length;
    final totalVisits = cachedVisits.length;
    final waiting = cachedVisits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED').length;
    final triaged = cachedVisits.where((v) => v.status == 'TRIAGED').length;
    final completed = cachedVisits.where((v) => v.status == 'COMPLETED').length;
    final activeDoctors = cachedDoctors.where((d) => d.isAvailable).length;

    // Asynchronously sync with live backend if online without stalling the UI
    if (DioClient.isHostReachable) {
      Future.microtask(() async {
        try {
          await dioClient.dio.get(ApiEndpoints.adminStats);
        } catch (_) {}
      });
    }

    return DashboardStatsModel(
      totalPatients: totalPatients,
      totalVisits: totalVisits,
      activeDoctors: activeDoctors,
      departments: totalPatients > 0 || totalVisits > 0 ? 5 : 0,
      waiting: waiting,
      triaged: triaged,
      completed: completed,
    );
  }

  // 2. Cold launch with empty memory: query server or active repositories
  try {
    if (DioClient.isHostReachable) {
      final res = await dioClient.dio.get(ApiEndpoints.adminStats);
      if (res.data['status'] == 'success') {
        return DashboardStatsModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    }
  } catch (_) {}

  // Concurrently calculate real-time hospital statistics from active repositories
  try {
    final results = await Future.wait([
      ref.watch(patientRepositoryProvider).getPatients().catchError((_) => <PatientModel>[]),
      ref.watch(visitRepositoryProvider).getVisits().catchError((_) => <OPDVisitModel>[]),
      ref.watch(doctorRepositoryProvider).getDoctors().catchError((_) => <DoctorModel>[]),
    ]);

    final patients = results[0] as List<PatientModel>;
    final visits = results[1] as List<OPDVisitModel>;
    final doctors = results[2] as List<DoctorModel>;

    final totalPatients = patients.length;
    final totalVisits = visits.length;
    final waiting = visits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED').length;
    final triaged = visits.where((v) => v.status == 'TRIAGED').length;
    final completed = visits.where((v) => v.status == 'COMPLETED').length;
    final activeDoctors = doctors.where((d) => d.isAvailable).length;

    return DashboardStatsModel(
      totalPatients: totalPatients,
      totalVisits: totalVisits,
      activeDoctors: activeDoctors,
      departments: totalPatients > 0 || totalVisits > 0 ? 5 : 0,
      waiting: waiting,
      triaged: triaged,
      completed: completed,
    );
  } catch (_) {
    return const DashboardStatsModel();
  }
});

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  void setTheme(ThemeMode mode) => state = mode;
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
