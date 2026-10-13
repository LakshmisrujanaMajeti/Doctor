class VitalSignsModel {
  final String id;
  final String visitId;
  final int? systolicBp;
  final int? diastolicBp;
  final int? pulseRate;
  final double? temperatureF;
  final double? spo2Percent;
  final int? respiratoryRate;
  final double? weightKg;
  final double? heightCm;
  final double? bmi;
  final double? bloodGlucoseMgDl;
  final String? notes;
  final DateTime? recordedAt;

  VitalSignsModel({
    required this.id,
    required this.visitId,
    this.systolicBp,
    this.diastolicBp,
    this.pulseRate,
    this.temperatureF,
    this.spo2Percent,
    this.respiratoryRate,
    this.weightKg,
    this.heightCm,
    this.bmi,
    this.bloodGlucoseMgDl,
    this.notes,
    this.recordedAt,
  });

  String get bloodPressureDisplay {
    if (systolicBp != null && diastolicBp != null) {
      return '$systolicBp/$diastolicBp mmHg';
    }
    return '--';
  }

  String get bmiCategory {
    if (bmi == null) return '--';
    if (bmi! < 18.5) return 'Underweight';
    if (bmi! < 25.0) return 'Normal Weight';
    if (bmi! < 30.0) return 'Overweight';
    return 'Obese';
  }

  factory VitalSignsModel.fromJson(Map<String, dynamic> json) {
    return VitalSignsModel(
      id: json['id'] as String? ?? '',
      visitId: json['visit_id'] as String? ?? '',
      systolicBp: json['systolic_bp'] as int?,
      diastolicBp: json['diastolic_bp'] as int?,
      pulseRate: json['pulse_rate'] as int?,
      temperatureF: (json['temperature_f'] as num?)?.toDouble(),
      spo2Percent: (json['spo2_percent'] as num?)?.toDouble(),
      respiratoryRate: json['respiratory_rate'] as int?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      heightCm: (json['height_cm'] as num?)?.toDouble(),
      bmi: (json['bmi'] as num?)?.toDouble(),
      bloodGlucoseMgDl: (json['blood_glucose_mg_dl'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      recordedAt: json['recorded_at'] != null ? DateTime.tryParse(json['recorded_at']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'visit_id': visitId,
    'systolic_bp': systolicBp,
    'diastolic_bp': diastolicBp,
    'pulse_rate': pulseRate,
    'temperature_f': temperatureF,
    'spo2_percent': spo2Percent,
    'respiratory_rate': respiratoryRate,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'bmi': bmi,
    'blood_glucose_mg_dl': bloodGlucoseMgDl,
    'notes': notes,
  };
}
