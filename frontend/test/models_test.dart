import 'package:flutter_test/flutter_test.dart';
import 'package:opd_connect/features/patients/models/patient_model.dart';
import 'package:opd_connect/features/visits/models/vitals_model.dart';
import 'package:opd_connect/features/visits/models/visit_model.dart';

void main() {
  group('OPD Connect+ Models Unit Tests', () {
    test('PatientModel serialization and deserialization', () {
      final json = {
        'id': 'pat-101',
        'uhid': 'UHID-2026-00001',
        'full_name': 'Eleanor Vance',
        'age_years': 34,
        'gender': 'FEMALE',
        'phone': '+15559876543',
        'blood_group': 'B+',
      };

      final patient = PatientModel.fromJson(json);
      expect(patient.id, 'pat-101');
      expect(patient.uhid, 'UHID-2026-00001');
      expect(patient.fullName, 'Eleanor Vance');
      expect(patient.bloodGroup, 'B+');
      expect(patient.gender, 'FEMALE');

      final outputMap = patient.toJson();
      expect(outputMap['uhid'], 'UHID-2026-00001');
      expect(outputMap['full_name'], 'Eleanor Vance');
    });

    test('VitalSignsModel BMI category and BP display calculation', () {
      final vitals = VitalSignsModel(
        id: 'vit-1',
        visitId: 'vis-1',
        systolicBp: 120,
        diastolicBp: 80,
        heightCm: 180.0,
        weightKg: 75.0,
        bmi: 23.1,
      );

      expect(vitals.bloodPressureDisplay, '120/80 mmHg');
      expect(vitals.bmiCategory, 'Normal Weight');

      final overVitals = VitalSignsModel(
        id: 'vit-2',
        visitId: 'vis-2',
        bmi: 28.5,
      );
      expect(overVitals.bmiCategory, 'Overweight');

      final obeseVitals = VitalSignsModel(
        id: 'vit-3',
        visitId: 'vis-3',
        bmi: 32.0,
      );
      expect(obeseVitals.bmiCategory, 'Obese');
    });

    test('OPDVisitModel token queue parsing', () {
      final json = {
        'id': 'vis-99',
        'visit_number': 'VIS-20261012-0099',
        'patient_id': 'pat-1',
        'doctor_id': 'doc-1',
        'department_id': 'dept-1',
        'queue_token': 14,
        'triage_priority': 'PRIORITY',
        'status': 'TRIAGED',
        'consultation_fee': 500.0,
        'payment_status': 'PAID',
        'visit_date': '2026-10-12T09:30:00Z',
      };

      final visit = OPDVisitModel.fromJson(json);
      expect(visit.queueToken, 14);
      expect(visit.triagePriority, 'PRIORITY');
      expect(visit.status, 'TRIAGED');
    });
  });
}
