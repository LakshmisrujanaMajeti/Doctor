import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/laboratory/models/laboratory_models.dart';
import 'package:opd_connect/features/laboratory/repositories/laboratory_repository.dart';
import 'package:opd_connect/features/laboratory/providers/laboratory_provider.dart';
import 'package:opd_connect/features/laboratory/screens/laboratory_workspace_view.dart';
import 'package:opd_connect/features/laboratory/screens/laboratory_report_screen.dart';
import 'package:opd_connect/features/laboratory/widgets/specimen_label_dialog.dart';
import 'package:opd_connect/features/laboratory/widgets/specimen_action_dialogs.dart';
import 'package:opd_connect/features/laboratory/widgets/verification_dialog.dart';

class MockLaboratoryRepository extends LaboratoryRepository {
  MockLaboratoryRepository() : super(DioClient());

  @override
  Future<List<LabCatalogueItem>> getCatalogue({String? category}) async {
    return [
      const LabCatalogueItem(
        id: 'cat-1',
        category: 'BIOCHEMISTRY',
        testName: 'Glucose Fasting',
        sampleType: 'Fluoride Plasma',
        specimenTube: 'Grey Top',
        turnaroundTimeMins: 60,
      ),
      const LabCatalogueItem(
        id: 'cat-2',
        category: 'HAEMATOLOGY',
        testName: 'Haemoglobin (Hb)',
        sampleType: 'Whole Blood',
        specimenTube: 'Lavender Top',
        turnaroundTimeMins: 45,
      ),
      const LabCatalogueItem(
        id: 'cat-3',
        category: 'MICROBIOLOGY',
        testName: 'HIV',
        sampleType: 'Serum',
        specimenTube: 'Yellow Top',
        isSensitive: true,
        turnaroundTimeMins: 120,
      ),
    ];
  }

  @override
  Future<LabDashboardStatsModel> getDashboardStats() async {
    return const LabDashboardStatsModel(
      totalOrders: 15,
      pendingCollection: 4,
      inLabReceived: 3,
      processing: 2,
      pendingVerification: 2,
      completedToday: 3,
      rejectedCount: 1,
    );
  }

  @override
  Future<List<LabOrderModel>> getOrders({
    String? department,
    String? status,
    String? specimenStatus,
    String? search,
    String? date,
  }) async {
    return [
      const LabOrderModel(
        id: 'ord-101',
        orderNumber: 'LAB-20261012-0001',
        visitId: 'vis-101',
        patientId: 'pat-101',
        uhid: 'UHID-20261012-0001',
        patientName: 'Ramesh Patel',
        patientAge: 45,
        patientGender: 'MALE',
        department: 'Biochemistry',
        testName: 'Glucose Fasting',
        specimenId: 'SPEC-20261012-0001',
        specimenType: 'Fluoride Plasma',
        specimenStatus: 'ORDERED',
        orderStatus: 'PENDING',
        urgency: 'ROUTINE',
      ),
      const LabOrderModel(
        id: 'ord-102',
        orderNumber: 'LAB-20261012-0002',
        visitId: 'vis-102',
        patientId: 'pat-102',
        uhid: 'UHID-20261012-0002',
        patientName: 'Sunita Rao',
        patientAge: 29,
        patientGender: 'FEMALE',
        department: 'Haematology',
        testName: 'Haemoglobin (Hb)',
        specimenId: 'SPEC-20261012-0002',
        specimenType: 'Whole Blood',
        specimenStatus: 'RECEIVED',
        orderStatus: 'PROCESSING',
        urgency: 'STAT',
        results: [
          LabResultItemModel(
            parameterName: 'Haemoglobin',
            valueText: '11.8',
            unit: 'g/dL',
            flag: 'NORMAL',
          ),
        ],
      ),
      const LabOrderModel(
        id: 'ord-103',
        orderNumber: 'LAB-20261012-0003',
        visitId: 'vis-103',
        patientId: 'pat-103',
        uhid: 'UHID-20261012-0003',
        patientName: 'Kavita Verma',
        patientAge: 38,
        patientGender: 'FEMALE',
        department: 'Microbiology',
        testName: 'HIV',
        specimenId: 'SPEC-20261012-0003',
        specimenType: 'Serum',
        specimenStatus: 'COMPLETED',
        orderStatus: 'COMPLETED',
        isSensitive: true,
        verifiedByName: 'Dr. Sarah Chen',
        verifiedAt: '2026-10-12T14:30:00Z',
        results: [
          LabResultItemModel(
            parameterName: 'HIV 1 & 2 Rapid Antibody',
            valueText: 'Non-Reactive',
            flag: 'NORMAL',
          ),
        ],
      ),
    ];
  }

  @override
  Future<LabReportDataModel> getPrintableReport(String orderId) async {
    return const LabReportDataModel(
      hospitalName: 'OPD CONNECT+ HOSPITAL',
      hospitalAddress: 'General Hospital Campus, Medical Enclave',
      hospitalPhone: '+1-555-OPD-CARE',
      orderId: 'ord-103',
      orderNumber: 'LAB-20261012-0003',
      specimenId: 'SPEC-20261012-0003',
      uhid: 'UHID-20261012-0003',
      patientName: 'Kavita Verma',
      patientAge: 38,
      patientGender: 'FEMALE',
      testName: 'HIV',
      department: 'Microbiology',
      specimenType: 'Serum',
      specimenStatus: 'COMPLETED',
      orderStatus: 'COMPLETED',
      isSensitive: true,
      collectionTime: '2026-10-12T10:00:00Z',
      collectedByName: 'Phlebotomist Anil',
      receivedAt: '2026-10-12T10:30:00Z',
      receivedByName: 'Technician Maya',
      verifiedByName: 'Dr. Sarah Chen, MD',
      verifiedAt: '2026-10-12T14:30:00Z',
      verificationNotes: 'Antibody screening verified negative on duplicate run.',
      reportGeneratedAt: '2026-10-12T14:35:00Z',
      parameters: [
        LabResultItemModel(
          parameterName: 'HIV 1 & 2 Rapid Antibody',
          valueText: 'Non-Reactive',
          flag: 'NORMAL',
        ),
      ],
    );
  }
}

void main() {
  final mockRepo = MockLaboratoryRepository();

  Widget buildTestApp(Widget child, {bool scrollable = false}) {
    return ProviderScope(
      overrides: [
        laboratoryRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: scrollable ? SingleChildScrollView(child: child) : child,
        ),
      ),
    );
  }

  test('LabCatalogueItem and LabOrderModel correctly parse OPD booklet structure', () {
    const item = LabCatalogueItem(
      id: 'cat-gtt',
      category: 'BIOCHEMISTRY',
      testName: 'Glucose Tolerance Test (pregnancy)',
      sampleType: 'Fluoride Plasma',
      specimenTube: 'Grey Top',
      isSensitive: false,
    );

    expect(item.testName, 'Glucose Tolerance Test (pregnancy)');
    expect(item.category, 'BIOCHEMISTRY');
    expect(item.isSensitive, false);

    const order = LabOrderModel(
      id: 'ord-vdrl',
      orderNumber: 'LAB-20261012-0004',
      visitId: 'vis-104',
      patientId: 'pat-104',
      department: 'Microbiology',
      testName: 'VDRL',
      specimenType: 'Serum',
      isSensitive: true,
    );

    expect(order.testName, 'VDRL');
    expect(order.isSensitive, true);
    expect(order.specimenStatus, 'ORDERED');
  });

  testWidgets('LaboratoryWorkspaceView renders metrics, departments, tabs, and orders', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1000));

    await tester.pumpWidget(buildTestApp(const LaboratoryWorkspaceView(), scrollable: true));
    await tester.pumpAndSettle();

    // Verify Title & Catalogue button
    expect(find.text('Laboratory Operations Portal'), findsOneWidget);
    expect(find.text('Catalogue'), findsOneWidget);

    // Verify KPI Metrics
    expect(find.text('To Collect'), findsWidgets);
    expect(find.text('In-Lab'), findsOneWidget);
    expect(find.text('Processing'), findsWidgets);
    expect(find.text('To Verify'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Rejected'), findsWidgets);

    // Verify Department filter chips
    expect(find.text('Biochemistry'), findsWidgets);
    expect(find.text('Haematology'), findsWidgets);
    expect(find.text('Microbiology'), findsWidgets);

    // Verify Orders
    expect(find.text('Glucose Fasting'), findsOneWidget);
    expect(find.text('Haemoglobin (Hb)'), findsOneWidget);
    expect(find.text('HIV'), findsOneWidget);
    expect(find.text('SENSITIVE'), findsOneWidget);
  });

  testWidgets('SpecimenLabelDialog displays thermal tube barcode information', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    const order = LabOrderModel(
      id: 'ord-label-1',
      orderNumber: 'LAB-20261012-0001',
      visitId: 'vis-1',
      patientId: 'pat-1',
      uhid: 'UHID-20261012-0001',
      patientName: 'Ramesh Patel',
      patientAge: 45,
      patientGender: 'MALE',
      department: 'Biochemistry',
      testName: 'Glucose Fasting',
      specimenId: 'SPEC-20261012-0001',
      specimenType: 'Fluoride Plasma',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SpecimenLabelDialog(order: order),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Specimen Barcode Label'), findsOneWidget);
    expect(find.text('OPD CONNECT+ LAB'), findsOneWidget);
    expect(find.text('RAMESH PATEL'), findsOneWidget);
    expect(find.text('UHID: UHID-20261012-0001'), findsOneWidget);
    expect(find.text('TEST: Glucose Fasting'), findsOneWidget);
    expect(find.text('SPEC-20261012-0001'), findsOneWidget);
    expect(find.text('Print Label'), findsOneWidget);
  });

  testWidgets('SpecimenCollectionDialog renders collector fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    const order = LabOrderModel(
      id: 'ord-col-1',
      orderNumber: 'LAB-20261012-0001',
      visitId: 'vis-1',
      patientId: 'pat-1',
      uhid: 'UHID-20261012-0001',
      patientName: 'Ramesh Patel',
      department: 'Biochemistry',
      testName: 'Glucose Fasting',
      specimenType: 'Blood',
    );

    await tester.pumpWidget(buildTestApp(SpecimenCollectionDialog(order: order)));
    await tester.pumpAndSettle();

    expect(find.text('Record Specimen Collection'), findsOneWidget);
    expect(find.text('Confirm Collection'), findsOneWidget);
    expect(find.text('Phlebotomist / Collector Name'), findsOneWidget);
  });

  testWidgets('VerificationDialog renders pathologist sign-off checklist', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 1000));
    const order = LabOrderModel(
      id: 'ord-ver-1',
      orderNumber: 'LAB-20261012-0002',
      visitId: 'vis-2',
      patientId: 'pat-2',
      uhid: 'UHID-20261012-0002',
      patientName: 'Sunita Rao',
      department: 'Haematology',
      testName: 'Haemoglobin (Hb)',
      specimenId: 'SPEC-20261012-0002',
      specimenType: 'Whole Blood',
      results: [
        LabResultItemModel(
          parameterName: 'Haemoglobin',
          valueText: '11.8',
          unit: 'g/dL',
          flag: 'NORMAL',
        ),
      ],
    );

    await tester.pumpWidget(buildTestApp(VerificationDialog(order: order)));
    await tester.pumpAndSettle();

    expect(find.text('Pathologist Verification & Sign-off'), findsOneWidget);
    expect(find.text('Test Results Summary'), findsOneWidget);
    expect(find.text('Haemoglobin'), findsOneWidget);
    expect(find.text('11.8'), findsOneWidget);
    expect(find.text('Sign & Publish'), findsOneWidget);
  });

  testWidgets('LaboratoryReportScreen renders printable hospital header and verification seal', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));

    await tester.pumpWidget(buildTestApp(const LaboratoryReportScreen(orderId: 'ord-103')));
    await tester.pumpAndSettle();

    expect(find.text('Laboratory Report'), findsOneWidget);
    expect(find.text('OPD CONNECT+ HOSPITAL'), findsOneWidget);
    expect(find.text('DEPARTMENT OF PATHOLOGY & LABORATORY MEDICINE'), findsOneWidget);
    expect(find.text('INVESTIGATION: HIV'), findsOneWidget);
    expect(find.text('CONFIDENTIAL MEDICAL RECORD: Restricted Access under Healthcare Privacy Rules'), findsOneWidget);
    expect(find.text('DIGITALLY VERIFIED LABORATORY REPORT'), findsOneWidget);
    expect(find.text('Verified by: Dr. Sarah Chen, MD'), findsOneWidget);
  });
}
