import 'dart:convert';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/visit_model.dart';
import '../models/vitals_model.dart';
import '../../patients/models/patient_model.dart';

class VisitRepository {
  final DioClient _dioClient;

  // Local offline cache - shared static in-memory cache for instant 0ms access
  static final List<OPDVisitModel> _localVisits = [];
  static bool _isLoaded = false;

  static List<OPDVisitModel> get cachedVisits => List.unmodifiable(_localVisits);

  static void initializeCache(List<OPDVisitModel> visits) {
    _localVisits.clear();
    _localVisits.addAll(visits);
    _isLoaded = true;
  }

  VisitRepository(this._dioClient);

  static bool isSyntheticVisit(OPDVisitModel v) {
    // All OPD visits and queue tokens in PostgreSQL/Supabase are genuine hospital records.
    return false;
  }

  Future<void> _loadCacheIfNeeded() async {
    if (_localVisits.isEmpty) {
      try {
        final raw = await SecureStorageService.getVisitsJson();
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _localVisits.addAll(list.map((m) => OPDVisitModel.fromJson(m as Map<String, dynamic>)));
          // Purge any legacy demo or seed visits from old test builds
          final beforeCount = _localVisits.length;
          _localVisits.removeWhere((v) =>
              v.id.contains('c407662') ||
              (v.patient?.fullName.toLowerCase().contains('ravi prasanth') ?? false) ||
              (v.patient?.uhid == 'C407662') ||
              isSyntheticVisit(v));
          if (_localVisits.length != beforeCount) {
            await _saveCache();
          }
        }
      } catch (_) {}
    }
    _isLoaded = true;
  }

  Future<void> _saveCache() async {
    try {
      final jsonList = _localVisits.map((v) => v.toJson()).toList();
      await SecureStorageService.saveVisitsJson(jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Instant Stale-While-Revalidate: returns cached visits in 0-1ms,
  /// then asynchronously updates from Supabase Cloud and backend without blocking the UI.
  Future<List<OPDVisitModel>> getVisits({String? status, String? departmentId, String? query}) async {
    await _loadCacheIfNeeded();

    // 1. If we have cached visits, return immediately (0ms) and background sync
    if (_localVisits.isNotEmpty) {
      _syncVisitsFromCloud(status, departmentId, query);
      return _filterVisits(_localVisits, status, departmentId, query);
    }

    // 2. Cold first run with empty local storage: fetch from Supabase Cloud (works everywhere)
    try {
      final supaList = await SupabaseService.fetchVisits();
      final cleanList = supaList.where((v) => !isSyntheticVisit(v)).toList();
      if (cleanList.isNotEmpty) {
        _localVisits.clear();
        _localVisits.addAll(cleanList);
        await _saveCache();
        return _filterVisits(cleanList, status, departmentId, query);
      }
    } catch (_) {}

    // 3. Fallback to Dio backend if reachable
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.visits,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (departmentId != null && departmentId.isNotEmpty) 'department_id': departmentId,
          if (query != null && query.isNotEmpty) 'query': query,
        },
      );

      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        final fetched = list
            .map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>))
            .where((v) => !isSyntheticVisit(v))
            .toList();
        if ((status == null || status.isEmpty) && (departmentId == null || departmentId.isEmpty) && (query == null || query.isEmpty)) {
          _localVisits.clear();
          _localVisits.addAll(fetched);
          await _saveCache();
        }
        return _filterVisits(fetched, status, departmentId, query);
      }
    } catch (_) {}

    return _filterVisits(_localVisits, status, departmentId, query);
  }

  void _syncVisitsFromCloud(String? status, String? departmentId, String? query) {
    Future.microtask(() async {
      try {
        final supaList = await SupabaseService.fetchVisits();
        final cleanList = supaList.where((v) => !isSyntheticVisit(v)).toList();
        if (cleanList.isNotEmpty) {
          bool hasChanges = false;
          for (final sv in cleanList) {
            final idx = _localVisits.indexWhere((v) => v.id == sv.id || (v.visitNumber.isNotEmpty && v.visitNumber == sv.visitNumber));
            if (idx != -1) {
              _localVisits[idx] = sv;
              hasChanges = true;
            } else {
              _localVisits.add(sv);
              hasChanges = true;
            }
          }
          if (hasChanges) await _saveCache();
        }
      } catch (_) {}

      if (DioClient.isHostReachable) {
        try {
          final res = await _dioClient.dio.get(
            ApiEndpoints.visits,
            queryParameters: {
              if (status != null && status.isNotEmpty) 'status': status,
              if (departmentId != null && departmentId.isNotEmpty) 'department_id': departmentId,
              if (query != null && query.isNotEmpty) 'query': query,
            },
          );

          if (res.data['status'] == 'success') {
            final list = res.data['data'] as List<dynamic>;
            final fetched = list
                .map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>))
                .where((v) => !isSyntheticVisit(v))
                .toList();
            bool hasChanges = false;
            for (final fv in fetched) {
              final idx = _localVisits.indexWhere((v) => v.id == fv.id || (v.visitNumber.isNotEmpty && v.visitNumber == fv.visitNumber));
              if (idx != -1) {
                _localVisits[idx] = fv;
                hasChanges = true;
              } else {
                _localVisits.add(fv);
                hasChanges = true;
              }
            }
            if (hasChanges) await _saveCache();
          }
        } catch (_) {}
      }
    });
  }

  List<OPDVisitModel> _filterVisits(List<OPDVisitModel> source, String? status, String? departmentId, String? query) {
    var results = List<OPDVisitModel>.from(source);

    if (status != null && status.isNotEmpty) {
      results = results.where((v) => v.status == status).toList();
    }
    if (departmentId != null && departmentId.isNotEmpty) {
      results = results.where((v) => v.departmentId == departmentId).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      final cleanDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
      final queryNum = cleanDigits.isNotEmpty ? int.tryParse(cleanDigits) : null;

      results = results.where((v) {
        final token = v.queueToken;
        final tokenStr = token.toString();
        final tokenPrefixed = '#$tokenStr';
        final uhid = (v.patient?.uhid ?? '').toLowerCase();
        final name = (v.patient?.fullName ?? '').toLowerCase();
        final phone = (v.patient?.phone ?? '').toLowerCase();
        final visitNum = v.visitNumber.toLowerCase();
        final docName = (v.doctorName ?? '').toLowerCase();

        if (tokenStr == q || tokenPrefixed == q) return true;
        if (queryNum != null && queryNum == token) return true;
        if (uhid.contains(q) || name.contains(q) || phone.contains(q) || visitNum.contains(q) || docName.contains(q)) {
          return true;
        }
        return false;
      }).toList();
    }

    return results;
  }

  Future<OPDVisitModel> reassignVisit({
    required String visitId,
    required String doctorId,
    required String departmentId,
    String? doctorName,
    String? departmentName,
  }) async {
    try {
      final res = await _dioClient.dio.patch(
        '${ApiEndpoints.visits}/$visitId',
        data: {
          'doctor_id': doctorId,
          'department_id': departmentId,
        },
      );
      if (res.data != null && res.data['status'] == 'success') {
        final updated = OPDVisitModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final merged = updated.copyWith(
          doctorName: doctorName ?? updated.doctorName,
          departmentName: departmentName ?? updated.departmentName,
        );
        _updateLocalVisit(merged);
        await _saveCache();
        SupabaseService.upsertVisit(merged).catchError((_) => false);
        return merged;
      }
    } catch (_) {}

    await _loadCacheIfNeeded();
    final idx = _localVisits.indexWhere((v) => v.id == visitId);
    if (idx >= 0) {
      final existing = _localVisits[idx];
      final reassigned = existing.copyWith(
        doctorId: doctorId,
        departmentId: departmentId,
        doctorName: doctorName ?? existing.doctorName,
        departmentName: departmentName ?? existing.departmentName,
      );
      _localVisits[idx] = reassigned;
      await _saveCache();
      SupabaseService.upsertVisit(reassigned).catchError((_) => false);
      return reassigned;
    }
    throw Exception('Visit with ID $visitId not found');
  }

  Future<OPDVisitModel?> updateVisitStatus(String visitId, String status) async {
    await _loadCacheIfNeeded();
    final idx = _localVisits.indexWhere((v) => v.id == visitId);
    if (idx >= 0) {
      final existing = _localVisits[idx];
      final updated = existing.copyWith(status: status);
      _localVisits[idx] = updated;
      await _saveCache();

      // Immediately sync to Supabase Cloud
      final cli = SupabaseService.client;
      if (cli != null) {
        cli.from('opd_visits').update({'status': status}).eq('id', visitId).catchError((_) => null);
      }

      // Sync to backend if reachable
      if (DioClient.isHostReachable) {
        try {
          await _dioClient.dio.patch(
            '${ApiEndpoints.visits}/$visitId',
            data: {'status': status},
          );
        } catch (_) {}
      }

      return updated;
    }
    return null;
  }

  void _updateLocalVisit(OPDVisitModel visit) {
    final idx = _localVisits.indexWhere((v) => v.id == visit.id);
    if (idx >= 0) {
      _localVisits[idx] = visit;
    } else {
      // If another active visit for this patient exists today, update that encounter
      final now = DateTime.now();
      final activeIdx = _localVisits.indexWhere((v) =>
        v.patientId == visit.patientId &&
        (v.status == 'REGISTERED' || v.status == 'TRIAGED' || v.status == 'IN_CONSULTATION') &&
        v.visitDate.year == now.year &&
        v.visitDate.month == now.month &&
        v.visitDate.day == now.day
      );
      if (activeIdx >= 0) {
        _localVisits[activeIdx] = visit;
      } else {
        _localVisits.insert(0, visit);
      }
    }
  }

  Future<OPDVisitModel> createVisit({
    required String patientId,
    required String doctorId,
    required String departmentId,
    String? doctorName,
    String? departmentName,
    PatientModel? patient,
    String triagePriority = 'NORMAL',
    double consultationFee = 500.0,
    String? notes,
    bool allowAdditionalVisit = false,
  }) async {
    await _loadCacheIfNeeded();

    // Check if patient already has an active visit for today locally
    final now = DateTime.now();
    if (!allowAdditionalVisit) {
      final existingActiveIdx = _localVisits.indexWhere((v) =>
        v.patientId == patientId &&
        (v.status == 'REGISTERED' || v.status == 'TRIAGED' || v.status == 'IN_CONSULTATION') &&
        v.visitDate.year == now.year &&
        v.visitDate.month == now.month &&
        v.visitDate.day == now.day
      );

      if (existingActiveIdx >= 0) {
        final existing = _localVisits[existingActiveIdx];
        return await reassignVisit(
          visitId: existing.id,
          doctorId: doctorId,
          departmentId: departmentId,
          doctorName: doctorName,
          departmentName: departmentName,
        );
      }
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.visits,
        data: {
          'patient_id': patientId,
          'doctor_id': doctorId,
          'department_id': departmentId,
          'triage_priority': triagePriority,
          'consultation_fee': consultationFee,
          'notes': notes,
          'allow_additional_visit': allowAdditionalVisit,
        },
      );

      if (res.data['status'] == 'success') {
        final created = OPDVisitModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final merged = created.copyWith(
          patient: patient ?? created.patient,
          doctorName: doctorName ?? created.doctorName,
          departmentName: departmentName ?? created.departmentName,
        );
        _updateLocalVisit(merged);
        await _saveCache();
        SupabaseService.upsertVisit(merged).catchError((_) => false);
        return merged;
      }
    } catch (_) {}

    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');

    // Department-scoped sequential token calculation for today to prevent overlap
    final deptTodayVisits = _localVisits.where((v) =>
      (v.departmentId == departmentId || (v.departmentName != null && v.departmentName == departmentName)) &&
      v.visitDate.year == now.year &&
      v.visitDate.month == now.month &&
      v.visitDate.day == now.day
    ).toList();
    final token = deptTodayVisits.length + 1;
    final tokenFormatted = 'SMVMCH$dd$mm$yy${token.toString().padLeft(4, '0')}';

    final newVisit = OPDVisitModel(
      id: 'vis-${DateTime.now().millisecondsSinceEpoch}',
      visitNumber: tokenFormatted,
      patientId: patientId,
      doctorId: doctorId,
      departmentId: departmentId,
      queueToken: token,
      triagePriority: triagePriority,
      status: 'REGISTERED',
      consultationFee: consultationFee,
      paymentStatus: 'UNPAID',
      notes: notes,
      visitDate: now,
      patient: patient,
      doctorName: doctorName ?? 'Dr. Sarah Chen, MD',
      departmentName: departmentName ?? departmentId,
    );
    _updateLocalVisit(newVisit);
    await _saveCache();
    // Persist directly to Supabase PostgreSQL so all physical devices see this visit
    SupabaseService.upsertVisit(newVisit).catchError((_) => false);
    return newVisit;
  }

  Future<VitalSignsModel> recordVitals(VitalSignsModel vitals, {String? triagePriority}) async {
    // 1. Immediately persist to Supabase Cloud PostgreSQL
    SupabaseService.upsertVitalSigns({
      'id': vitals.id.isNotEmpty ? vitals.id : 'vit_${vitals.visitId}',
      'visit_id': vitals.visitId,
      'systolic_bp': vitals.systolicBp,
      'diastolic_bp': vitals.diastolicBp,
      'pulse_rate': vitals.pulseRate,
      'temperature_f': vitals.temperatureF,
      'spo2_percent': vitals.spo2Percent,
      'respiratory_rate': vitals.respiratoryRate,
      'height_cm': vitals.heightCm,
      'weight_kg': vitals.weightKg,
      'bmi': vitals.bmi,
      'notes': vitals.notes,
    }).catchError((_) => false);

    final cli = SupabaseService.client;
    if (cli != null) {
      final updateData = <String, dynamic>{'status': 'TRIAGED'};
      if (triagePriority != null && triagePriority.isNotEmpty) {
        updateData['triage_priority'] = triagePriority;
      }
      cli.from('opd_visits').update(updateData).eq('id', vitals.visitId).catchError((_) => null);
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.visitVitals(vitals.visitId),
        data: {
          ...vitals.toJson(),
          if (triagePriority != null && triagePriority.isNotEmpty) 'triage_priority': triagePriority,
        },
      );

      if (res.data['status'] == 'success') {
        final savedVitals = VitalSignsModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _updateLocalVisitWithVitals(savedVitals, triagePriority: triagePriority);
        return savedVitals;
      }
    } catch (_) {}

    _updateLocalVisitWithVitals(vitals, triagePriority: triagePriority);
    return vitals;
  }

  Future<void> _updateLocalVisitWithVitals(VitalSignsModel vitals, {String? triagePriority}) async {
    await _loadCacheIfNeeded();
    final idx = _localVisits.indexWhere((v) => v.id == vitals.visitId);
    if (idx != -1) {
      _localVisits[idx] = _localVisits[idx].copyWith(
        vitals: vitals,
        status: 'TRIAGED',
        triagePriority: triagePriority ?? _localVisits[idx].triagePriority,
      );
      await _saveCache();
    }
  }
}
