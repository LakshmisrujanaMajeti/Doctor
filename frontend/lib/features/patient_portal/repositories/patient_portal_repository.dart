import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/patient_portal_models.dart';

class PatientPortalRepository {
  final DioClient _dioClient;

  PatientPortalRepository(this._dioClient);

  Future<PatientPortalProfile> getProfile() async {
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalProfile);
    return PatientPortalProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<DependentProfile> addDependent({
    required String fullName,
    required String relation,
    required String gender,
    int? ageYears,
    int? ageMonths,
    String? bloodGroup,
    String? emergencyContactPhone,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.patientPortalDependents,
      data: {
        'full_name': fullName,
        'relation': relation,
        'gender': gender,
        'age_years': ageYears,
        'age_months': ageMonths,
        'blood_group': bloodGroup,
        'emergency_contact_phone': emergencyContactPhone,
      },
    );
    return DependentProfile.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DependentProfile>> getDependents() async {
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalDependents);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((d) => DependentProfile.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getVisits({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalVisits, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<UpcomingAppointment>> getAppointments({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalAppointments, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((a) => UpcomingAppointment.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<List<PatientPrescriptionSummaryItem>> getPrescriptions({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalPrescriptions, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((p) => PatientPrescriptionSummaryItem.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<List<PatientLabReportSummary>> getLabReports({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalLabReports, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((r) => PatientLabReportSummary.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<Map<String, dynamic>>> getDocuments({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalDocuments, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<List<PatientBillSummary>> getBills({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalBills, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((b) => PatientBillSummary.fromJson(b as Map<String, dynamic>)).toList();
  }

  Future<SupportTicketModel> createSupportTicket({
    required String subject,
    required String category,
    required String message,
    String priority = 'NORMAL',
    String? dependentPatientId,
  }) async {
    final response = await _dioClient.dio.post(
      ApiEndpoints.patientPortalSupport,
      data: {
        'subject': subject,
        'category': category,
        'priority': priority,
        'message': message,
        'dependent_patient_id': dependentPatientId,
      },
    );
    return SupportTicketModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<SupportTicketModel>> getSupportTickets({String? patientId}) async {
    final query = patientId != null ? {'patient_id': patientId} : null;
    final response = await _dioClient.dio.get(ApiEndpoints.patientPortalSupport, queryParameters: query);
    final list = (response.data['data'] as List?) ?? [];
    return list.map((t) => SupportTicketModel.fromJson(t as Map<String, dynamic>)).toList();
  }
}
