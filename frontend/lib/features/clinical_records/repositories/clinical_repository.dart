import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/clinical_record_model.dart';

class ClinicalRepository {
  final DioClient _dioClient;

  // Local offline record cache
  final Map<String, ClinicalRecordModel> _localRecords = {};

  ClinicalRepository(this._dioClient);

  Future<ClinicalRecordModel?> getRecordByVisit(String visitId) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.clinicalRecordByVisit(visitId));
      if (res.data['status'] == 'success') {
        return ClinicalRecordModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    return _localRecords[visitId];
  }

  Future<ClinicalRecordModel> saveRecord(ClinicalRecordModel record) async {
    try {
      final res = await _dioClient.dio.post(
        ApiEndpoints.clinicalRecords,
        data: record.toJson(),
      );
      if (res.data['status'] == 'success') {
        final saved = ClinicalRecordModel.fromJson(res.data['data'] as Map<String, dynamic>);
        _localRecords[record.visitId] = saved;
        return saved;
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response!.data['message'] ?? e.response!.data['detail'];
        if (msg != null) throw Exception(msg.toString());
      }
      rethrow;
    } catch (_) {}

    // Fallback local save
    _localRecords[record.visitId] = record;
    return record;
  }

  Future<ClinicalRecordModel> signRecord(String recordId) async {
    try {
      final res = await _dioClient.dio.post(ApiEndpoints.signClinicalRecord(recordId));
      if (res.data['status'] == 'success') {
        return ClinicalRecordModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response!.data['message'] ?? e.response!.data['detail'];
        if (msg != null) throw Exception(msg.toString());
      }
      rethrow;
    } catch (_) {}

    // Fallback local sign
    for (final entry in _localRecords.entries) {
      if (entry.value.id == recordId || entry.key == recordId) {
        final signed = ClinicalRecordModel(
          id: entry.value.id,
          visitId: entry.value.visitId,
          patientId: entry.value.patientId,
          doctorId: entry.value.doctorId,
          presentingComplaint: entry.value.presentingComplaint,
          historyOfPresentIllness: entry.value.historyOfPresentIllness,
          allergies: entry.value.allergies,
          pastMedicalHistory: entry.value.pastMedicalHistory,
          priorHospitalization: entry.value.priorHospitalization,
          hypertensionHistory: entry.value.hypertensionHistory,
          diabetesHistory: entry.value.diabetesHistory,
          asthmaHistory: entry.value.asthmaHistory,
          tuberculosisHistory: entry.value.tuberculosisHistory,
          smokingHistory: entry.value.smokingHistory,
          alcoholHistory: entry.value.alcoholHistory,
          familyHistory: entry.value.familyHistory,
          generalExamination: entry.value.generalExamination,
          respiratoryExamination: entry.value.respiratoryExamination,
          cardiovascularExamination: entry.value.cardiovascularExamination,
          gastrointestinalExamination: entry.value.gastrointestinalExamination,
          cnsExamination: entry.value.cnsExamination,
          otherExaminationFindings: entry.value.otherExaminationFindings,
          provisionalDiagnosis: entry.value.provisionalDiagnosis,
          finalDiagnosis: entry.value.finalDiagnosis,
          icd10Code: entry.value.icd10Code,
          carePlan: entry.value.carePlan,
          investigationsRequested: entry.value.investigationsRequested,
          dietaryAdvice: entry.value.dietaryAdvice,
          followUpDate: entry.value.followUpDate,
          referralDepartment: entry.value.referralDepartment,
          status: 'FINALIZED',
          version: entry.value.version,
          signedAt: DateTime.now(),
        );
        _localRecords[entry.key] = signed;
        return signed;
      }
    }
    throw Exception('Record not found to sign');
  }

  Future<ClinicalRecordModel> amendRecord(
    String recordId, {
    required String reason,
    required Map<String, dynamic> updateFields,
  }) async {
    try {
      final payload = Map<String, dynamic>.from(updateFields);
      payload['amendment_reason'] = reason;

      final res = await _dioClient.dio.post(
        ApiEndpoints.amendClinicalRecord(recordId),
        data: payload,
      );
      if (res.data['status'] == 'success') {
        return ClinicalRecordModel.fromJson(res.data['data'] as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map) {
        final msg = e.response!.data['message'] ?? e.response!.data['detail'];
        if (msg != null) throw Exception(msg.toString());
      }
      rethrow;
    } catch (_) {}

    // Fallback local amend
    for (final entry in _localRecords.entries) {
      if (entry.value.id == recordId || entry.key == recordId) {
        final current = entry.value;
        final amendment = ClinicalAmendmentModel(
          id: 'amend-${DateTime.now().millisecondsSinceEpoch}',
          clinicalRecordId: current.id,
          amendedByUserId: 'current-doctor',
          amendedAt: DateTime.now(),
          reason: reason,
          previousSnapshotJson: '{"version": ${current.version}, "status": "${current.status}"}',
        );

        final amended = ClinicalRecordModel(
          id: current.id,
          visitId: current.visitId,
          patientId: current.patientId,
          doctorId: current.doctorId,
          presentingComplaint: updateFields['presenting_complaint'] as String? ?? current.presentingComplaint,
          historyOfPresentIllness: updateFields['history_of_present_illness'] as String? ?? current.historyOfPresentIllness,
          allergies: updateFields['allergies'] as String? ?? current.allergies,
          pastMedicalHistory: updateFields['past_medical_history'] as String? ?? current.pastMedicalHistory,
          priorHospitalization: updateFields['prior_hospitalization'] as String? ?? current.priorHospitalization,
          hypertensionHistory: updateFields['hypertension_history'] as String? ?? current.hypertensionHistory,
          diabetesHistory: updateFields['diabetes_history'] as String? ?? current.diabetesHistory,
          asthmaHistory: updateFields['asthma_history'] as String? ?? current.asthmaHistory,
          tuberculosisHistory: updateFields['tuberculosis_history'] as String? ?? current.tuberculosisHistory,
          smokingHistory: updateFields['smoking_history'] as String? ?? current.smokingHistory,
          alcoholHistory: updateFields['alcohol_history'] as String? ?? current.alcoholHistory,
          familyHistory: updateFields['family_history'] as String? ?? current.familyHistory,
          generalExamination: updateFields['general_examination'] as String? ?? current.generalExamination,
          respiratoryExamination: updateFields['respiratory_examination'] as String? ?? current.respiratoryExamination,
          cardiovascularExamination: updateFields['cardiovascular_examination'] as String? ?? current.cardiovascularExamination,
          gastrointestinalExamination: updateFields['gastrointestinal_examination'] as String? ?? current.gastrointestinalExamination,
          cnsExamination: updateFields['cns_examination'] as String? ?? current.cnsExamination,
          otherExaminationFindings: updateFields['other_examination_findings'] as String? ?? current.otherExaminationFindings,
          provisionalDiagnosis: updateFields['provisional_diagnosis'] as String? ?? current.provisionalDiagnosis,
          finalDiagnosis: updateFields['final_diagnosis'] as String? ?? current.finalDiagnosis,
          icd10Code: updateFields['icd10_code'] as String? ?? current.icd10Code,
          carePlan: updateFields['care_plan'] as String? ?? current.carePlan,
          investigationsRequested: updateFields['investigations_requested'] as String? ?? current.investigationsRequested,
          dietaryAdvice: updateFields['dietary_advice'] as String? ?? current.dietaryAdvice,
          followUpDate: updateFields['follow_up_date'] as String? ?? current.followUpDate,
          referralDepartment: updateFields['referral_department'] as String? ?? current.referralDepartment,
          status: 'AMENDED',
          version: current.version + 1,
          amendmentReason: reason,
          signedAt: current.signedAt,
          amendments: [amendment, ...current.amendments],
        );
        _localRecords[entry.key] = amended;
        return amended;
      }
    }
    throw Exception('Record not found to amend');
  }

  Future<List<ClinicalAmendmentModel>> getAmendments(String recordId) async {
    try {
      final res = await _dioClient.dio.get(ApiEndpoints.clinicalAmendments(recordId));
      if (res.data['status'] == 'success') {
        final list = res.data['data'] as List<dynamic>;
        return list.map((item) => ClinicalAmendmentModel.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (_) {}

    return [];
  }
}
