import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/features/patients/models/patient_model.dart';
import 'package:opd_connect/features/patients/screens/patient_registration_screen.dart';
import 'package:opd_connect/features/clinical_records/models/clinical_record_model.dart';
import 'package:opd_connect/features/clinical_records/screens/consultation_sheet_screen.dart';
import 'package:opd_connect/features/clinical_records/providers/clinical_provider.dart';
import 'package:opd_connect/features/visits/models/visit_model.dart';
import 'package:opd_connect/features/visits/models/vitals_model.dart';

void main() {
  group('OPD Booklet Patient Registration & Demographics Model Tests', () {
    test('PatientModel serializes and deserializes all OPD booklet fields', () {
      final json = {
        'id': 'pat-101',
        'uhid': 'UHID-2026-00042',
        'hospital_reg_num': 'REG-2026-00042',
        'full_name': 'Aarav Dev Sharma',
        'parent_spouse_name': 'Dev Sharma',
        'parent_spouse_relation': 'S/o',
        'date_of_birth': '1995-08-20',
        'age_years': 31,
        'age_months': 2,
        'gender': 'MALE',
        'phone': '+919876543210',
        'email': 'aarav@example.com',
        'address': 'Flat 402, Lotus Towers',
        'city': 'Hyderabad',
        'state': 'Telangana',
        'postal_code': '500081',
        'blood_group': 'B+',
        'barcode_value': 'BAR-UHID-2026-00042',
        'qr_code_data': 'OPDCONNECT+UHID-2026-00042+REG-2026-00042',
        'emergency_contact_name': 'Dev Sharma',
        'emergency_contact_phone': '+919876543211',
        'emergency_contact_relation': 'Father',
      };

      final patient = PatientModel.fromJson(json);
      expect(patient.id, 'pat-101');
      expect(patient.uhid, 'UHID-2026-00042');
      expect(patient.hospitalRegNum, 'REG-2026-00042');
      expect(patient.fullName, 'Aarav Dev Sharma');
      expect(patient.parentSpouseName, 'Dev Sharma');
      expect(patient.parentSpouseRelation, 'S/o');
      expect(patient.ageYears, 31);
      expect(patient.ageMonths, 2);
      expect(patient.gender, 'MALE');
      expect(patient.city, 'Hyderabad');
      expect(patient.postalCode, '500081');
      expect(patient.barcodeValue, 'BAR-UHID-2026-00042');

      final serialized = patient.toJson();
      expect(serialized['hospital_reg_num'], 'REG-2026-00042');
      expect(serialized['parent_spouse_relation'], 'S/o');
      expect(serialized['age_months'], 2);
    });

    test('DuplicateCheckResult correctly parses potential duplicates', () {
      final json = {
        'is_duplicate': true,
        'candidates': [
          {
            'id': 'pat-dup-1',
            'uhid': 'UHID-2026-00001',
            'hospital_reg_num': 'REG-2026-00001',
            'full_name': 'Johnathan Reynolds',
            'phone': '+15551234567',
            'gender': 'MALE',
            'age_years': 38,
            'match_reason': 'Identical Phone Number and Matching Full Name',
          }
        ],
        'message': 'Found 1 potential duplicate patient record(s).'
      };

      final result = DuplicateCheckResult.fromJson(json);
      expect(result.isDuplicate, isTrue);
      expect(result.candidates.length, 1);
      expect(result.candidates.first.matchReason, contains('Identical Phone Number'));
    });
  });

  group('OPD Booklet Clinical Record & Amendment Model Tests', () {
    test('ClinicalRecordModel serializes assessment, examination, care plan, and authorship', () {
      final json = {
        'id': 'cr-201',
        'visit_id': 'vis-501',
        'patient_id': 'pat-101',
        'doctor_id': 'doc-301',
        'presenting_complaint': 'Throat irritation and mild dry cough for 3 days',
        'history_of_present_illness': 'Started after dust exposure, worse at night',
        'allergies': 'Sulfa drugs (urticaria)',
        'past_medical_history': 'Essential hypertension for 3 years',
        'prior_hospitalization': 'Appendectomy in 2018',
        'hypertension_history': 'Controlled on Telmisartan 40mg',
        'diabetes_history': 'None',
        'asthma_history': 'None',
        'tuberculosis_history': 'None',
        'smoking_history': 'Non-smoker',
        'alcohol_history': 'Social',
        'family_history': 'Father: CAD, Hypertension',
        'general_examination': 'Conscious, oriented, afebrile. No pallor or edema.',
        'respiratory_examination': 'Vesicular breath sounds bilaterally, no wheeze.',
        'cardiovascular_examination': 'S1 S2 normal, no murmurs.',
        'gastrointestinal_examination': 'Soft, non-tender, no organomegaly.',
        'cns_examination': 'Higher functions intact, cranial nerves normal.',
        'other_examination_findings': 'Mild oropharyngeal erythema.',
        'provisional_diagnosis': 'Acute Viral Pharyngitis',
        'final_diagnosis': 'Acute Viral Pharyngitis (J02.9)',
        'icd10_code': 'J02.9',
        'care_plan': 'Warm saline gargles, adequate hydration, voice rest.',
        'investigations_requested': 'Complete Blood Count (CBC)',
        'dietary_advice': 'Avoid cold juices and spicy foods for 3 days.',
        'follow_up_date': '2026-10-19',
        'referral_department': 'ENT OPD',
        'status': 'AMENDED',
        'version': 2,
        'signed_by_user_id': 'user-doc-1',
        'amendment_reason': 'Updated care plan based on CBC review',
        'amendments': [
          {
            'id': 'amend-1',
            'clinical_record_id': 'cr-201',
            'amended_by_user_id': 'user-doc-1',
            'amended_at': '2026-10-12T10:00:00Z',
            'reason': 'Updated care plan based on CBC review',
            'previous_snapshot_json': '{"version": 1, "status": "FINALIZED"}',
          }
        ],
      };

      final record = ClinicalRecordModel.fromJson(json);
      expect(record.presentingComplaint, 'Throat irritation and mild dry cough for 3 days');
      expect(record.chiefComplaint, record.presentingComplaint);
      expect(record.hypertensionHistory, contains('Telmisartan'));
      expect(record.respiratoryExamination, contains('Vesicular breath sounds'));
      expect(record.status, 'AMENDED');
      expect(record.version, 2);
      expect(record.amendments.length, 1);
      expect(record.amendments.first.reason, contains('Updated care plan'));

      final serialized = record.toJson();
      expect(serialized['presenting_complaint'], record.presentingComplaint);
      expect(serialized['icd10_code'], 'J02.9');
    });
  });

  group('OPD Booklet UI Widget Tests', () {
    testWidgets('PatientRegistrationScreen renders multi-section tabs and booklet form fields', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PatientRegistrationScreen(),
          ),
        ),
      );

      // Verify TabBar sections
      expect(find.text('Demographics'), findsOneWidget);
      expect(find.text('Contact & Addr'), findsOneWidget);
      expect(find.text('Clinical & Emer'), findsOneWidget);

      // Verify Demographics form fields
      expect(find.text('Patient Full Name *'), findsOneWidget);
      expect(find.text('Parent / Spouse Name'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);
      expect(find.text('Age (Y)'), findsOneWidget);
      expect(find.text('Sex / Gender *'), findsOneWidget);
      expect(find.text('Check Duplicate'), findsOneWidget);
      expect(find.text('Review & Save'), findsOneWidget);

      // Enter patient name
      final nameFinder = find.descendant(
        of: find.byKey(const Key('patient_name_input')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(nameFinder, 'Ananya Sen');
      await tester.pumpAndSettle();
      expect(find.text('Ananya Sen'), findsOneWidget);

      // Switch to Contact Tab
      await tester.tap(find.text('Contact & Addr'));
      await tester.pumpAndSettle();
      expect(find.text('Contact Phone Number *'), findsOneWidget);
      expect(find.text('Street / Residential Address *'), findsOneWidget);

      // Enter phone
      final phoneFinder = find.descendant(
        of: find.byKey(const Key('patient_phone_input')),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(phoneFinder, '+919988776655');
      await tester.pumpAndSettle();

      // Switch back to Demographics tab and verify data was preserved
      await tester.tap(find.text('Demographics'));
      await tester.pumpAndSettle();
      expect(find.text('Ananya Sen'), findsOneWidget);
    });

    testWidgets('ConsultationSheetScreen renders multi-section tabs and assessment observation metrics', (tester) async {
      final syntheticVisit = OPDVisitModel(
        id: 'vis-test-1',
        visitNumber: 'VIS-20261012-0088',
        patientId: 'pat-test-1',
        doctorId: 'doc-test-1',
        departmentId: 'dept-test-1',
        queueToken: 5,
        triagePriority: 'NORMAL',
        status: 'TRIAGED',
        consultationFee: 500.0,
        paymentStatus: 'PAID',
        visitDate: DateTime.now(),
        vitals: VitalSignsModel(
          id: 'vit-1',
          visitId: 'vis-test-1',
          systolicBp: 120,
          diastolicBp: 80,
          pulseRate: 74,
          temperatureF: 98.6,
          spo2Percent: 99.0,
          respiratoryRate: 16,
          heightCm: 172.0,
          weightKg: 68.0,
          bmi: 23.0,
          bloodGlucoseMgDl: 105.0,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRecordProvider('vis-test-1').overrideWith((ref) => Future.value(null)),
          ],
          child: MaterialApp(
            home: ConsultationSheetScreen(
              visitId: 'vis-test-1',
              visit: syntheticVisit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify TabBar sections
      expect(find.text('Assessment & Vitals'), findsOneWidget);
      expect(find.text('Systemic Exam'), findsOneWidget);
      expect(find.text('Diagnoses & Plan'), findsOneWidget);
      expect(find.text('Audit History'), findsOneWidget);

      // Verify Vitals Observation panel
      expect(find.text('Clinical Observations & Vitals'), findsOneWidget);
      expect(find.text('120/80 mmHg'), findsOneWidget);
      expect(find.text('74 bpm'), findsOneWidget);
      expect(find.text('105.0 mg/dL'), findsOneWidget);

      // Verify Initial assessment form fields
      expect(find.text('Presenting Complaint & Duration *'), findsOneWidget);
      expect(find.text('Specific Chronic Disease Histories'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Sign & Finalize'), findsOneWidget);
    });
  });
}
