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

  // 1. Live real-time hospital operational statistics from backend
  try {
    if (DioClient.isHostReachable) {
      final res = await dioClient.dio.get(ApiEndpoints.adminStats);
      if (res.data != null && res.data['status'] == 'success' && res.data['data'] != null) {
        return DashboardStatsModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    }
  } catch (_) {}

  // 2. Offline fallback calculating dynamically from local caches and active providers
  final patientAsync = ref.watch(patientListProvider);
  final allPatients = patientAsync.value ?? PatientRepository.cachedPatients;
  final cachedVisits = VisitRepository.cachedVisits;
  final cachedDoctors = DoctorRepository.cachedDoctors.isNotEmpty
      ? DoctorRepository.cachedDoctors
      : DoctorRepository.defaultDoctors;

  final totalPatients = allPatients.length;
  final totalVisits = cachedVisits.length;
  final waiting = cachedVisits.where((v) => v.status == 'WAITING' || v.status == 'REGISTERED').length;
  final triaged = cachedVisits.where((v) => v.status == 'TRIAGED').length;
  final completed = cachedVisits.where((v) => v.status == 'COMPLETED').length;
  final activeDoctors = cachedDoctors.where((d) => d.isAvailable).length;
  final deptCount = cachedDoctors.map((d) => d.departmentId).where((id) => id.isNotEmpty).toSet().length;

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  final todayReg = allPatients.where((p) =>
      (p.registrationDate != null && p.registrationDate!.isAfter(todayStart)) ||
      (p.createdAt != null && p.createdAt!.isAfter(todayStart))).length;
  final yestReg = allPatients.where((p) =>
      (p.registrationDate != null && p.registrationDate!.isAfter(yesterdayStart) && p.registrationDate!.isBefore(todayStart)) ||
      (p.createdAt != null && p.createdAt!.isAfter(yesterdayStart) && p.createdAt!.isBefore(todayStart))).length;

  final todayVitals = cachedVisits.where((v) => (v.status == 'TRIAGED' || v.vitals != null) && v.visitDate.isAfter(todayStart)).length;
  final yestVitals = cachedVisits.where((v) => (v.status == 'TRIAGED' || v.vitals != null) && v.visitDate.isAfter(yesterdayStart) && v.visitDate.isBefore(todayStart)).length;
  final totalVitals = cachedVisits.where((v) => v.status == 'TRIAGED' || v.vitals != null).length;

  return DashboardStatsModel(
    totalPatients: totalPatients,
    todayRegisteredPatients: todayReg,
    yesterdayRegisteredPatients: yestReg,
    todayTriagedVitals: todayVitals,
    yesterdayTriagedVitals: yestVitals,
    totalTriagedVitals: totalVitals,
    totalVisits: totalVisits,
    activeDoctors: activeDoctors > 0 ? activeDoctors : cachedDoctors.length,
    departments: deptCount > 0 ? deptCount : 6,
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
