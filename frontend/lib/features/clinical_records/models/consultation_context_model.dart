class PreviousVisitSummaryModel {
  final String id;
  final String visitNumber;
  final DateTime visitDate;
  final String? doctorName;
  final String? departmentName;
  final String? provisionalDiagnosis;
  final String? finalDiagnosis;
  final String? chiefComplaint;
  final String status;

  PreviousVisitSummaryModel({
    required this.id,
    required this.visitNumber,
    required this.visitDate,
    this.doctorName,
    this.departmentName,
    this.provisionalDiagnosis,
    this.finalDiagnosis,
    this.chiefComplaint,
    this.status = 'COMPLETED',
  });

  factory PreviousVisitSummaryModel.fromJson(Map<String, dynamic> json) {
    return PreviousVisitSummaryModel(
      id: json['id'] ?? '',
      visitNumber: json['visit_number'] ?? '',
      visitDate: DateTime.tryParse(json['visit_date'] ?? '') ?? DateTime.now(),
      doctorName: json['doctor_name'],
      departmentName: json['department_name'],
      provisionalDiagnosis: json['provisional_diagnosis'],
      finalDiagnosis: json['final_diagnosis'],
      chiefComplaint: json['chief_complaint'],
      status: json['status'] ?? 'COMPLETED',
    );
  }
}

class PatientMedicalHistorySummaryModel {
  final String? allergies;
  final String? pastMedicalHistory;
  final String? priorHospitalization;
  final String? hypertensionHistory;
  final String? diabetesHistory;
  final String? asthmaHistory;
  final String? tuberculosisHistory;
  final String? smokingHistory;
  final String? alcoholHistory;
  final String? familyHistory;

  PatientMedicalHistorySummaryModel({
    this.allergies,
    this.pastMedicalHistory,
    this.priorHospitalization,
    this.hypertensionHistory,
    this.diabetesHistory,
    this.asthmaHistory,
    this.tuberculosisHistory,
    this.smokingHistory,
    this.alcoholHistory,
    this.familyHistory,
  });

  factory PatientMedicalHistorySummaryModel.fromJson(Map<String, dynamic> json) {
    return PatientMedicalHistorySummaryModel(
      allergies: json['allergies'],
      pastMedicalHistory: json['past_medical_history'],
      priorHospitalization: json['prior_hospitalization'],
      hypertensionHistory: json['hypertension_history'],
      diabetesHistory: json['diabetes_history'],
      asthmaHistory: json['asthma_history'],
      tuberculosisHistory: json['tuberculosis_history'],
      smokingHistory: json['smoking_history'],
      alcoholHistory: json['alcohol_history'],
      familyHistory: json['family_history'],
    );
  }
}

class ConsultationContextModel {
  final Map<String, dynamic> visit;
  final Map<String, dynamic> patient;
  final PatientMedicalHistorySummaryModel medicalHistory;
  final List<PreviousVisitSummaryModel> previousVisits;
  final List<Map<String, dynamic>> availableInvestigations;
  final List<Map<String, dynamic>> activePrescriptions;
  final Map<String, dynamic>? clinicalRecord;

  ConsultationContextModel({
    required this.visit,
    required this.patient,
    required this.medicalHistory,
    required this.previousVisits,
    required this.availableInvestigations,
    required this.activePrescriptions,
    this.clinicalRecord,
  });

  factory ConsultationContextModel.fromJson(Map<String, dynamic> json) {
    return ConsultationContextModel(
      visit: json['visit'] is Map<String, dynamic> ? json['visit'] : {},
      patient: json['patient'] is Map<String, dynamic> ? json['patient'] : {},
      medicalHistory: PatientMedicalHistorySummaryModel.fromJson(
        json['medical_history'] is Map<String, dynamic> ? json['medical_history'] : {},
      ),
      previousVisits: (json['previous_visits'] as List<dynamic>? ?? [])
          .map((v) => PreviousVisitSummaryModel.fromJson(v as Map<String, dynamic>))
          .toList(),
      availableInvestigations: (json['available_investigations'] as List<dynamic>? ?? [])
          .map((i) => i as Map<String, dynamic>)
          .toList(),
      activePrescriptions: (json['active_prescriptions'] as List<dynamic>? ?? [])
          .map((p) => p as Map<String, dynamic>)
          .toList(),
      clinicalRecord: json['clinical_record'] is Map<String, dynamic> ? json['clinical_record'] : null,
    );
  }
}
