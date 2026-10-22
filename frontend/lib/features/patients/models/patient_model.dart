class PatientModel {
  final String id;
  final String uhid;
  final String? hospitalRegNum;
  final String? abhaNumber; // Ayushman Bharat Health Account (e.g. 78-6882-8324-4837)
  final String fullName;
  final String? parentSpouseName;
  final String? parentSpouseRelation; // "S/o", "D/o", "W/o", "H/o", "Care of"
  final String? dateOfBirth;
  final int? ageYears;
  final int? ageMonths;
  final String gender;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? bloodGroup;
  final DateTime? registrationDate;
  final String? barcodeValue;
  final String? qrCodeData;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? emergencyContactRelation;
  final String? guardianId;
  final String? registeredByStaffId;
  final String? registeredByStaffName;
  final String? registeredByStaffRole;
  final DateTime? createdAt;
  final int? currentToken;
  final String? currentVisitNumber;

  PatientModel({
    required this.id,
    required this.uhid,
    this.hospitalRegNum,
    this.abhaNumber,
    required this.fullName,
    this.parentSpouseName,
    this.parentSpouseRelation,
    this.dateOfBirth,
    this.ageYears,
    this.ageMonths,
    required this.gender,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.postalCode,
    this.bloodGroup,
    this.registrationDate,
    this.barcodeValue,
    this.qrCodeData,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.emergencyContactRelation,
    this.guardianId,
    this.registeredByStaffId,
    this.registeredByStaffName,
    this.registeredByStaffRole,
    this.createdAt,
    this.currentToken,
    this.currentVisitNumber,
  });


  PatientModel copyWith({
    String? id,
    String? uhid,
    String? hospitalRegNum,
    String? abhaNumber,
    String? fullName,
    String? parentSpouseName,
    String? parentSpouseRelation,
    String? dateOfBirth,
    int? ageYears,
    int? ageMonths,
    String? gender,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? postalCode,
    String? bloodGroup,
    DateTime? registrationDate,
    String? barcodeValue,
    String? qrCodeData,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? emergencyContactRelation,
    String? guardianId,
    String? registeredByStaffId,
    String? registeredByStaffName,
    String? registeredByStaffRole,
    DateTime? createdAt,
    int? currentToken,
    String? currentVisitNumber,
  }) {
    return PatientModel(
      id: id ?? this.id,
      uhid: uhid ?? this.uhid,
      hospitalRegNum: hospitalRegNum ?? this.hospitalRegNum,
      fullName: fullName ?? this.fullName,
      parentSpouseName: parentSpouseName ?? this.parentSpouseName,
      parentSpouseRelation: parentSpouseRelation ?? this.parentSpouseRelation,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      ageYears: ageYears ?? this.ageYears,
      ageMonths: ageMonths ?? this.ageMonths,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      abhaNumber: abhaNumber ?? this.abhaNumber,
      registrationDate: registrationDate ?? this.registrationDate,
      barcodeValue: barcodeValue ?? this.barcodeValue,
      qrCodeData: qrCodeData ?? this.qrCodeData,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      emergencyContactRelation: emergencyContactRelation ?? this.emergencyContactRelation,
      guardianId: guardianId ?? this.guardianId,
      registeredByStaffId: registeredByStaffId ?? this.registeredByStaffId,
      registeredByStaffName: registeredByStaffName ?? this.registeredByStaffName,
      registeredByStaffRole: registeredByStaffRole ?? this.registeredByStaffRole,
      createdAt: createdAt ?? this.createdAt,
      currentToken: currentToken ?? this.currentToken,
      currentVisitNumber: currentVisitNumber ?? this.currentVisitNumber,
    );
  }

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      hospitalRegNum: json['hospital_reg_num'] as String?,
      abhaNumber: json['abha_number'] as String?,
      fullName: json['full_name'] as String? ?? '',
      parentSpouseName: json['parent_spouse_name'] as String?,
      parentSpouseRelation: json['parent_spouse_relation'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      ageYears: json['age_years'] as int?,
      ageMonths: json['age_months'] as int?,
      gender: json['gender'] as String? ?? 'OTHER',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      bloodGroup: json['blood_group'] as String?,
      registrationDate: json['registration_date'] != null
          ? DateTime.tryParse(json['registration_date'].toString())
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null),
      barcodeValue: json['barcode_value'] as String?,
      qrCodeData: json['qr_code_data'] as String?,
      emergencyContactName: json['emergency_contact_name'] as String?,
      emergencyContactPhone: json['emergency_contact_phone'] as String?,
      emergencyContactRelation: json['emergency_contact_relation'] as String?,
      guardianId: json['guardian_id'] as String?,
      registeredByStaffId: json['registered_by_staff_id'] as String?,
      registeredByStaffName: json['registered_by_staff_name'] as String?,
      registeredByStaffRole: json['registered_by_staff_role'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : (json['registration_date'] != null ? DateTime.tryParse(json['registration_date'].toString()) : null),
      currentToken: json['current_token'] as int? ?? (json['queue_token'] as int?),
      currentVisitNumber: json['current_visit_number'] as String? ?? (json['visit_number'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'uhid': uhid,
    if (hospitalRegNum != null) 'hospital_reg_num': hospitalRegNum,
    if (abhaNumber != null) 'abha_number': abhaNumber,
    'full_name': fullName,
    if (parentSpouseName != null) 'parent_spouse_name': parentSpouseName,
    if (parentSpouseRelation != null) 'parent_spouse_relation': parentSpouseRelation,
    if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
    if (ageYears != null) 'age_years': ageYears,
    if (ageMonths != null) 'age_months': ageMonths,
    'gender': gender,
    'phone': phone,
    if (email != null) 'email': email,
    if (address != null) 'address': address,
    if (city != null) 'city': city,
    if (state != null) 'state': state,
    if (postalCode != null) 'postal_code': postalCode,
    if (bloodGroup != null) 'blood_group': bloodGroup,
    if (registrationDate != null) 'registration_date': registrationDate!.toIso8601String(),
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    if (barcodeValue != null) 'barcode_value': barcodeValue,
    if (qrCodeData != null) 'qr_code_data': qrCodeData,
    if (emergencyContactName != null) 'emergency_contact_name': emergencyContactName,
    if (emergencyContactPhone != null) 'emergency_contact_phone': emergencyContactPhone,
    if (emergencyContactRelation != null) 'emergency_contact_relation': emergencyContactRelation,
    if (guardianId != null) 'guardian_id': guardianId,
    if (registeredByStaffId != null) 'registered_by_staff_id': registeredByStaffId,
    if (registeredByStaffName != null) 'registered_by_staff_name': registeredByStaffName,
    if (registeredByStaffRole != null) 'registered_by_staff_role': registeredByStaffRole,
    if (currentToken != null) 'current_token': currentToken,
    if (currentVisitNumber != null) 'current_visit_number': currentVisitNumber,
  };

}

class DuplicateCandidateModel {
  final String id;
  final String uhid;
  final String? hospitalRegNum;
  final String fullName;
  final String phone;
  final String gender;
  final int? ageYears;
  final String? parentSpouseName;
  final String matchReason;

  DuplicateCandidateModel({
    required this.id,
    required this.uhid,
    this.hospitalRegNum,
    required this.fullName,
    required this.phone,
    required this.gender,
    this.ageYears,
    this.parentSpouseName,
    required this.matchReason,
  });

  factory DuplicateCandidateModel.fromJson(Map<String, dynamic> json) {
    return DuplicateCandidateModel(
      id: json['id'] as String? ?? '',
      uhid: json['uhid'] as String? ?? '',
      hospitalRegNum: json['hospital_reg_num'] as String?,
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      gender: json['gender'] as String? ?? 'OTHER',
      ageYears: json['age_years'] as int?,
      parentSpouseName: json['parent_spouse_name'] as String?,
      matchReason: json['match_reason'] as String? ?? 'Potential Duplicate',
    );
  }
}

class DuplicateCheckResult {
  final bool isDuplicate;
  final List<DuplicateCandidateModel> candidates;
  final String message;

  DuplicateCheckResult({
    required this.isDuplicate,
    required this.candidates,
    required this.message,
  });

  factory DuplicateCheckResult.fromJson(Map<String, dynamic> json) {
    final list = json['candidates'] as List<dynamic>? ?? [];
    return DuplicateCheckResult(
      isDuplicate: json['is_duplicate'] as bool? ?? false,
      candidates: list
          .map((item) => DuplicateCandidateModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      message: json['message'] as String? ?? '',
    );
  }
}
