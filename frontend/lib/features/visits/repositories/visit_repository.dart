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
              (v.patient?.uhid == 'C407662'));
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
      if (supaList.isNotEmpty) {
        _localVisits.clear();
        _localVisits.addAll(supaList);
        await _saveCache();
        return _filterVisits(supaList, status, departmentId, query);
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
        final fetched = list.map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>)).toList();
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
        if (supaList.isNotEmpty) {
          final existingIds = _localVisits.map((v) => v.id).toSet();
          bool hasNew = false;
          for (final sv in supaList) {
            if (!existingIds.contains(sv.id)) {
              _localVisits.add(sv);
              hasNew = true;
            }
          }
          if (hasNew) {
            await _saveCache();
          }
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
            final fetched = list.map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>)).toList();
            final existingIds = _localVisits.map((v) => v.id).toSet();
            bool hasNew = false;
            for (final v in fetched) {
              if (!existingIds.contains(v.id)) {
                _localVisits.add(v);
                hasNew = true;
              }
            }
            if (hasNew) {
              await _saveCache();
            }
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
  }) async {
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
        },
      );

      if (res.data['status'] == 'success') {
        final created = OPDVisitModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final merged = created.copyWith(
          patient: patient ?? created.patient,
          doctorName: doctorName ?? created.doctorName,
          departmentName: departmentName ?? created.departmentName,
        );
        _localVisits.insert(0, merged);
        await _saveCache();
        SupabaseService.upsertVisit(merged).catchError((_) => false);
        return merged;
      }
    } catch (_) {}

    await _loadCacheIfNeeded();

    final now = DateTime.now();
    final dd = now.day.toString().padLeft(2, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final yy = (now.year % 100).toString().padLeft(2, '0');
    final todayPrefix = 'SMVMCH$dd$mm$yy';

    // Strictly unique sequential token calculation across all patients and departments today
    int maxTodayToken = 0;
    for (final v in _localVisits) {
      if (v.visitDate.year == now.year &&
          v.visitDate.month == now.month &&
          v.visitDate.day == now.day) {
        if (v.queueToken > maxTodayToken) {
          maxTodayToken = v.queueToken;
        }
        if (v.visitNumber.startsWith(todayPrefix)) {
          final suffixStr = v.visitNumber.substring(todayPrefix.length);
          final parsed = int.tryParse(suffixStr);
          if (parsed != null && parsed > maxTodayToken) {
            maxTodayToken = parsed;
          }
        }
      }
    }

    try {
      final supaVisits = await SupabaseService.fetchVisits();
      for (final sv in supaVisits) {
        if (sv.visitDate.year == now.year &&
            sv.visitDate.month == now.month &&
            sv.visitDate.day == now.day) {
          if (sv.queueToken > maxTodayToken) {
            maxTodayToken = sv.queueToken;
          }
          if (sv.visitNumber.startsWith(todayPrefix)) {
            final suffixStr = sv.visitNumber.substring(todayPrefix.length);
            final parsed = int.tryParse(suffixStr);
            if (parsed != null && parsed > maxTodayToken) {
              maxTodayToken = parsed;
            }
          }
        }
      }
    } catch (_) {}

    final token = maxTodayToken + 1;
    final tokenFormatted = '$todayPrefix${token.toString().padLeft(4, '0')}';

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
      doctorName: doctorName ?? 'OPD Consulting Physician',
      departmentName: departmentName ?? departmentId,
    );
    _localVisits.insert(0, newVisit);
    await _saveCache();
    // Persist directly to Supabase PostgreSQL so all physical devices see this visit
    SupabaseService.upsertVisit(newVisit).catchError((_) => false);
    return newVisit;
  }

  Future<VitalSignsModel> recordVitals(VitalSignsModel vitals) async {
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
      cli.from('opd_visits').update({'status': 'TRIAGED'}).eq('id', vitals.visitId).catchError((_) => null);
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.visitVitals(vitals.visitId),
        data: vitals.toJson(),
      );

      if (res.data['status'] == 'success') {
        final savedVitals = VitalSignsModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _updateLocalVisitWithVitals(savedVitals);
        return savedVitals;
      }
    } catch (_) {}

    _updateLocalVisitWithVitals(vitals);
    return vitals;
  }

  Future<void> _updateLocalVisitWithVitals(VitalSignsModel vitals) async {
    await _loadCacheIfNeeded();
    final idx = _localVisits.indexWhere((v) => v.id == vitals.visitId);
    if (idx != -1) {
      _localVisits[idx] = _localVisits[idx].copyWith(
        vitals: vitals,
        status: 'TRIAGED',
      );
      await _saveCache();
    }
  }
}
