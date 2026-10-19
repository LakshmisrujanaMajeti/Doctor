import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/supabase_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/patient_model.dart';
import '../../visits/repositories/visit_repository.dart';

class PatientRepository {
  final DioClient _dioClient;

  // Local offline cache - shared static in-memory cache for instant 0ms access
  static final List<PatientModel> _localPatients = [];
  static bool _isLoaded = false;

  static List<PatientModel> get cachedPatients => List.unmodifiable(_localPatients);

  static void initializeCache(List<PatientModel> patients) {
    _localPatients.clear();
    _localPatients.addAll(patients);
    _isLoaded = true;
  }

  PatientRepository(this._dioClient);

  Future<void> _loadCacheIfNeeded() async {
    if (_localPatients.isEmpty) {
      try {
        final raw = await SecureStorageService.getPatientsJson();
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _localPatients.addAll(list.map((m) => PatientModel.fromJson(m as Map<String, dynamic>)));
          // Purge any legacy demo or seed patients from old test builds
          final beforeCount = _localPatients.length;
          _localPatients.removeWhere((p) =>
              p.uhid == 'C407662' ||
              p.id == 'pat-c407662' ||
              p.fullName.toLowerCase().contains('ravi prasanth'));
          if (_localPatients.length != beforeCount) {
            await _saveCache();
          }
        }
      } catch (_) {}
    }
    _isLoaded = true;
  }

  Future<void> _saveCache() async {
    try {
      final jsonList = _localPatients.map((p) => p.toJson()).toList();
      await SecureStorageService.savePatientsJson(jsonEncode(jsonList));
    } catch (_) {}
  }

  /// Instant Stale-While-Revalidate: returns cached patients in 0-1ms,
  /// then asynchronously updates from Supabase Cloud and backend without blocking the UI.
  Future<List<PatientModel>> getPatients({String? query}) async {
    await _loadCacheIfNeeded();

    // 1. If we have cached patients, return immediately (0ms) and background sync
    if (_localPatients.isNotEmpty) {
      _syncPatientsFromCloud(query);
      return _filterPatients(_localPatients, query);
    }

    // 2. Cold first run with empty local storage: fetch from Supabase Cloud (works everywhere)
    try {
      final supaList = await SupabaseService.fetchPatients();
      if (supaList.isNotEmpty) {
        _localPatients.clear();
        _localPatients.addAll(supaList);
        await _saveCache();
        return _filterPatients(supaList, query);
      }
    } catch (_) {}

    // 3. Fallback to Dio backend if reachable
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.patients,
        queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
      );

      final dynamic raw = res.data is String ? jsonDecode(res.data as String) : res.data;
      if (raw is Map && raw['status'] == 'success') {
        final list = raw['data'] as List<dynamic>;
        final fetched = list.map((item) => PatientModel.fromJson(item as Map<String, dynamic>)).toList();
        if (query == null || query.isEmpty) {
          _localPatients.clear();
          _localPatients.addAll(fetched);
          await _saveCache();
        }
        return _filterPatients(fetched, query);
      }
    } catch (_) {}

    return _filterPatients(_localPatients, query);
  }

  void _syncPatientsFromCloud(String? query) {
    Future.microtask(() async {
      try {
        final supaList = await SupabaseService.fetchPatients();
        if (supaList.isNotEmpty) {
          final existingIds = _localPatients.map((p) => p.id).toSet();
          final existingUhids = _localPatients.map((p) => p.uhid).toSet();
          bool hasNew = false;
          for (final sp in supaList) {
            if (!existingIds.contains(sp.id) && !existingUhids.contains(sp.uhid)) {
              _localPatients.add(sp);
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
            ApiEndpoints.patients,
            queryParameters: query != null && query.isNotEmpty ? {'query': query} : null,
          );

          final dynamic raw = res.data is String ? jsonDecode(res.data as String) : res.data;
          if (raw is Map && raw['status'] == 'success') {
            final list = raw['data'] as List<dynamic>;
            final fetched = list.map((item) => PatientModel.fromJson(item as Map<String, dynamic>)).toList();
            if (query == null || query.isEmpty) {
              final existingIds = _localPatients.map((p) => p.id).toSet();
              bool hasNew = false;
              for (final p in fetched) {
                if (!existingIds.contains(p.id)) {
                  _localPatients.add(p);
                  hasNew = true;
                }
              }
              if (hasNew) {
                await _saveCache();
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  List<PatientModel> _filterPatients(List<PatientModel> source, String? query) {
    if (query == null || query.trim().isEmpty) {
      return List.unmodifiable(source);
    }

    final q = query.toLowerCase().trim();
    final tokenMatch = RegExp(r'^(?:token|tok|queue|opd|t|#|\s)*(\d{1,4})$').firstMatch(q);
    final queryNum = tokenMatch != null ? int.tryParse(tokenMatch.group(1)!) : (int.tryParse(q));

    final Set<String> matchingVisitPatientIds = {};
    for (final v in VisitRepository.cachedVisits) {
      final t = v.queueToken;
      final numStr = v.visitNumber.toLowerCase();
      if ((queryNum != null && t == queryNum) || numStr.contains(q)) {
        matchingVisitPatientIds.add(v.patientId);
      }
    }

    return source.where((p) =>
      p.fullName.toLowerCase().contains(q) ||
      p.uhid.toLowerCase().contains(q) ||
      (p.hospitalRegNum != null && p.hospitalRegNum!.toLowerCase().contains(q)) ||
      (p.barcodeValue != null && p.barcodeValue!.toLowerCase().contains(q)) ||
      (q.length >= 4 && p.phone.contains(q)) ||
      matchingVisitPatientIds.contains(p.id)
    ).toList();
  }

  Future<DuplicateCheckResult> checkDuplicates({
    required String phone,
    String? fullName,
    String? hospitalRegNum,
  }) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.checkDuplicate,
        data: {
          'phone': phone,
          if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
          if (hospitalRegNum != null && hospitalRegNum.isNotEmpty) 'hospital_reg_num': hospitalRegNum,
        },
      );
      if (res.data['status'] == 'success') {
        return DuplicateCheckResult.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // Local check fallback
    final candidates = <DuplicateCandidateModel>[];
    for (final p in _localPatients) {
      if (hospitalRegNum != null && p.hospitalRegNum == hospitalRegNum) {
        candidates.add(DuplicateCandidateModel(
          id: p.id,
          uhid: p.uhid,
          hospitalRegNum: p.hospitalRegNum,
          fullName: p.fullName,
          phone: p.phone,
          gender: p.gender,
          ageYears: p.ageYears,
          parentSpouseName: p.parentSpouseName,
          matchReason: 'Identical Hospital Reg No',
        ));
      } else if (p.phone == phone) {
        final isNameMatch = fullName != null && p.fullName.toLowerCase() == fullName.toLowerCase();
        candidates.add(DuplicateCandidateModel(
          id: p.id,
          uhid: p.uhid,
          hospitalRegNum: p.hospitalRegNum,
          fullName: p.fullName,
          phone: p.phone,
          gender: p.gender,
          ageYears: p.ageYears,
          parentSpouseName: p.parentSpouseName,
          matchReason: isNameMatch
              ? 'Identical Phone Number and Matching Full Name'
              : 'Identical Contact Phone Number',
        ));
      }
    }

    return DuplicateCheckResult(
      isDuplicate: candidates.isNotEmpty,
      candidates: candidates,
      message: candidates.isNotEmpty
          ? 'Found ${candidates.length} potential duplicate record(s).'
          : 'No existing duplicate records found.',
    );
  }

  Future<PatientModel> registerPatient(PatientModel patient, {bool allowDuplicate = false}) async {
    await _loadCacheIfNeeded();

    final cleanPhone = patient.phone.trim();
    final cleanEmail = patient.email?.trim().toLowerCase();

    // 1. Strict duplicate check against existing patients in local cache
    for (final p in _localPatients) {
      if (cleanPhone.isNotEmpty && p.phone.trim() == cleanPhone) {
        throw Exception(
          'A patient with mobile number "$cleanPhone" is already registered in the hospital database (UHID: ${p.uhid}, Name: ${p.fullName}). Duplicate mobile numbers are not allowed.',
        );
      }
      if (cleanEmail != null && cleanEmail.isNotEmpty && p.email != null && p.email!.trim().toLowerCase() == cleanEmail) {
        throw Exception(
          'A patient with email address "$cleanEmail" is already registered in the hospital database (UHID: ${p.uhid}, Name: ${p.fullName}). Duplicate emails are not allowed.',
        );
      }
    }

    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.patients,
        queryParameters: {'allow_duplicate': allowDuplicate},
        data: patient.toJson(),
      );

      if (res.data['status'] == 'success') {
        final registered = PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _localPatients.removeWhere((p) => p.id == registered.id || p.uhid == registered.uhid);
        _localPatients.insert(0, registered);
        await _saveCache();
        SupabaseService.upsertPatient(registered).catchError((_) => false);
        return registered;
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response!.data['message'] ?? e.response!.data['detail'];
        final strMsg = msg?.toString() ?? '';
        // If it's a duplicate warning, preserve and throw so the UI duplicate dialog opens
        if (strMsg.contains('Accidental duplicate prevented') || strMsg.contains('duplicate')) {
          throw Exception(strMsg);
        }

        // If it's token expired or 401, attempt automatic token refresh and retry
        if (e.response?.statusCode == 401 || strMsg.toLowerCase().contains('token expired')) {
          final refreshed = await _dioClient.attemptTokenRefresh();
          if (refreshed) {
            try {
              final retryRes = await _dioClient.dio.post(
                ApiEndpoints.patients,
                queryParameters: {'allow_duplicate': allowDuplicate},
                data: patient.toJson(),
              );
              if (retryRes.data['status'] == 'success') {
                final registered = PatientModel.fromJson(retryRes.data['data'] as Map<String, dynamic>);
                _localPatients.insert(0, registered);
                await _saveCache();
                SupabaseService.upsertPatient(registered).catchError((_) => false);
                return registered;
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    int maxUhidNum = 0;
    for (final p in _localPatients) {
      if (p.uhid.startsWith('UHID-2026-')) {
        final numPart = int.tryParse(p.uhid.substring('UHID-2026-'.length));
        if (numPart != null && numPart > maxUhidNum) {
          maxUhidNum = numPart;
        }
      }
    }
    final nextUhidNum = maxUhidNum + 1;
    final generatedUhid = 'UHID-2026-${nextUhidNum.toString().padLeft(5, '0')}';
    final generatedReg = 'REG-2026-${nextUhidNum.toString().padLeft(5, '0')}';
    final newPat = PatientModel(
      id: patient.id.isNotEmpty ? patient.id : 'pat-${DateTime.now().millisecondsSinceEpoch}',
      uhid: patient.uhid.isNotEmpty ? patient.uhid : generatedUhid,
      hospitalRegNum: patient.hospitalRegNum ?? generatedReg,
      fullName: patient.fullName,
      parentSpouseName: patient.parentSpouseName,
      parentSpouseRelation: patient.parentSpouseRelation,
      dateOfBirth: patient.dateOfBirth,
      ageYears: patient.ageYears,
      ageMonths: patient.ageMonths,
      gender: patient.gender,
      phone: patient.phone,
      email: patient.email,
      address: patient.address,
      city: patient.city,
      state: patient.state,
      postalCode: patient.postalCode,
      bloodGroup: patient.bloodGroup,
      barcodeValue: 'BAR-$generatedUhid',
      qrCodeData: 'OPDCONNECT+$generatedUhid+$generatedReg',
      emergencyContactName: patient.emergencyContactName,
      emergencyContactPhone: patient.emergencyContactPhone,
      emergencyContactRelation: patient.emergencyContactRelation,
      registrationDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    _localPatients.insert(0, newPat);
    await _saveCache();
    // Persist directly to Supabase PostgreSQL so all physical devices see this immediately
    SupabaseService.upsertPatient(newPat).catchError((_) => false);
    return newPat;
  }

  Future<PatientModel?> getPatientById(String patientId) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.patientById(patientId));
      final dynamic raw = res.data is String ? jsonDecode(res.data as String) : res.data;
      if (raw is Map && raw['status'] == 'success') {
        return PatientModel.fromJson(raw['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    await _loadCacheIfNeeded();
    return _localPatients.cast<PatientModel?>().firstWhere(
      (p) => p?.id == patientId || p?.uhid == patientId,
      orElse: () => null,
    );
  }

  Future<PatientModel?> getPatientByReg(String regNum) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.patientByReg(regNum));
      if (res.data['status'] == 'success') {
        return PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return _localPatients.cast<PatientModel?>().firstWhere(
      (p) => p?.hospitalRegNum == regNum,
      orElse: () => null,
    );
  }

  Future<PatientModel?> getPatientByBarcode(String barcode) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.patientByBarcode(barcode));
      if (res.data['status'] == 'success') {
        return PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return _localPatients.cast<PatientModel?>().firstWhere(
      (p) => p?.barcodeValue == barcode,
      orElse: () => null,
    );
  }

  Future<PatientModel> updatePatient(PatientModel patient) async {
    try {
      final res = await _dioClient.dio.put(
        ApiEndpoints.patientById(patient.id),
        data: patient.toJson(),
      );
      if (res.data['status'] == 'success') {
        final updated = PatientModel.fromJson(res.data['data'] as Map<String, dynamic>);
        final idx = _localPatients.indexWhere((p) => p.id == patient.id);
        if (idx != -1) {
          _localPatients[idx] = updated;
          await _saveCache();
        }
        return updated;
      }
    } catch (_) {}

    await _loadCacheIfNeeded();
    final idx = _localPatients.indexWhere((p) => p.id == patient.id);
    if (idx != -1) {
      _localPatients[idx] = patient;
    } else {
      _localPatients.insert(0, patient);
    }
    await _saveCache();
    return patient;
  }

  Future<void> deletePatient(String patientId) async {
    try {
      await _dioClient.dio.delete(ApiEndpoints.patientById(patientId));
    } catch (_) {}

    await _loadCacheIfNeeded();
    _localPatients.removeWhere((p) => p.id == patientId);
    await _saveCache();
  }

  Future<List<int>> downloadBookletByRegId(String regId) async {
    final res = await _dioClient.dio.get<List<int>>(
      ApiEndpoints.patientDownloadByReg(regId),
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? [];
  }
}
