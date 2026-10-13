import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/dashboard/screens/doctor_dashboard_view.dart';
import 'package:opd_connect/features/dashboard/models/doctor_dashboard_model.dart';
import 'package:opd_connect/features/dashboard/providers/doctor_dashboard_provider.dart';
import 'package:opd_connect/features/prescriptions/screens/prescription_screen.dart';
import 'package:opd_connect/features/prescriptions/models/prescription_model.dart';
import 'package:opd_connect/features/prescriptions/providers/prescription_provider.dart';
import 'package:opd_connect/features/prescriptions/repositories/prescription_repository.dart';
import 'package:opd_connect/features/clinical_records/screens/consultation_sheet_screen.dart';
import 'package:opd_connect/features/clinical_records/providers/clinical_provider.dart';
import 'package:opd_connect/features/clinical_records/models/consultation_context_model.dart';
import 'package:opd_connect/features/clinical_records/providers/consultation_context_provider.dart';
import 'package:opd_connect/features/visits/models/visit_model.dart';
import 'package:opd_connect/features/patients/models/patient_model.dart';

class MockPrescriptionRepository extends PrescriptionRepository {
  MockPrescriptionRepository() : super(DioClient());

  @override
  Future<List<MedicineCatalogItemModel>> searchMedicines({String? query}) async {
    return [
      MedicineCatalogItemModel(
        name: 'Paracetamol',
        category: 'Analgesic',
        commonForms: ['Tablet'],
        commonDosages: ['650 mg'],
        defaultRoute: 'Oral',
      ),
    ];
  }

  @override
  Future<List<AllergyWarningModel>> checkAllergies({
    required String patientId,
    required List<String> medicines,
  }) async {
    return [];
  }
}

void main() {
  final testPatient = PatientModel(
    id: 'pat-test-101',
    uhid: 'UHID-20261012-001',
    hospitalRegNum: 'HOSP-101',
    fullName: 'Priya Sharma',
    gender: 'FEMALE',
    phone: '+919876543210',
    ageYears: 32,
    bloodGroup: 'B+',
  );

  final testVisit = OPDVisitModel(
    id: 'vis-test-101',
    visitNumber: 'VIS-20261012-0001',
    patientId: 'pat-test-101',
    doctorId: 'doc-test-101',
    departmentId: 'dept-test-101',
    queueToken: 2,
    triagePriority: 'PRIORITY',
    status: 'IN_CONSULTATION',
    consultationFee: 250.0,
    paymentStatus: 'PAID',
    visitDate: DateTime.now(),
    doctorName: 'Dr. Sarah Chen, MD',
    patient: testPatient,
  );

  final mockDashboard = DoctorDashboardModel(
    stats: DoctorDashboardStatsModel(
      todayAppointments: 4,
      waitingPatients: 2,
      underConsultation: 1,
      completedConsultations: 1,
      pendingInvestigations: 1,
      followUpAppointments: 1,
    ),
    waitingPatients: [testVisit],
    underConsultation: [testVisit],
    completedConsultations: [testVisit],
    pendingInvestigations: [
      PendingInvestigationModel(
        id: 'lab-1',
        testName: 'HbA1c & Fasting Lipid Profile',
        testCategory: 'Biochemistry',
        status: 'PENDING',
        patientId: 'pat-test-101',
        patientName: 'Priya Sharma',
        uhid: 'UHID-20261012-001',
        visitId: 'vis-test-101',
        visitNumber: 'VIS-20261012-0001',
      ),
    ],
    followUpAppointments: [
      FollowUpAppointmentModel(
        patientId: 'pat-test-102',
        patientName: 'Johnathan Reynolds',
        uhid: 'UHID-20261012-002',
        visitId: 'vis-1',
        followUpDate: '2026-10-19',
        finalDiagnosis: 'Type 2 Diabetes Mellitus',
      ),
    ],
    recentAuthorizedPatients: [
      RecentAuthorizedPatientModel(
        patientId: 'pat-test-101',
        uhid: 'UHID-20261012-001',
        fullName: 'Priya Sharma',
        ageDisplay: '32 yrs',
        gender: 'FEMALE',
        phoneNumber: '+919876543210',
      ),
    ],
  );

  final mockContext = ConsultationContextModel(
    visit: {'id': testVisit.id, 'visit_number': testVisit.visitNumber},
    patient: {
      'id': testPatient.id,
      'full_name': testPatient.fullName,
      'hospital_number': testPatient.hospitalRegNum,
      'age': testPatient.ageYears,
      'sex': testPatient.gender,
      'phone': testPatient.phone,
      'allergies': 'Penicillin, Sulfa drugs',
    },
    medicalHistory: PatientMedicalHistorySummaryModel(
      allergies: 'Penicillin, Sulfa drugs',
      hypertensionHistory: 'Stage 1 HTN (2 yrs)',
      diabetesHistory: 'Type 2 DM (5 yrs)',
    ),
    previousVisits: [
      PreviousVisitSummaryModel(
        id: 'vis-prev-1',
        visitNumber: 'VIS-20260901-0012',
        visitDate: DateTime.now().subtract(const Duration(days: 30)),
        doctorName: 'Dr. Sarah Chen, MD',
        finalDiagnosis: 'Acute Bronchitis',
        status: 'COMPLETED',
      ),
    ],
    availableInvestigations: [
      {
        'test_name': 'Complete Blood Count (CBC)',
        'status': 'COMPLETED',
      },
    ],
    activePrescriptions: [],
  );

  group('Doctor Portal - Dashboard Tests', () {
    testWidgets('DoctorDashboardView renders metric cards, queues, and follow-ups', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            doctorDashboardProvider.overrideWith((ref) => Future.value(mockDashboard)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DoctorDashboardView(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify KPI Metrics Grid
      expect(find.text("Today's Appointments"), findsOneWidget);
      expect(find.text('Waiting Patients'), findsOneWidget);
      expect(find.text('In Consultation'), findsWidgets);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Pending Labs'), findsWidgets);
      expect(find.text('Follow-ups'), findsWidgets);

      // Verify queue tabs exist
      expect(find.text('Waiting (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);

      // Verify cards
      expect(find.text('Doctor Patient Queue'), findsOneWidget);
      expect(find.text('Pending Investigations'), findsOneWidget);
      expect(find.text('Follow-up Appointments'), findsOneWidget);
      expect(find.text('Recent Authorized Patients'), findsOneWidget);
    });

    testWidgets('DoctorDashboardView tab switching works between Waiting and Completed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            doctorDashboardProvider.overrideWith((ref) => Future.value(mockDashboard)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DoctorDashboardView(),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on Completed queue tab
      final completedTab = find.text('Completed (1)');
      expect(completedTab, findsOneWidget);
      await tester.tap(completedTab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Completed (1)'), findsOneWidget);
    });
  });

  group('Doctor Portal - Prescription Workflow & Clinical Safety Tests', () {
    testWidgets('PrescriptionScreen displays empty state and opens medication dialog with full fields', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prescriptionRepositoryProvider.overrideWithValue(MockPrescriptionRepository()),
            prescriptionListProvider(testVisit.id).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            home: PrescriptionScreen(
              visitId: testVisit.id,
              visit: testVisit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify header and patient banner
      expect(find.text('Doctor Prescription Portal'), findsOneWidget);
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.textContaining('Dr. Sarah Chen'), findsOneWidget);

      // Verify empty state & add medication button
      expect(find.text('No medications prescribed yet'), findsOneWidget);
      final addMedicationBtn = find.widgetWithText(ElevatedButton, 'Add Medication');
      expect(addMedicationBtn, findsOneWidget);

      // Tap Add Medication to open dialog
      await tester.tap(addMedicationBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify all prescription fields in dialog
      expect(find.text('Catalog Search & Autocomplete'), findsOneWidget);
      expect(find.text('Dosage *'), findsOneWidget);
      expect(find.text('Route'), findsOneWidget);
      expect(find.text('Frequency'), findsOneWidget);
      expect(find.text('Duration (Days)'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Timing'), findsOneWidget);
      expect(find.text('Add to Prescription'), findsOneWidget);
    });

    testWidgets('PrescriptionScreen warns when attempting to add empty medication name', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            prescriptionRepositoryProvider.overrideWithValue(MockPrescriptionRepository()),
            prescriptionListProvider(testVisit.id).overrideWith((ref) => Future.value([])),
          ],
          child: MaterialApp(
            home: PrescriptionScreen(
              visitId: testVisit.id,
              visit: testVisit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Open dialog
      final addMedicationBtn = find.widgetWithText(ElevatedButton, 'Add Medication');
      await tester.tap(addMedicationBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap Add to Prescription with empty medicine
      final addBtn = find.text('Add to Prescription');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();

      // SnackBar verification
      expect(find.text('Please specify a medication name.'), findsOneWidget);
    });
  });

  group('Doctor Portal - Consultation Sheet & Lab Ordering Tests', () {
    testWidgets('ConsultationSheetScreen renders patient context and lab investigation ordering button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRecordProvider(testVisit.id).overrideWith((ref) => Future.value(null)),
            consultationContextProvider(testVisit.id).overrideWith((ref) => Future.value(mockContext)),
          ],
          child: MaterialApp(
            home: ConsultationSheetScreen(
              visitId: testVisit.id,
              visit: testVisit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify tabs
      expect(find.text('Assessment & Vitals'), findsOneWidget);
      expect(find.text('Systemic Exam'), findsOneWidget);
      expect(find.text('Diagnoses & Plan'), findsOneWidget);
      expect(find.text('Audit History'), findsOneWidget);

      // Verify patient demographics & history banner
      expect(find.text('Priya Sharma'), findsOneWidget);
      expect(find.text('HOSP-101'), findsOneWidget);

      // Verify known allergy alert banner from medical history
      expect(find.text('KNOWN PATIENT ALLERGIES'), findsOneWidget);
      expect(find.text('Penicillin, Sulfa drugs'), findsOneWidget);

      // Switch to Diagnoses & Plan Tab
      await tester.tap(find.text('Diagnoses & Plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify lab ordering button and prescription navigation button
      expect(find.text('Order Formal Lab Investigation'), findsOneWidget);
      expect(find.text('Prescribe Medicines (Safety Checked)'), findsOneWidget);
    });

    testWidgets('Opening Order Formal Lab Investigation dialog shows test catalog and can cancel', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clinicalRecordProvider(testVisit.id).overrideWith((ref) => Future.value(null)),
            consultationContextProvider(testVisit.id).overrideWith((ref) => Future.value(mockContext)),
          ],
          child: MaterialApp(
            home: ConsultationSheetScreen(
              visitId: testVisit.id,
              visit: testVisit,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Switch to Diagnoses & Plan Tab
      await tester.tap(find.text('Diagnoses & Plan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Order Formal Lab Investigation button
      final orderLabButton = find.text('Order Formal Lab Investigation');
      await tester.ensureVisible(orderLabButton);
      await tester.tap(orderLabButton, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify dialog is displayed
      expect(find.text('Order Laboratory Investigation'), findsOneWidget);
      expect(find.text('Select Investigation Test:'), findsOneWidget);
      expect(find.text('Clinical Indication / Notes'), findsOneWidget);
      expect(find.text('Confirm Order'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Order Laboratory Investigation'), findsNothing);
    });
  });
}
