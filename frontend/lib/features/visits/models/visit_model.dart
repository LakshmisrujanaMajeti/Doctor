import '../models/vitals_model.dart';
import '../../patients/models/patient_model.dart';
import '../../patients/repositories/patient_repository.dart';
import '../../doctors/repositories/doctor_repository.dart';

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

  PatientModel? get effectivePatient {
    if (patient != null) return patient;
    if (patientId.isNotEmpty) {
      try {
        final matches = PatientRepository.cachedPatients.where((p) => p.id == patientId || p.uhid == patientId).toList();
        if (matches.isNotEmpty) return matches.first;
      } catch (_) {}
    }
    return null;
  }

  String get effectivePatientName {
    final ep = effectivePatient;
    if (ep != null && ep.fullName.trim().isNotEmpty && !ep.fullName.startsWith('Patient ')) {
      return ep.fullName;
    }
    return 'Patient $visitNumber';
  }

  String get effectivePatientUhid {
    final ep = effectivePatient;
    if (ep != null && ep.uhid.trim().isNotEmpty && ep.uhid != 'UHID Pending') {
      return ep.uhid;
    }
    return 'UHID Pending';
  }

  /// Formatted departmental OPD Token: `SMVMCH<DD><MM><YY><0001>`
  /// Ensures tokens never overlap across dates or departments
  String get formattedToken {
    if (visitNumber.toUpperCase().startsWith('SMVMCH')) {
      return visitNumber.toUpperCase();
    }
    final dd = visitDate.day.toString().padLeft(2, '0');
    final mm = visitDate.month.toString().padLeft(2, '0');
    final yy = (visitDate.year % 100).toString().padLeft(2, '0');
    final seq = queueToken > 0 ? queueToken.toString().padLeft(4, '0') : '0001';
    return 'SMVMCH$dd$mm$yy$seq';
  }

  factory OPDVisitModel.fromJson(Map<String, dynamic> json) {
    PatientModel? patientObj;
    if (json['patient'] != null && json['patient'] is Map) {
      patientObj = PatientModel.fromJson(json['patient']);
    }
    final rawPid = json['patient_id'] as String? ?? '';
    if (patientObj == null && rawPid.isNotEmpty) {
      try {
        final matches = PatientRepository.cachedPatients.where((p) => p.id == rawPid || p.uhid == rawPid).toList();
        if (matches.isNotEmpty) {
          patientObj = matches.first;
        }
      } catch (_) {}
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
      } else if (docMap['full_name'] != null) {
        docName = docMap['full_name'] as String?;
      } else if (docMap['name'] != null) {
        docName = docMap['name'] as String?;
      } else {
        docName = docMap['qualification'] as String?;
      }
    }
    if ((docName == null || docName.isEmpty) && json['doctor_name'] != null) {
      docName = json['doctor_name'] as String?;
    }

    final docId = json['doctor_id'] as String? ?? '';

    // If docName is missing or generic, resolve from DoctorRepository
    if (docName == null || docName.isEmpty || docName == 'Dr. Specialist') {
      if (docId.isNotEmpty) {
        try {
          final matched = DoctorRepository.cachedDoctors.where((d) => d.id == docId || d.userId == docId).toList();
          if (matched.isNotEmpty) {
            docName = matched.first.name;
          }
        } catch (_) {}
      }
    }

    String? deptName;
    if (json['department'] != null && json['department'] is Map) {
      deptName = json['department']['name'] as String?;
    }
    if ((deptName == null || deptName.isEmpty) && json['department_name'] != null) {
      deptName = json['department_name'] as String?;
    }
    if (deptName == null || deptName.isEmpty || deptName == 'General Medicine') {
      if (docId.isNotEmpty) {
        try {
          final matched = DoctorRepository.cachedDoctors.where((d) => d.id == docId || d.userId == docId).toList();
          if (matched.isNotEmpty && matched.first.departmentName.isNotEmpty) {
            deptName = matched.first.departmentName;
          }
        } catch (_) {}
      }
    }

    return OPDVisitModel(
      id: json['id'] as String? ?? '',
      visitNumber: json['visit_number'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: docId,
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

  OPDVisitModel copyWith({
    String? id,
    String? visitNumber,
    String? patientId,
    String? doctorId,
    String? departmentId,
    int? queueToken,
    String? triagePriority,
    String? status,
    double? consultationFee,
    String? paymentStatus,
    String? notes,
    DateTime? visitDate,
    PatientModel? patient,
    VitalSignsModel? vitals,
    String? doctorName,
    String? departmentName,
  }) {
    return OPDVisitModel(
      id: id ?? this.id,
      visitNumber: visitNumber ?? this.visitNumber,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      departmentId: departmentId ?? this.departmentId,
      queueToken: queueToken ?? this.queueToken,
      triagePriority: triagePriority ?? this.triagePriority,
      status: status ?? this.status,
      consultationFee: consultationFee ?? this.consultationFee,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      notes: notes ?? this.notes,
      visitDate: visitDate ?? this.visitDate,
      patient: patient ?? this.patient,
      vitals: vitals ?? this.vitals,
      doctorName: doctorName ?? this.doctorName,
      departmentName: departmentName ?? this.departmentName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'visit_number': visitNumber,
    'patient_id': patientId,
    'doctor_id': doctorId,
    'department_id': departmentId,
    'queue_token': queueToken,
    'triage_priority': triagePriority,
    'status': status,
    'consultation_fee': consultationFee,
    'payment_status': paymentStatus,
    'notes': notes,
    'visit_date': visitDate.toIso8601String(),
    'patient': patient?.toJson(),
    'vitals': vitals?.toJson(),
    'doctor_name': doctorName,
    'department_name': departmentName,
  };
}
