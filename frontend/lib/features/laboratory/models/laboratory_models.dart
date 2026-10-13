class LabCatalogueParameter {
  final String name;
  final String defaultUnit;
  final String referenceRange;

  const LabCatalogueParameter({
    required this.name,
    this.defaultUnit = '',
    this.referenceRange = '',
  });

  factory LabCatalogueParameter.fromJson(Map<String, dynamic> json) {
    return LabCatalogueParameter(
      name: json['name'] as String? ?? '',
      defaultUnit: json['default_unit'] as String? ?? '',
      referenceRange: json['reference_range'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'default_unit': defaultUnit,
        'reference_range': referenceRange,
      };
}

class LabCatalogueItem {
  final String id;
  final String category; // BIOCHEMISTRY, HAEMATOLOGY, MICROBIOLOGY
  final String testName;
  final String sampleType;
  final String specimenTube;
  final int turnaroundTimeMins;
  final bool isSensitive;
  final String instructions;
  final List<LabCatalogueParameter> parameters;

  const LabCatalogueItem({
    required this.id,
    required this.category,
    required this.testName,
    required this.sampleType,
    required this.specimenTube,
    this.turnaroundTimeMins = 60,
    this.isSensitive = false,
    this.instructions = '',
    this.parameters = const [],
  });

  factory LabCatalogueItem.fromJson(Map<String, dynamic> json) {
    var rawParams = json['parameters'] as List<dynamic>? ?? [];
    return LabCatalogueItem(
      id: json['id'] as String? ?? '',
      category: json['category'] as String? ?? 'GENERAL',
      testName: json['test_name'] as String? ?? '',
      sampleType: json['sample_type'] as String? ?? '',
      specimenTube: json['specimen_tube'] as String? ?? '',
      turnaroundTimeMins: (json['turnaround_time_mins'] as num?)?.toInt() ?? 60,
      isSensitive: json['is_sensitive'] as bool? ?? false,
      instructions: json['instructions'] as String? ?? '',
      parameters: rawParams
          .map((p) => LabCatalogueParameter.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LabResultItemModel {
  final String parameterName;
  final String valueText;
  final String unit;
  final String referenceRange;
  final bool isAbnormal;
  final bool isCritical;
  final String flag; // NORMAL, ABNORMAL, CRITICAL

  const LabResultItemModel({
    required this.parameterName,
    required this.valueText,
    this.unit = '',
    this.referenceRange = '',
    this.isAbnormal = false,
    this.isCritical = false,
    this.flag = 'NORMAL',
  });

  factory LabResultItemModel.fromJson(Map<String, dynamic> json) {
    return LabResultItemModel(
      parameterName: json['parameter_name'] as String? ?? '',
      valueText: json['value_text'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      referenceRange: json['reference_range'] as String? ?? '',
      isAbnormal: json['is_abnormal'] as bool? ?? false,
      isCritical: json['is_critical'] as bool? ?? false,
      flag: json['flag'] as String? ?? 'NORMAL',
    );
  }

  Map<String, dynamic> toJson() => {
        'parameter_name': parameterName,
        'value_text': valueText,
        'unit': unit,
        'reference_range': referenceRange,
        'is_abnormal': isAbnormal,
        'is_critical': isCritical,
        'flag': flag,
      };
}

class LabOrderModel {
  final String id;
  final String orderNumber;
  final String visitId;
  final String patientId;
  final String uhid;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final String department;
  final String testName;
  final String? specimenId;
  final String specimenType;
  final String specimenStatus; // ORDERED, COLLECTED, RECEIVED, PROCESSING, COMPLETED, REJECTED, CANCELLED
  final String orderStatus; // PENDING, PROCESSING, COMPLETED, CANCELLED
  final bool isSensitive;
  final bool requiresReview;
  final String urgency;
  final String? notes;
  final String? collectionTime;
  final String? collectedByName;
  final String? receivedAt;
  final String? receivedByName;
  final String? rejectionReason;
  final String? verifiedByUserId;
  final String? verifiedByName;
  final String? verifiedAt;
  final String? verificationNotes;
  final bool publishedToVisit;
  final String? orderedAt;
  final List<LabResultItemModel> results;

  const LabOrderModel({
    required this.id,
    required this.orderNumber,
    required this.visitId,
    required this.patientId,
    this.uhid = '',
    this.patientName = '',
    this.patientAge,
    this.patientGender,
    required this.department,
    required this.testName,
    this.specimenId,
    required this.specimenType,
    this.specimenStatus = 'ORDERED',
    this.orderStatus = 'PENDING',
    this.isSensitive = false,
    this.requiresReview = false,
    this.urgency = 'ROUTINE',
    this.notes,
    this.collectionTime,
    this.collectedByName,
    this.receivedAt,
    this.receivedByName,
    this.rejectionReason,
    this.verifiedByUserId,
    this.verifiedByName,
    this.verifiedAt,
    this.verificationNotes,
    this.publishedToVisit = false,
    this.orderedAt,
    this.results = const [],
  });

  factory LabOrderModel.fromJson(Map<String, dynamic> json) {
    var rawResults = json['results'] as List<dynamic>? ?? [];
    return LabOrderModel(
      id: json['id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? 'ORD-0000',
      visitId: json['visit_id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      patientAge: (json['patient_age'] as num?)?.toInt(),
      patientGender: json['patient_gender'] as String?,
      department: json['department'] as String? ?? 'Biochemistry',
      testName: json['test_name'] as String? ?? '',
      specimenId: json['specimen_id'] as String?,
      specimenType: json['specimen_type'] as String? ?? 'Blood',
      specimenStatus: json['specimen_status'] as String? ?? 'ORDERED',
      orderStatus: json['order_status'] as String? ?? 'PENDING',
      isSensitive: json['is_sensitive'] as bool? ?? false,
      requiresReview: json['requires_review'] as bool? ?? false,
      urgency: json['urgency'] as String? ?? 'ROUTINE',
      notes: json['notes'] as String?,
      collectionTime: json['collection_time'] as String?,
      collectedByName: json['collected_by_name'] as String?,
      receivedAt: json['received_at'] as String?,
      receivedByName: json['received_by_name'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      verifiedByUserId: json['verified_by_user_id'] as String?,
      verifiedByName: json['verified_by_name'] as String?,
      verifiedAt: json['verified_at'] as String?,
      verificationNotes: json['verification_notes'] as String?,
      publishedToVisit: json['published_to_visit'] as bool? ?? false,
      orderedAt: json['ordered_at'] as String?,
      results: rawResults
          .map((r) => LabResultItemModel.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LabDashboardStatsModel {
  final int totalOrders;
  final int pendingCollection;
  final int inLabReceived;
  final int processing;
  final int pendingVerification;
  final int completedToday;
  final int rejectedCount;

  const LabDashboardStatsModel({
    this.totalOrders = 0,
    this.pendingCollection = 0,
    this.inLabReceived = 0,
    this.processing = 0,
    this.pendingVerification = 0,
    this.completedToday = 0,
    this.rejectedCount = 0,
  });

  factory LabDashboardStatsModel.fromJson(Map<String, dynamic> json) {
    return LabDashboardStatsModel(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      pendingCollection: (json['pending_collection'] as num?)?.toInt() ?? 0,
      inLabReceived: (json['in_lab_received'] as num?)?.toInt() ?? 0,
      processing: (json['processing'] as num?)?.toInt() ?? 0,
      pendingVerification: (json['pending_verification'] as num?)?.toInt() ?? 0,
      completedToday: (json['completed_today'] as num?)?.toInt() ?? 0,
      rejectedCount: (json['rejected_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class LabReportDataModel {
  final String hospitalName;
  final String hospitalAddress;
  final String hospitalPhone;
  final String orderId;
  final String orderNumber;
  final String specimenId;
  final String uhid;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final String testName;
  final String department;
  final String specimenType;
  final String specimenStatus;
  final String orderStatus;
  final bool isSensitive;
  final String? collectionTime;
  final String? collectedByName;
  final String? receivedAt;
  final String? receivedByName;
  final String? verifiedByName;
  final String? verifiedAt;
  final String? verificationNotes;
  final String? reportGeneratedAt;
  final List<LabResultItemModel> parameters;

  const LabReportDataModel({
    required this.hospitalName,
    required this.hospitalAddress,
    required this.hospitalPhone,
    required this.orderId,
    required this.orderNumber,
    required this.specimenId,
    required this.uhid,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    required this.testName,
    required this.department,
    required this.specimenType,
    required this.specimenStatus,
    required this.orderStatus,
    this.isSensitive = false,
    this.collectionTime,
    this.collectedByName,
    this.receivedAt,
    this.receivedByName,
    this.verifiedByName,
    this.verifiedAt,
    this.verificationNotes,
    this.reportGeneratedAt,
    this.parameters = const [],
  });

  factory LabReportDataModel.fromJson(Map<String, dynamic> json) {
    var rawParams = json['parameters'] as List<dynamic>? ?? [];
    return LabReportDataModel(
      hospitalName: json['hospital_name'] as String? ?? 'OPD CONNECT+ HOSPITAL',
      hospitalAddress: json['hospital_address'] as String? ?? 'General Hospital Campus',
      hospitalPhone: json['hospital_phone'] as String? ?? '+1-555-OPD-CARE',
      orderId: json['order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      specimenId: json['specimen_id'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      patientName: json['patient_name'] as String? ?? '',
      patientAge: (json['patient_age'] as num?)?.toInt(),
      patientGender: json['patient_gender'] as String?,
      testName: json['test_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      specimenType: json['specimen_type'] as String? ?? '',
      specimenStatus: json['specimen_status'] as String? ?? '',
      orderStatus: json['order_status'] as String? ?? '',
      isSensitive: json['is_sensitive'] as bool? ?? false,
      collectionTime: json['collection_time'] as String?,
      collectedByName: json['collected_by_name'] as String?,
      receivedAt: json['received_at'] as String?,
      receivedByName: json['received_by_name'] as String?,
      verifiedByName: json['verified_by_name'] as String?,
      verifiedAt: json['verified_at'] as String?,
      verificationNotes: json['verification_notes'] as String?,
      reportGeneratedAt: json['report_generated_at'] as String?,
      parameters: rawParams
          .map((p) => LabResultItemModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
