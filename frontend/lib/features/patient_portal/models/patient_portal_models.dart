import 'package:flutter/foundation.dart';
import '../../patients/models/patient_model.dart';

@immutable
class DependentProfile {
  final String id;
  final String uhid;
  final String fullName;
  final String relation;
  final String gender;
  final String ageDisplay;
  final String? bloodGroup;
  final String registrationDate;

  const DependentProfile({
    required this.id,
    required this.uhid,
    required this.fullName,
    required this.relation,
    required this.gender,
    required this.ageDisplay,
    this.bloodGroup,
    required this.registrationDate,
  });

  factory DependentProfile.fromJson(Map<String, dynamic> json) {
    return DependentProfile(
      id: json['id'] as String,
      uhid: json['uhid'] as String,
      fullName: json['full_name'] as String,
      relation: json['relation'] as String,
      gender: json['gender'] as String,
      ageDisplay: json['age_display'] as String,
      bloodGroup: json['blood_group'] as String?,
      registrationDate: json['registration_date'] as String,
    );
  }
}

@immutable
class PatientPortalProfile {
  final PatientModel patient;
  final List<DependentProfile> dependents;
  final bool hasActiveToken;
  final String? activeTokenNumber;
  final String? activeTokenQueueStatus;

  const PatientPortalProfile({
    required this.patient,
    required this.dependents,
    this.hasActiveToken = false,
    this.activeTokenNumber,
    this.activeTokenQueueStatus,
  });

  factory PatientPortalProfile.fromJson(Map<String, dynamic> json) {
    final patientJson = json['patient'] as Map<String, dynamic>;
    final depsJson = (json['dependents'] as List?) ?? [];
    return PatientPortalProfile(
      patient: PatientModel.fromJson(patientJson),
      dependents: depsJson.map((d) => DependentProfile.fromJson(d as Map<String, dynamic>)).toList(),
      hasActiveToken: (json['has_active_token'] as bool?) ?? false,
      activeTokenNumber: json['active_token_number'] as String?,
      activeTokenQueueStatus: json['active_token_queue_status'] as String?,
    );
  }
}

@immutable
class UpcomingAppointment {
  final String visitId;
  final String visitNumber;
  final String doctorName;
  final String departmentName;
  final String scheduledDate;
  final String? followUpReason;
  final String? carePlan;
  final bool isCompleted;

  const UpcomingAppointment({
    required this.visitId,
    required this.visitNumber,
    required this.doctorName,
    required this.departmentName,
    required this.scheduledDate,
    this.followUpReason,
    this.carePlan,
    this.isCompleted = false,
  });

  factory UpcomingAppointment.fromJson(Map<String, dynamic> json) {
    return UpcomingAppointment(
      visitId: json['visit_id'] as String,
      visitNumber: (json['visit_number'] as String?) ?? '',
      doctorName: (json['doctor_name'] as String?) ?? 'Attending Clinician',
      departmentName: (json['department_name'] as String?) ?? 'General Clinic',
      scheduledDate: json['scheduled_date'] as String,
      followUpReason: json['follow_up_reason'] as String?,
      carePlan: json['care_plan'] as String?,
      isCompleted: (json['is_completed'] as bool?) ?? false,
    );
  }
}

@immutable
class PatientPrescriptionItemDetail {
  final String medicineName;
  final String form;
  final String dosage;
  final String route;
  final String frequency;
  final int durationDays;
  final int quantity;
  final String? timing;
  final String? instructions;
  final bool isDispensed;

  const PatientPrescriptionItemDetail({
    required this.medicineName,
    required this.form,
    required this.dosage,
    required this.route,
    required this.frequency,
    required this.durationDays,
    required this.quantity,
    this.timing,
    this.instructions,
    this.isDispensed = false,
  });

  factory PatientPrescriptionItemDetail.fromJson(Map<String, dynamic> json) {
    return PatientPrescriptionItemDetail(
      medicineName: json['medicine_name'] as String,
      form: (json['form'] as String?) ?? 'Tablet',
      dosage: json['dosage'] as String,
      route: (json['route'] as String?) ?? 'Oral',
      frequency: json['frequency'] as String,
      durationDays: (json['duration_days'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      timing: json['timing'] as String?,
      instructions: json['instructions'] as String?,
      isDispensed: (json['is_dispensed'] as bool?) ?? false,
    );
  }
}

@immutable
class PatientPrescriptionSummaryItem {
  final String id;
  final String visitId;
  final String doctorName;
  final String departmentName;
  final String status;
  final String? signedAt;
  final String? notes;
  final List<PatientPrescriptionItemDetail> items;

  const PatientPrescriptionSummaryItem({
    required this.id,
    required this.visitId,
    required this.doctorName,
    required this.departmentName,
    required this.status,
    this.signedAt,
    this.notes,
    required this.items,
  });

  factory PatientPrescriptionSummaryItem.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? [];
    return PatientPrescriptionSummaryItem(
      id: json['id'] as String,
      visitId: json['visit_id'] as String,
      doctorName: (json['doctor_name'] as String?) ?? 'Physician',
      departmentName: (json['department_name'] as String?) ?? 'Outpatient Clinic',
      status: json['status'] as String,
      signedAt: json['signed_at'] as String?,
      notes: json['notes'] as String?,
      items: rawItems.map((i) => PatientPrescriptionItemDetail.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }
}

@immutable
class PatientLabResultItem {
  final String parameterName;
  final String resultValue;
  final String? unit;
  final String? referenceRange;
  final bool isAbnormal;

  const PatientLabResultItem({
    required this.parameterName,
    required this.resultValue,
    this.unit,
    this.referenceRange,
    this.isAbnormal = false,
  });

  factory PatientLabResultItem.fromJson(Map<String, dynamic> json) {
    return PatientLabResultItem(
      parameterName: json['parameter_name'] as String,
      resultValue: json['result_value'] as String,
      unit: json['unit'] as String?,
      referenceRange: json['reference_range'] as String?,
      isAbnormal: (json['is_abnormal'] as bool?) ?? false,
    );
  }
}

@immutable
class PatientLabReportSummary {
  final String id;
  final String? orderNumber;
  final String testName;
  final String testCategory;
  final String status;
  final String orderedAt;
  final String? completedAt;
  final String? specimenType;
  final bool isSensitive;
  final List<PatientLabResultItem> results;

  const PatientLabReportSummary({
    required this.id,
    this.orderNumber,
    required this.testName,
    required this.testCategory,
    required this.status,
    required this.orderedAt,
    this.completedAt,
    this.specimenType,
    this.isSensitive = false,
    required this.results,
  });

  factory PatientLabReportSummary.fromJson(Map<String, dynamic> json) {
    final rawRes = (json['results'] as List?) ?? [];
    return PatientLabReportSummary(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      testName: json['test_name'] as String,
      testCategory: json['test_category'] as String,
      status: json['status'] as String,
      orderedAt: json['ordered_at'] as String,
      completedAt: json['completed_at'] as String?,
      specimenType: json['specimen_type'] as String?,
      isSensitive: (json['is_sensitive'] as bool?) ?? false,
      results: rawRes.map((r) => PatientLabResultItem.fromJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

@immutable
class PatientBillSummary {
  final String id;
  final String invoiceNumber;
  final String? visitId;
  final double totalAmount;
  final double paidAmount;
  final double discountAmount;
  final String paymentStatus;
  final String billedAt;
  final String? receiptNumber;
  final int itemsCount;

  const PatientBillSummary({
    required this.id,
    required this.invoiceNumber,
    this.visitId,
    required this.totalAmount,
    required this.paidAmount,
    required this.discountAmount,
    required this.paymentStatus,
    required this.billedAt,
    this.receiptNumber,
    required this.itemsCount,
  });

  factory PatientBillSummary.fromJson(Map<String, dynamic> json) {
    return PatientBillSummary(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      visitId: json['visit_id'] as String?,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      discountAmount: (json['discount_amount'] as num).toDouble(),
      paymentStatus: json['payment_status'] as String,
      billedAt: json['billed_at'] as String,
      receiptNumber: json['receipt_number'] as String?,
      itemsCount: (json['items_count'] as num).toInt(),
    );
  }
}

@immutable
class SupportTicketModel {
  final String id;
  final String patientId;
  final String patientName;
  final String patientUhid;
  final String subject;
  final String category;
  final String priority;
  final String message;
  final String status;
  final String? adminResponse;
  final String? resolvedAt;
  final String createdAt;

  const SupportTicketModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.patientUhid,
    required this.subject,
    required this.category,
    required this.priority,
    required this.message,
    required this.status,
    this.adminResponse,
    this.resolvedAt,
    required this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      patientName: (json['patient_name'] as String?) ?? 'Patient',
      patientUhid: (json['patient_uhid'] as String?) ?? '',
      subject: json['subject'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      adminResponse: json['admin_response'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      createdAt: json['created_at'] as String,
    );
  }
}
