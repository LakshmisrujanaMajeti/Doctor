class OpdConstants {
  static const List<String> triagePriorities = [
    'NORMAL',
    'PRIORITY',
    'EMERGENCY',
  ];

  static const List<String> visitStatuses = [
    'REGISTERED',
    'TRIAGED',
    'IN_CONSULTATION',
    'COMPLETED',
    'CANCELLED',
  ];

  static const List<String> departments = [
    'General Medicine',
    'Pediatrics',
    'Orthopedics',
    'Cardiology',
    'ENT',
    'Dermatology',
    'Ophthalmology',
  ];

  static const List<String> bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> dosageFrequencies = [
    'OD (Once Daily)',
    'BD (Twice Daily)',
    'TID (Three Times Daily)',
    'QID (Four Times Daily)',
    'SOS (As Needed)',
  ];

  static const List<String> medicineForms = [
    'Tablet',
    'Capsule',
    'Syrup',
    'Injection',
    'Ointment',
    'Inhaler',
    'Eye Drops',
  ];
}
