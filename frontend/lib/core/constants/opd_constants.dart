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
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Gastroenterology',
    'Neurology',
    'Oncology',
    'Pulmonology',
    'Nephrology',
    'Gynecology',
    'Pediatrics',
    'Orthopedics',
    'ENT',
    'Ophthalmology',
  ];

  /// 10 Dedicated Hospital Clinical Doctor Roles & Specializations
  static const List<Map<String, String>> doctorRoles = [
    {
      'role': 'doctor_gen_med',
      'title': 'General Medicine Doctor',
      'department': 'General Medicine',
      'specialization': 'General Medicine',
      'qualification': 'MBBS, MD (General Medicine)',
      'conditions': 'Fever, diabetes, hypertension, infection, general illness, fatigue',
      'default_room': 'Room 101',
      'fee': '500.0',
    },
    {
      'role': 'doctor_cardiology',
      'title': 'Cardiologist',
      'department': 'Cardiology',
      'specialization': 'Cardiology',
      'qualification': 'MBBS, MD, DM (Cardiology)',
      'conditions': 'Chest pain, palpitations, hypertension, breathlessness, cardiac evaluation',
      'default_room': 'Room 102',
      'fee': '750.0',
    },
    {
      'role': 'doctor_dermatology',
      'title': 'Dermatologist',
      'department': 'Dermatology',
      'specialization': 'Dermatology',
      'qualification': 'MBBS, MD (DVL)',
      'conditions': 'Skin allergy, acne, rashes, eczema, hair loss, psoriasis',
      'default_room': 'Room 103',
      'fee': '600.0',
    },
    {
      'role': 'doctor_endocrinology',
      'title': 'Endocrinologist',
      'department': 'Endocrinology',
      'specialization': 'Endocrinology',
      'qualification': 'MBBS, MD, DM (Endocrinology)',
      'conditions': 'Thyroid disorder, uncontrolled diabetes, hormonal imbalance, metabolic disorder',
      'default_room': 'Room 104',
      'fee': '700.0',
    },
    {
      'role': 'doctor_gastroenterology',
      'title': 'Gastroenterologist',
      'department': 'Gastroenterology',
      'specialization': 'Gastroenterology',
      'qualification': 'MBBS, MD, DM (Gastroenterology)',
      'conditions': 'Acid reflux, GERD, abdominal pain, gastritis, liver disorders, jaundice',
      'default_room': 'Room 105',
      'fee': '750.0',
    },
    {
      'role': 'doctor_neurology',
      'title': 'Neurologist',
      'department': 'Neurology',
      'specialization': 'Neurology',
      'qualification': 'MBBS, MD, DM (Neurology)',
      'conditions': 'Migraine, headache, seizures, numbness, tremors, nerve disorders',
      'default_room': 'Room 106',
      'fee': '800.0',
    },
    {
      'role': 'doctor_oncology',
      'title': 'Oncologist',
      'department': 'Oncology',
      'specialization': 'Oncology',
      'qualification': 'MBBS, MD, DM (Medical Oncology)',
      'conditions': 'Cancer screening, tumor evaluation, unexplained weight loss, oncology follow-up',
      'default_room': 'Room 107',
      'fee': '900.0',
    },
    {
      'role': 'doctor_pulmonology',
      'title': 'Pulmonologist',
      'department': 'Pulmonology',
      'specialization': 'Pulmonology',
      'qualification': 'MBBS, MD (Pulmonary Medicine)',
      'conditions': 'Asthma, chronic cough, COPD, breathing difficulty, wheezing, pneumonia',
      'default_room': 'Room 108',
      'fee': '650.0',
    },
    {
      'role': 'doctor_nephrology',
      'title': 'Nephrologist',
      'department': 'Nephrology',
      'specialization': 'Nephrology',
      'qualification': 'MBBS, MD, DM (Nephrology)',
      'conditions': 'Kidney stones, renal failure, pedal edema, proteinuria, CKD',
      'default_room': 'Room 109',
      'fee': '750.0',
    },
    {
      'role': 'doctor_gynecology',
      'title': 'Gynecologist',
      'department': 'Gynecology',
      'specialization': 'Gynecology',
      'qualification': 'MBBS, MS, DGO (Obstetrics & Gynecology)',
      'conditions': 'Antenatal care (ANC), pregnancy, menstrual issues, PCOS, pelvic pain',
      'default_room': 'Room 110',
      'fee': '600.0',
    },
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
