class DoctorModel {
  final String id;
  final String userId;
  final String name;
  final String specialization;
  final String departmentId;
  final String departmentName;
  final String qualification;
  final String roomNumber;
  final double consultationFee;
  final bool isAvailable;

  DoctorModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.specialization,
    required this.departmentId,
    required this.departmentName,
    this.qualification = 'MBBS, Specialist',
    this.roomNumber = 'Room 101',
    this.consultationFee = 500.0,
    this.isAvailable = true,
  });

  factory DoctorModel.fromJson(Map<String, dynamic> json) {
    String docName = json['name'] as String? ?? '';
    if (docName.isEmpty && json['user'] != null && json['user'] is Map) {
      docName = json['user']['full_name'] as String? ?? '';
    }
    if (docName.isEmpty) {
      docName = json['full_name'] as String? ?? 'Consulting Physician';
    }

    String deptName = json['department_name'] as String? ?? '';
    if (deptName.isEmpty && json['department'] != null && json['department'] is Map) {
      deptName = json['department']['name'] as String? ?? '';
    }
    if (deptName.isEmpty) {
      deptName = json['specialization'] as String? ?? 'General Medicine';
    }

    return DoctorModel(
      id: json['id'] as String? ?? 'doc-${DateTime.now().millisecondsSinceEpoch}',
      userId: json['user_id'] as String? ?? '',
      name: docName,
      specialization: json['specialization'] as String? ?? 'General Medicine',
      departmentId: json['department_id'] as String? ?? 'General Medicine',
      departmentName: deptName,
      qualification: json['qualification'] as String? ?? 'MBBS, MD',
      roomNumber: json['room_number'] as String? ?? 'Room 104',
      consultationFee: (json['consultation_fee'] as num?)?.toDouble() ??
          (double.tryParse(json['consultation_fee']?.toString() ?? '') ?? 500.0),
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'name': name,
    'specialization': specialization,
    'department_id': departmentId,
    'department_name': departmentName,
    'qualification': qualification,
    'room_number': roomNumber,
    'consultation_fee': consultationFee,
    'is_available': isAvailable,
  };
}
