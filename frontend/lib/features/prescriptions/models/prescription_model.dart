class PrescriptionItemModel {
  final String? id;
  final String medicineName;
  final String form;
  final String dosage;
  final String route;
  final String frequency;
  final int durationDays;
  final int? quantity;
  final String timing;
  final String? instructions;
  final bool isDispensed;

  PrescriptionItemModel({
    this.id,
    required this.medicineName,
    this.form = 'Tablet',
    required this.dosage,
    this.route = 'Oral',
    required this.frequency,
    this.durationDays = 5,
    this.quantity,
    this.timing = 'After Food',
    this.instructions,
    this.isDispensed = false,
  });

  factory PrescriptionItemModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionItemModel(
      id: json['id'] as String?,
      medicineName: json['medicine_name'] as String? ?? '',
      form: json['form'] as String? ?? 'Tablet',
      dosage: json['dosage'] as String? ?? '',
      route: json['route'] as String? ?? 'Oral',
      frequency: json['frequency'] as String? ?? 'OD',
      durationDays: json['duration_days'] as int? ?? 5,
      quantity: json['quantity'] as int?,
      timing: json['timing'] as String? ?? 'After Food',
      instructions: json['instructions'] as String?,
      isDispensed: json['is_dispensed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'medicine_name': medicineName,
    'form': form,
    'dosage': dosage,
    'route': route,
    'frequency': frequency,
    'duration_days': durationDays,
    if (quantity != null) 'quantity': quantity,
    'timing': timing,
    'instructions': instructions,
  };
}

class PrescriptionAmendmentModel {
  final String id;
  final String prescriptionId;
  final String amendedByUserId;
  final String amendedAt;
  final String reason;
  final String previousSnapshotJson;

  PrescriptionAmendmentModel({
    required this.id,
    required this.prescriptionId,
    required this.amendedByUserId,
    required this.amendedAt,
    required this.reason,
    required this.previousSnapshotJson,
  });

  factory PrescriptionAmendmentModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionAmendmentModel(
      id: json['id'] as String? ?? '',
      prescriptionId: json['prescription_id'] as String? ?? '',
      amendedByUserId: json['amended_by_user_id'] as String? ?? '',
      amendedAt: json['amended_at'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      previousSnapshotJson: json['previous_snapshot_json'] as String? ?? '',
    );
  }
}

class PrescriptionModel {
  final String id;
  final String visitId;
  final String patientId;
  final String doctorId;
  final String status; // DRAFT, SIGNED, AMENDED, CANCELLED, ACTIVE
  final int version;
  final String? notes;
  final String? signedByUserId;
  final String? signedAt;
  final String? amendmentReason;
  final bool isOcrExtracted;
  final bool isVerifiedByClinician;
  final bool allergyWarningAcknowledged;
  final String? doctorName;
  final List<PrescriptionItemModel> items;
  final List<PrescriptionAmendmentModel> amendments;

  PrescriptionModel({
    required this.id,
    required this.visitId,
    required this.patientId,
    required this.doctorId,
    required this.status,
    this.version = 1,
    this.notes,
    this.signedByUserId,
    this.signedAt,
    this.amendmentReason,
    this.isOcrExtracted = false,
    this.isVerifiedByClinician = true,
    this.allergyWarningAcknowledged = false,
    this.doctorName,
    required this.items,
    this.amendments = const [],
  });

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isSigned => status.toUpperCase() == 'SIGNED' || status.toUpperCase() == 'ACTIVE';
  bool get isAmended => status.toUpperCase() == 'AMENDED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<PrescriptionItemModel> itemsList = rawItems
        .map((i) => PrescriptionItemModel.fromJson(i as Map<String, dynamic>))
        .toList();

    var rawAmendments = json['amendments'] as List<dynamic>? ?? [];
    List<PrescriptionAmendmentModel> amendmentsList = rawAmendments
        .map((a) => PrescriptionAmendmentModel.fromJson(a as Map<String, dynamic>))
        .toList();

    String? docName;
    if (json['doctor'] != null && json['doctor']['user'] != null) {
      docName = json['doctor']['user']['full_name'] as String?;
    } else if (json['doctor_name'] != null) {
      docName = json['doctor_name'] as String?;
    }

    return PrescriptionModel(
      id: json['id'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      status: json['status'] as String? ?? 'SIGNED',
      version: json['version'] as int? ?? 1,
      notes: json['notes'] as String?,
      signedByUserId: json['signed_by_user_id'] as String?,
      signedAt: json['signed_at'] as String?,
      amendmentReason: json['amendment_reason'] as String?,
      isOcrExtracted: json['is_ocr_extracted'] as bool? ?? false,
      isVerifiedByClinician: json['is_verified_by_clinician'] as bool? ?? true,
      allergyWarningAcknowledged: json['allergy_warning_acknowledged'] as bool? ?? false,
      doctorName: docName,
      items: itemsList,
      amendments: amendmentsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'visit_id': visitId,
    'status': status,
    'notes': notes,
    'is_ocr_extracted': isOcrExtracted,
    'is_verified_by_clinician': isVerifiedByClinician,
    'allergy_warning_acknowledged': allergyWarningAcknowledged,
    'items': items.map((i) => i.toJson()).toList(),
  };
}

class AllergyWarningModel {
  final String medicineName;
  final String allergen;
  final String severity;
  final String warningMessage;

  AllergyWarningModel({
    required this.medicineName,
    required this.allergen,
    required this.severity,
    required this.warningMessage,
  });

  factory AllergyWarningModel.fromJson(Map<String, dynamic> json) {
    return AllergyWarningModel(
      medicineName: json['medicine_name'] as String? ?? '',
      allergen: json['allergen'] as String? ?? '',
      severity: json['severity'] as String? ?? 'HIGH',
      warningMessage: json['warning_message'] as String? ?? '',
    );
  }
}

class MedicineCatalogItemModel {
  final String name;
  final String category;
  final List<String> commonForms;
  final List<String> commonDosages;
  final String defaultRoute;
  final String? allergyClass;

  MedicineCatalogItemModel({
    required this.name,
    required this.category,
    required this.commonForms,
    required this.commonDosages,
    this.defaultRoute = 'Oral',
    this.allergyClass,
  });

  factory MedicineCatalogItemModel.fromJson(Map<String, dynamic> json) {
    return MedicineCatalogItemModel(
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      commonForms: (json['common_forms'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      commonDosages: (json['common_dosages'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      defaultRoute: json['default_route'] as String? ?? 'Oral',
      allergyClass: json['allergy_class'] as String?,
    );
  }
}
