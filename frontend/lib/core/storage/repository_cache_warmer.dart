import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../storage/secure_storage_service.dart';
import '../../features/patients/models/patient_model.dart';
import '../../features/patients/repositories/patient_repository.dart';
import '../../features/visits/models/visit_model.dart';
import '../../features/visits/repositories/visit_repository.dart';
import '../../features/doctors/models/doctor_model.dart';
import '../../features/doctors/repositories/doctor_repository.dart';
import '../../features/admin_portal/models/admin_portal_models.dart';
import '../../features/admin_portal/repositories/admin_portal_repository.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'initial_hospital_data.dart';

/// Pre-warms in-memory repository caches at application startup.
/// Ensures all screens, KPI dashboards, queues, and directories load in 0-1ms.
class RepositoryCacheWarmer {
  static bool _hasWarmed = false;
  static bool get hasWarmed => _hasWarmed;

  static const String currentCacheVersion = 'smvmch_canonical_db_v9';

  static Future<void> prewarmAll() async {
    if (_hasWarmed) return;

    try {
      // Purge old stale cache from earlier test builds on mobile devices
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getString('opd_cache_version');
      if (savedVersion != currentCacheVersion) {
        await prefs.remove(SecureStorageService.keyPatientsData);
        await prefs.remove(SecureStorageService.keyVisitsData);
        await prefs.remove(SecureStorageService.keyStaffDirectoryData);
        await prefs.remove(SecureStorageService.keyBillsData);
        await prefs.setString('opd_cache_version', currentCacheVersion);
      }

      final results = await Future.wait([
        SecureStorageService.getPatientsJson().catchError((_) => null),
        SecureStorageService.getVisitsJson().catchError((_) => null),
        SecureStorageService.getStaffDirectoryJson().catchError((_) => null),
      ]);

      final rawPatients = results[0];
      final rawVisits = results[1];
      final rawStaff = results[2];

      // 1. Warm Patients Cache
      List<PatientModel> patients = [];
      if (rawPatients != null && rawPatients.isNotEmpty) {
        try {
          final list = jsonDecode(rawPatients) as List<dynamic>;
          patients = list
              .map((m) => PatientModel.fromJson(m as Map<String, dynamic>))
              .where((p) =>
                  p.uhid != 'C407662' &&
                  p.id != 'pat-c407662' &&
                  !p.fullName.toLowerCase().contains('ravi prasanth') &&
                  !_isSyntheticPatient(p))
              .toList();
        } catch (e) {
          debugPrint('Warm patients error: $e');
        }
      }

      // Populate authoritative canonical hospital patients from InitialHospitalData
      try {
        final map = jsonDecode(InitialHospitalData.jsonSnapshot) as Map<String, dynamic>;
        final list = (map['patients'] as List?) ?? [];
        final canonicalPatients = list.map((m) => PatientModel.fromJson(m as Map<String, dynamic>)).toList();
        final Map<String, PatientModel> patientMap = {};
        for (final p in patients) {
          patientMap[p.uhid] = p;
        }
        for (final cp in canonicalPatients) {
          patientMap[cp.uhid] = cp; // Canonical database record is authoritative
        }
        patients = patientMap.values.toList();
      } catch (e) {
        debugPrint('Canonical patients merge error: $e');
      }

      if (patients.isNotEmpty) {
        PatientRepository.initializeCache(patients);
        await SecureStorageService.savePatientsJson(jsonEncode(patients.map((p) => p.toJson()).toList()));
      }

      // 2. Warm Visits Cache
      List<OPDVisitModel> visits = [];
      if (rawVisits != null && rawVisits.isNotEmpty) {
        try {
          final list = jsonDecode(rawVisits) as List<dynamic>;
          visits = list
              .map((m) => OPDVisitModel.fromJson(m as Map<String, dynamic>))
              .where((v) =>
                  !v.id.contains('c407662') &&
                  !(v.patient?.fullName.toLowerCase().contains('ravi prasanth') ?? false) &&
                  v.patient?.uhid != 'C407662' &&
                  !_isSyntheticVisit(v))
              .toList();
        } catch (e) {
          debugPrint('Warm visits error: $e');
        }
      }

      // Populate authoritative canonical hospital visits from InitialHospitalData
      try {
        final map = jsonDecode(InitialHospitalData.jsonSnapshot) as Map<String, dynamic>;
        final list = (map['visits'] as List?) ?? [];
        final canonicalVisits = list.map((m) => OPDVisitModel.fromJson(m as Map<String, dynamic>)).toList();
        final Map<String, OPDVisitModel> visitMap = {};
        for (final v in visits) {
          visitMap[v.visitNumber] = v;
        }
        for (final cv in canonicalVisits) {
          visitMap[cv.visitNumber] = cv; // Canonical database record is authoritative
        }
        visits = visitMap.values.toList();
      } catch (e) {
        debugPrint('Canonical visits merge error: $e');
      }

      // Hydrate all visits with their corresponding PatientModel
      for (int i = 0; i < visits.length; i++) {
        final v = visits[i];
        final matchedPat = patients.where((p) => p.id == v.patientId || p.uhid == v.patientId).firstOrNull;
        if (matchedPat != null) {
          visits[i] = v.copyWith(patient: matchedPat);
        }
      }

      if (visits.isNotEmpty) {
        VisitRepository.initializeCache(visits);
        await SecureStorageService.saveVisitsJson(jsonEncode(visits.map((v) => v.toJson()).toList()));
      }

      // 3. Warm Doctors & Staff Cache
      if (rawStaff != null && rawStaff.isNotEmpty) {
        try {
          final list = jsonDecode(rawStaff) as List<dynamic>;
          final doctors = <DoctorModel>[];
          final users = <AdminUserModel>[];

          for (final item in list) {
            final map = item as Map<String, dynamic>;
            users.add(AdminUserModel.fromJson(map));
            final role = (map['role_name'] as String? ?? map['role'] as String? ?? '').toLowerCase();
            if (role == 'doctor') {
              final docId = map['id'] as String? ?? 'doc-${map['email']}';
              doctors.add(DoctorModel(
                id: docId,
                userId: docId,
                name: map['full_name'] as String? ?? map['name'] as String? ?? 'Dr. Specialist',
                specialization: map['specialization'] as String? ?? 'General Medicine',
                departmentId: map['department_id'] as String? ?? 'General Medicine',
                departmentName: map['department_name'] as String? ?? 'General Medicine',
                qualification: map['qualification'] as String? ?? 'MBBS, Specialist',
                roomNumber: map['room_number'] as String? ?? 'Room ${101 + doctors.length}',
                consultationFee: 500.0,
                isAvailable: true,
              ));
            }
          }

          DoctorRepository.initializeCache(doctors);
          AdminPortalRepository.initializeCache(users);
        } catch (e) {
          debugPrint('Warm staff error: $e');
        }
      }

      // Fallback to bundled doctors if staff cache empty
      if (DoctorRepository.cachedDoctors.isEmpty) {
        try {
          final map = jsonDecode(InitialHospitalData.jsonSnapshot) as Map<String, dynamic>;
          final docList = (map['doctors'] as List?) ?? [];
          final doctors = <DoctorModel>[];
          for (final item in docList) {
            final m = item as Map<String, dynamic>;
            doctors.add(DoctorModel(
              id: m['id']?.toString() ?? '',
              userId: m['user_id']?.toString() ?? m['id']?.toString() ?? '',
              name: m['name']?.toString() ?? 'Dr. Specialist',
              specialization: m['specialization']?.toString() ?? 'General Medicine',
              departmentId: m['department_id']?.toString() ?? 'General Medicine',
              departmentName: m['department_name']?.toString() ?? 'General Medicine',
              qualification: m['qualification']?.toString() ?? 'MBBS, MD',
              roomNumber: m['room_number']?.toString() ?? 'Room 101',
              consultationFee: (m['consultation_fee'] as num?)?.toDouble() ?? 500.0,
              isAvailable: true,
            ));
          }
          if (doctors.isNotEmpty) {
            DoctorRepository.initializeCache(doctors);
          }
        } catch (_) {}
      }

      _hasWarmed = true;
      debugPrint('⚡ [CACHE WARMER] In-memory repositories pre-warmed for 0-1ms instant loading');
    } catch (e) {
      debugPrint('Cache prewarm note: $e');
    }
  }

  static bool _isSyntheticPatient(PatientModel p) => false;
  static bool _isSyntheticVisit(OPDVisitModel v) => false;
}
