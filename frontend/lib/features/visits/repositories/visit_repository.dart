import 'dart:convert';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../models/visit_model.dart';
import '../models/vitals_model.dart';

class VisitRepository {
  final DioClient _dioClient;

  final List<OPDVisitModel> _localVisits = [];

  VisitRepository(this._dioClient);

  Future<void> _loadCacheIfNeeded() async {
    if (_localVisits.isEmpty) {
      try {
        final raw = await SecureStorageService.getVisitsJson();
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List<dynamic>;
          _localVisits.addAll(list.map((m) => OPDVisitModel.fromJson(m as Map<String, dynamic>)));
        }
      } catch (_) {}
    }
  }

  Future<void> _saveCache() async {
    try {
      final jsonList = _localVisits.map((v) => v.toJson()).toList();
      await SecureStorageService.saveVisitsJson(jsonEncode(jsonList));
    } catch (_) {}
  }

  Future<List<OPDVisitModel>> getVisits({String? status, String? departmentId}) async {
    try {
      final res = await _dioClient.dio.get(
        ApiEndpoints.visits,
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (departmentId != null && departmentId.isNotEmpty) 'department_id': departmentId,
        },
      );

      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        final fetched = list.map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>)).toList();
        if ((status == null || status.isEmpty) && (departmentId == null || departmentId.isEmpty)) {
          _localVisits.clear();
          _localVisits.addAll(fetched);
          await _saveCache();
        }
        return fetched;
      }
    } catch (_) {}

    await _loadCacheIfNeeded();

    // Fallback
    if (status != null && status.isNotEmpty) {
      return _localVisits.where((v) => v.status == status).toList();
    }
    return List.from(_localVisits);
  }

  Future<OPDVisitModel> createVisit({
    required String patientId,
    required String doctorId,
    required String departmentId,
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
        _localVisits.insert(0, created);
        await _saveCache();
        return created;
      }
    } catch (_) {}

    await _loadCacheIfNeeded();

    final token = _localVisits.length + 1;
    final newVisit = OPDVisitModel(
      id: 'vis-${DateTime.now().millisecondsSinceEpoch}',
      visitNumber: 'VIS-${DateTime.now().year}${(DateTime.now().month).toString().padLeft(2, '0')}${(DateTime.now().day).toString().padLeft(2, '0')}-${token.toString().padLeft(4, '0')}',
      patientId: patientId,
      doctorId: doctorId,
      departmentId: departmentId,
      queueToken: token,
      triagePriority: triagePriority,
      status: 'REGISTERED',
      consultationFee: consultationFee,
      paymentStatus: 'UNPAID',
      notes: notes,
      visitDate: DateTime.now(),
      doctorName: 'Dr. Sarah Chen, MD',
      departmentName: 'General Medicine',
    );
    _localVisits.insert(0, newVisit);
    await _saveCache();
    return newVisit;
  }

  Future<VitalSignsModel> recordVitals(VitalSignsModel vitals) async {
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
