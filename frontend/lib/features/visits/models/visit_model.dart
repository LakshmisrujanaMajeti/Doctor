import '../models/vitals_model.dart';
import '../../patients/models/patient_model.dart';

class OPDVisitModel {
  final String id;
  final String visitNumber;
  final String patientId;
  final String doctorId;
  final String departmentId;
  final int queueToken;
  final String triagePriority; // NORMAL, PRIORITY, EMERGENCY
  final String status; // REGISTERED, TRIAGED, IN_CONSULTATION, COMPLETED, CANCELLED
  final double consultationFee;
  final String paymentStatus;
  final String? notes;
  final DateTime visitDate;
  final PatientModel? patient;
  final VitalSignsModel? vitals;
  final String? doctorName;
  final String? departmentName;

  OPDVisitModel({
    required this.id,
    required this.visitNumber,
    required this.patientId,
    required this.doctorId,
    required this.departmentId,
    required this.queueToken,
    required this.triagePriority,
    required this.status,
    required this.consultationFee,
    required this.paymentStatus,
    this.notes,
    required this.visitDate,
    this.patient,
    this.vitals,
    this.doctorName,
    this.departmentName,
  });

  factory OPDVisitModel.fromJson(Map<String, dynamic> json) {
    PatientModel? patientObj;
    if (json['patient'] != null && json['patient'] is Map) {
      patientObj = PatientModel.fromJson(json['patient']);
    }

    VitalSignsModel? vitalsObj;
    if (json['vitals'] != null && json['vitals'] is Map) {
      vitalsObj = VitalSignsModel.fromJson(json['vitals']);
    }

    String? docName;
    if (json['doctor'] != null && json['doctor'] is Map) {
      final docMap = json['doctor'];
      if (docMap['user'] != null && docMap['user'] is Map) {
        docName = docMap['user']['full_name'] as String?;
      } else {
        docName = docMap['qualification'] as String?;
      }
    }

    String? deptName;
    if (json['department'] != null && json['department'] is Map) {
      deptName = json['department']['name'] as String?;
    }

    return OPDVisitModel(
      id: json['id'] as String? ?? '',
      visitNumber: json['visit_number'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      departmentId: json['department_id'] as String? ?? '',
      queueToken: json['queue_token'] as int? ?? 0,
      triagePriority: json['triage_priority'] as String? ?? 'NORMAL',
      status: json['status'] as String? ?? 'REGISTERED',
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ?? 500.0,
      paymentStatus: json['payment_status'] as String? ?? 'UNPAID',
      notes: json['notes'] as String?,
      visitDate: json['visit_date'] != null
          ? DateTime.tryParse(json['visit_date']) ?? DateTime.now()
          : DateTime.now(),
      patient: patientObj,
      vitals: vitalsObj,
      doctorName: docName ?? 'Dr. Specialist',
      departmentName: deptName ?? 'General Medicine',
    );
  }

  Map<String, dynamic> toJson() => {
    'patient_id': patientId,
    'doctor_id': doctorId,
    'department_id': departmentId,
    'triage_priority': triagePriority,
    'consultation_fee': consultationFee,
    'notes': notes,
  };
}
