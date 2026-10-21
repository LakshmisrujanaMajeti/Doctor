class ClinicalAmendmentModel {
  final String id;
  final String clinicalRecordId;
  final String amendedByUserId;
  final DateTime amendedAt;
  final String reason;
  final String previousSnapshotJson;

  ClinicalAmendmentModel({
    required this.id,
    required this.clinicalRecordId,
    required this.amendedByUserId,
    required this.amendedAt,
    required this.reason,
    required this.previousSnapshotJson,
  });

  factory ClinicalAmendmentModel.fromJson(Map<String, dynamic> json) {
    return ClinicalAmendmentModel(
      id: json['id'] as String? ?? '',
      clinicalRecordId: json['clinical_record_id'] as String? ?? '',
      amendedByUserId: json['amended_by_user_id'] as String? ?? '',
      amendedAt: json['amended_at'] != null
          ? DateTime.tryParse(json['amended_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      reason: json['reason'] as String? ?? '',
      previousSnapshotJson: json['previous_snapshot_json'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'clinical_record_id': clinicalRecordId,
    'amended_by_user_id': amendedByUserId,
    'amended_at': amendedAt.toIso8601String(),
    'reason': reason,
    'previous_snapshot_json': previousSnapshotJson,
  };
}

class ClinicalRecordModel {
  final String id;
  final String visitId;
  final String patientId;
  final String doctorId;

  // 1. Initial Assessment
  final String presentingComplaint;
  final String? historyOfPresentIllness;
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

  // 2. Examination Findings
  final String? generalExamination;
  final String? respiratoryExamination;
  final String? cardiovascularExamination;
  final String? gastrointestinalExamination;
  final String? cnsExamination;
  final String? otherExaminationFindings;

  // 3. Clinical Plan & Diagnoses
  final String? provisionalDiagnosis;
  final String? finalDiagnosis;
  final String? icd10Code;
  final String? carePlan;
  final String? investigationsRequested;
  final String? dietaryAdvice;
  final String? followUpDate;
  final String? referralDepartment;

  // 4. Data Integrity & Authorship Audit
  final String status; // DRAFT, FINALIZED, AMENDED
  final int version;
  final String? createdByUserId;
  final String? updatedByUserId;
  final String? signedByUserId;
  final DateTime? signedAt;
  final String? amendmentReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ClinicalAmendmentModel> amendments;

  // Backward compatibility getters
  String get chiefComplaint => presentingComplaint;
  String? get pastHistory => pastMedicalHistory;
  String? get physicalExamination => otherExaminationFindings ?? generalExamination;
  String? get clinicalNotes => carePlan;

  ClinicalRecordModel({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.doctorId,
    required this.presentingComplaint,
    this.historyOfPresentIllness,
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
    this.generalExamination,
    this.respiratoryExamination,
    this.cardiovascularExamination,
    this.gastrointestinalExamination,
    this.cnsExamination,
    this.otherExaminationFindings,
    this.provisionalDiagnosis,
    this.finalDiagnosis,
    this.icd10Code,
    this.carePlan,
    this.investigationsRequested,
    this.dietaryAdvice,
    this.followUpDate,
    this.referralDepartment,
    this.status = 'DRAFT',
    this.version = 1,
    this.createdByUserId,
    this.updatedByUserId,
    this.signedByUserId,
    this.signedAt,
    this.amendmentReason,
    this.createdAt,
    this.updatedAt,
    this.amendments = const [],
  });

  factory ClinicalRecordModel.fromJson(Map<String, dynamic> json) {
    final complaint = json['presenting_complaint'] as String? ??
        json['chief_complaint'] as String? ??
        '';

    final amendmentsList = json['amendments'] as List<dynamic>? ?? [];

    return ClinicalRecordModel(
      id: json['id'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      presentingComplaint: complaint,
      historyOfPresentIllness: json['history_of_present_illness'] as String?,
      allergies: json['allergies'] as String?,
      pastMedicalHistory: json['past_medical_history'] as String? ??
          json['past_history'] as String?,
      priorHospitalization: json['prior_hospitalization'] as String?,
      hypertensionHistory: json['hypertension_history'] as String?,
      diabetesHistory: json['diabetes_history'] as String?,
      asthmaHistory: json['asthma_history'] as String?,
      tuberculosisHistory: json['tuberculosis_history'] as String?,
      smokingHistory: json['smoking_history'] as String?,
      alcoholHistory: json['alcohol_history'] as String?,
      familyHistory: json['family_history'] as String?,
      generalExamination: json['general_examination'] as String?,
      respiratoryExamination: json['respiratory_examination'] as String?,
      cardiovascularExamination: json['cardiovascular_examination'] as String?,
      gastrointestinalExamination: json['gastrointestinal_examination'] as String?,
      cnsExamination: json['cns_examination'] as String?,
      otherExaminationFindings: json['other_examination_findings'] as String? ??
          json['physical_examination'] as String?,
      provisionalDiagnosis: json['provisional_diagnosis'] as String?,
      finalDiagnosis: json['final_diagnosis'] as String?,
      icd10Code: json['icd10_code'] as String?,
      carePlan: json['care_plan'] as String? ??
          json['clinical_notes'] as String?,
      investigationsRequested: json['investigations_requested'] as String?,
      dietaryAdvice: json['dietary_advice'] as String?,
      followUpDate: json['follow_up_date'] as String?,
      referralDepartment: json['referral_department'] as String?,
      status: json['status'] as String? ?? 'DRAFT',
      version: json['version'] as int? ?? 1,
      createdByUserId: json['created_by_user_id'] as String?,
      updatedByUserId: json['updated_by_user_id'] as String?,
      signedByUserId: json['signed_by_user_id'] as String?,
      signedAt: json['signed_at'] != null ? DateTime.tryParse(json['signed_at'] as String) : null,
      amendmentReason: json['amendment_reason'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
      amendments: amendmentsList
          .map((a) => ClinicalAmendmentModel.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'visit_id': visitId,
    'presenting_complaint': presentingComplaint,
    'chief_complaint': presentingComplaint, // For backward compatibility
    if (historyOfPresentIllness != null) 'history_of_present_illness': historyOfPresentIllness,
    if (allergies != null) 'allergies': allergies,
    if (pastMedicalHistory != null) 'past_medical_history': pastMedicalHistory,
    if (pastMedicalHistory != null) 'past_history': pastMedicalHistory,
    if (priorHospitalization != null) 'prior_hospitalization': priorHospitalization,
    if (hypertensionHistory != null) 'hypertension_history': hypertensionHistory,
    if (diabetesHistory != null) 'diabetes_history': diabetesHistory,
    if (asthmaHistory != null) 'asthma_history': asthmaHistory,
    if (tuberculosisHistory != null) 'tuberculosis_history': tuberculosisHistory,
    if (smokingHistory != null) 'smoking_history': smokingHistory,
    if (alcoholHistory != null) 'alcohol_history': alcoholHistory,
    if (familyHistory != null) 'family_history': familyHistory,
    if (generalExamination != null) 'general_examination': generalExamination,
    if (respiratoryExamination != null) 'respiratory_examination': respiratoryExamination,
    if (cardiovascularExamination != null) 'cardiovascular_examination': cardiovascularExamination,
    if (gastrointestinalExamination != null) 'gastrointestinal_examination': gastrointestinalExamination,
    if (cnsExamination != null) 'cns_examination': cnsExamination,
    if (otherExaminationFindings != null) 'other_examination_findings': otherExaminationFindings,
    if (otherExaminationFindings != null) 'physical_examination': otherExaminationFindings,
    if (provisionalDiagnosis != null) 'provisional_diagnosis': provisionalDiagnosis,
    if (finalDiagnosis != null) 'final_diagnosis': finalDiagnosis,
    if (icd10Code != null) 'icd10_code': icd10Code,
    if (carePlan != null) 'care_plan': carePlan,
    if (carePlan != null) 'clinical_notes': carePlan,
    if (investigationsRequested != null) 'investigations_requested': investigationsRequested,
    if (dietaryAdvice != null) 'dietary_advice': dietaryAdvice,
    if (followUpDate != null) 'follow_up_date': followUpDate,
    if (referralDepartment != null) 'referral_department': referralDepartment,
    'status': status,
  };
}
