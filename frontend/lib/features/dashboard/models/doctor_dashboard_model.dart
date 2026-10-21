import '../../visits/models/visit_model.dart';

class DoctorDashboardStatsModel {
  final int todayAppointments;
  final int waitingPatients;
  final int underConsultation;
  final int completedConsultations;
  final int pendingInvestigations;
  final int followUpAppointments;

  DoctorDashboardStatsModel({
    this.todayAppointments = 0,
    this.waitingPatients = 0,
    this.underConsultation = 0,
    this.completedConsultations = 0,
    this.pendingInvestigations = 0,
    this.followUpAppointments = 0,
  });

  factory DoctorDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return DoctorDashboardStatsModel(
      todayAppointments: json['today_appointments'] as int? ?? 0,
      waitingPatients: json['waiting_patients'] as int? ?? 0,
      underConsultation: json['under_consultation'] as int? ?? 0,
      completedConsultations: json['completed_consultations'] as int? ?? 0,
      pendingInvestigations: json['pending_investigations'] as int? ?? 0,
      followUpAppointments: json['follow_up_appointments'] as int? ?? 0,
    );
  }
}

class PendingInvestigationModel {
  final String id;
  final String testName;
  final String testCategory;
  final String status;
  final String patientId;
  final String patientName;
  final String uhid;
  final String visitId;
  final String visitNumber;
  final String? createdAt;
  final String? clinicalIndication;

  PendingInvestigationModel({
    required this.id,
    required this.testName,
    required this.testCategory,
    required this.status,
    required this.patientId,
    required this.patientName,
    required this.uhid,
    required this.visitId,
    required this.visitNumber,
    this.createdAt,
    this.clinicalIndication,
  });

  factory PendingInvestigationModel.fromJson(Map<String, dynamic> json) {
    return PendingInvestigationModel(
      id: json['id'] as String? ?? '',
      testName: json['test_name'] as String? ?? '',
      testCategory: json['test_category'] as String? ?? '',
      status: json['status'] as String? ?? 'ORDERED',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? 'Unknown',
      uhid: json['uhid'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      visitNumber: json['visit_number'] as String? ?? '',
      createdAt: json['created_at'] as String?,
      clinicalIndication: json['clinical_indication'] as String?,
    );
  }
}

class FollowUpAppointmentModel {
  final String patientId;
  final String patientName;
  final String uhid;
  final String visitId;
  final String followUpDate;
  final String? finalDiagnosis;
  final String? carePlan;

  FollowUpAppointmentModel({
    required this.patientId,
    required this.patientName,
    required this.uhid,
    required this.visitId,
    required this.followUpDate,
    this.finalDiagnosis,
    this.carePlan,
  });

  factory FollowUpAppointmentModel.fromJson(Map<String, dynamic> json) {
    return FollowUpAppointmentModel(
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      followUpDate: json['follow_up_date'] as String? ?? '',
      finalDiagnosis: json['final_diagnosis'] as String?,
      carePlan: json['care_plan'] as String?,
    );
  }
}

class RecentAuthorizedPatientModel {
  final String patientId;
  final String uhid;
  final String fullName;
  final String ageDisplay;
  final String gender;
  final String phoneNumber;
  final String? lastVisitDate;
  final String? lastDiagnosis;

  RecentAuthorizedPatientModel({
    required this.patientId,
    required this.uhid,
    required this.fullName,
    required this.ageDisplay,
    required this.gender,
    required this.phoneNumber,
    this.lastVisitDate,
    this.lastDiagnosis,
  });

  factory RecentAuthorizedPatientModel.fromJson(Map<String, dynamic> json) {
    return RecentAuthorizedPatientModel(
      patientId: json['patient_id'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      ageDisplay: json['age_display'] as String? ?? '',
      gender: json['gender'] as String? ?? 'UNKNOWN',
      phoneNumber: json['phone_number'] as String? ?? '',
      lastVisitDate: json['last_visit_date'] as String?,
      lastDiagnosis: json['last_diagnosis'] as String?,
    );
  }
}

class DoctorDashboardModel {
  final DoctorDashboardStatsModel stats;
  final List<OPDVisitModel> todayAppointments;
  final List<OPDVisitModel> waitingPatients;
  final List<OPDVisitModel> underConsultation;
  final List<OPDVisitModel> completedConsultations;
  final List<PendingInvestigationModel> pendingInvestigations;
  final List<FollowUpAppointmentModel> followUpAppointments;
  final List<RecentAuthorizedPatientModel> recentAuthorizedPatients;

  DoctorDashboardModel({
    required this.stats,
    this.todayAppointments = const [],
    this.waitingPatients = const [],
    this.underConsultation = const [],
    this.completedConsultations = const [],
    this.pendingInvestigations = const [],
    this.followUpAppointments = const [],
    this.recentAuthorizedPatients = const [],
  });

  factory DoctorDashboardModel.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] != null
        ? DoctorDashboardStatsModel.fromJson(json['stats'] as Map<String, dynamic>)
        : DoctorDashboardStatsModel();

    List<OPDVisitModel> parseVisits(dynamic raw) {
      if (raw == null || raw is! List) return [];
      return raw.map((e) => OPDVisitModel.fromJson(e as Map<String, dynamic>)).toList();
    }

    final todayAppts = parseVisits(json['today_appointments']);
    final waiting = parseVisits(json['waiting_patients']);
    final underConsult = parseVisits(json['under_consultation']);
    final completed = parseVisits(json['completed_consultations']);

    final rawLabs = json['pending_investigations'] as List<dynamic>? ?? [];
    final pendingLabs = rawLabs
        .map((e) => PendingInvestigationModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawFollowUps = json['follow_up_appointments'] as List<dynamic>? ?? [];
    final followUps = rawFollowUps
        .map((e) => FollowUpAppointmentModel.fromJson(e as Map<String, dynamic>))
        .toList();

    final rawRecent = json['recent_authorized_patients'] as List<dynamic>? ?? [];
    final recentPatients = rawRecent
        .map((e) => RecentAuthorizedPatientModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return DoctorDashboardModel(
      stats: stats,
      todayAppointments: todayAppts,
      waitingPatients: waiting,
      underConsultation: underConsult,
      completedConsultations: completed,
      pendingInvestigations: pendingLabs,
      followUpAppointments: followUps,
      recentAuthorizedPatients: recentPatients,
    );
  }
}
