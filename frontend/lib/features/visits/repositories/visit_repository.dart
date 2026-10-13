import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/visit_model.dart';
import '../models/vitals_model.dart';

class VisitRepository {
  final DioClient _dioClient;

  final List<OPDVisitModel> _localVisits = [
    OPDVisitModel(
      id: 'demo-vis-1',
      visitNumber: 'VIS-20261012-0001',
      patientId: 'demo-pat-1',
      doctorId: 'demo-doc-1',
      departmentId: 'dept-1',
      queueToken: 1,
      triagePriority: 'NORMAL',
      status: 'COMPLETED',
      consultationFee: 500.0,
      paymentStatus: 'PAID',
      visitDate: DateTime.now().subtract(const Duration(hours: 3)),
      doctorName: 'Dr. Sarah Chen, MD',
      departmentName: 'General Medicine',
      vitals: VitalSignsModel(
        id: 'vit-1',
        visitId: 'demo-vis-1',
        systolicBp: 128,
        diastolicBp: 82,
        pulseRate: 76,
        temperatureF: 98.6,
        spo2Percent: 99.0,
        respiratoryRate: 16,
        weightKg: 74.5,
        heightCm: 175.0,
        bmi: 24.3,
      ),
    ),
    OPDVisitModel(
      id: 'demo-vis-2',
      visitNumber: 'VIS-20261012-0002',
      patientId: 'demo-pat-2',
      doctorId: 'demo-doc-1',
      departmentId: 'dept-1',
      queueToken: 2,
      triagePriority: 'PRIORITY',
      status: 'TRIAGED',
      consultationFee: 500.0,
      paymentStatus: 'PAID',
      visitDate: DateTime.now().subtract(const Duration(hours: 1)),
      doctorName: 'Dr. Sarah Chen, MD',
      departmentName: 'General Medicine',
      vitals: VitalSignsModel(
        id: 'vit-2',
        visitId: 'demo-vis-2',
        systolicBp: 142,
        diastolicBp: 92,
        pulseRate: 88,
        temperatureF: 100.4,
        spo2Percent: 97.0,
        respiratoryRate: 18,
        weightKg: 62.0,
        heightCm: 160.0,
        bmi: 24.2,
      ),
    ),
    OPDVisitModel(
      id: 'demo-vis-3',
      visitNumber: 'VIS-20261012-0003',
      patientId: 'demo-pat-3',
      doctorId: 'demo-doc-1',
      departmentId: 'dept-1',
      queueToken: 3,
      triagePriority: 'EMERGENCY',
      status: 'REGISTERED',
      consultationFee: 500.0,
      paymentStatus: 'UNPAID',
      visitDate: DateTime.now(),
      doctorName: 'Dr. Sarah Chen, MD',
      departmentName: 'General Medicine',
    ),
  ];

  VisitRepository(this._dioClient);

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
        return list.map((item) => OPDVisitModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    // Fallback
    if (status != null && status.isNotEmpty) {
      return _localVisits.where((v) => v.status == status).toList();
    }
    return _localVisits;
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
        return OPDVisitModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    final token = _localVisits.length + 1;
    final newVisit = OPDVisitModel(
      id: 'demo-vis-$token',
      visitNumber: 'VIS-20261012-${token.toString().padLeft(4, '0')}',
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
    _localVisits.add(newVisit);
    return newVisit;
  }

  Future<VitalSignsModel> recordVitals(VitalSignsModel vitals) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.visitVitals(vitals.visitId),
        data: vitals.toJson(),
      );

      if (res.data['status'] == 'success') {
        return VitalSignsModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return vitals;
  }
}
