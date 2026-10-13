import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';
import 'package:opd_connect/features/documents/repositories/document_repository.dart';
import 'package:opd_connect/features/documents/providers/document_provider.dart';
import 'package:opd_connect/features/documents/screens/document_capture_screen.dart';
import 'package:opd_connect/features/documents/screens/document_ocr_verification_screen.dart';
import 'package:opd_connect/features/documents/screens/document_manager_workspace_view.dart';
import 'package:opd_connect/features/documents/widgets/barcode_scanner_modal.dart';

class MockDocumentRepository extends DocumentRepository {
  MockDocumentRepository() : super(DioClient());

  @override
  Future<List<MedicalDocumentModel>> getDocumentsByPatient(
    String patientId, {
    String? documentType,
    String? verificationStatus,
  }) async {
    return [
      const MedicalDocumentModel(
        id: 'doc-test-1',
        patientId: 'pat-1',
        visitId: 'vis-1',
        documentType: 'OPD_BOOKLET_SCAN',
        fileName: 'opd_booklet_consultation_sheet.pdf',
        fileSizeBytes: 245000,
        mimeType: 'application/pdf',
        pageCount: 2,
        checksumSha256: 'a1b2c3d4e5f6789012345678abcdef0123456789abcdef0123456789abcdef01',
        isVerified: true,
        verificationStatus: 'VERIFIED',
        createdAt: '2026-10-12T10:00:00Z',
      ),
      const MedicalDocumentModel(
        id: 'doc-test-2',
        patientId: 'pat-1',
        visitId: 'vis-1',
        documentType: 'PRESCRIPTION_SCAN',
        fileName: 'handwritten_prescription_pad.jpg',
        fileSizeBytes: 180000,
        mimeType: 'image/jpeg',
        pageCount: 1,
        checksumSha256: 'f6e5d4c3b2a109876543210fedcba09876543210fedcba09876543210fedcba',
        isVerified: false,
        verificationStatus: 'IN_REVIEW',
        createdAt: '2026-10-12T11:00:00Z',
      ),
    ];
  }

  @override
  Future<MedicalDocumentModel> getDocument(String documentId) async {
    return const MedicalDocumentModel(
      id: 'doc-test-1',
      patientId: 'pat-1',
      visitId: 'vis-1',
      documentType: 'OPD_BOOKLET_SCAN',
      fileName: 'opd_booklet_consultation_sheet.pdf',
      fileSizeBytes: 245000,
      mimeType: 'application/pdf',
      pageCount: 2,
      checksumSha256: 'a1b2c3d4e5f6789012345678abcdef0123456789abcdef0123456789abcdef01',
      isVerified: false,
      verificationStatus: 'IN_REVIEW',
      createdAt: '2026-10-12T10:00:00Z',
    );
  }

  @override
  Future<List<DocumentOcrFieldModel>> getOcrFields(String documentId) async {
    return [
      const DocumentOcrFieldModel(
        id: 'field-1',
        documentId: 'doc-test-1',
        pageNumber: 1,
        fieldCategory: 'PATIENT_IDENTIFIER',
        fieldName: 'uhid',
        rawText: 'UHID: UHID-2026-0001',
        normalizedValue: 'UHID-2026-0001',
        confidence: 0.98,
        isUncertain: false,
        isHandwritten: false,
        verificationStatus: 'CONFIRMED',
      ),
      const DocumentOcrFieldModel(
        id: 'field-2',
        documentId: 'doc-test-1',
        pageNumber: 1,
        fieldCategory: 'OBSERVATION',
        fieldName: 'vital_signs',
        rawText: 'BP 120/80 mmHg, Pulse 76 bpm',
        normalizedValue: '{"bp":"120/80","pulse":76}',
        confidence: 0.88,
        isUncertain: false,
        isHandwritten: false,
        verificationStatus: 'CONFIRMED',
      ),
      const DocumentOcrFieldModel(
        id: 'field-3',
        documentId: 'doc-test-1',
        pageNumber: 1,
        fieldCategory: 'PRESCRIPTION',
        fieldName: 'medication_item',
        rawText: 'Tab. Paracetamol 500mg - 1 tab TID x 3 days',
        normalizedValue: '{"medicine_name":"Paracetamol","dosage":"500mg"}',
        confidence: 0.65, // Uncertain / handwritten script
        isUncertain: true,
        isHandwritten: true,
        verificationStatus: 'UNVERIFIED',
      ),
    ];
  }

  @override
  Future<SignedUrlModel> generateSignedUrl(String documentId, {int validityMinutes = 15}) async {
    return SignedUrlModel(
      documentId: documentId,
      accessToken: 'token-abc-123',
      previewUrl: '/api/v1/documents/preview/token-abc-123',
      expiresAt: '2026-10-12T15:30:00Z',
      isShortLived: true,
      validityMinutes: validityMinutes,
    );
  }

  @override
  Future<BarcodeIdentifierModel> generateBarcode({
    required String identifierType,
    required String resourceId,
    String? labelText,
  }) async {
    return BarcodeIdentifierModel(
      identifierType: identifierType,
      token: '$identifierType:$resourceId',
      format: 'QR_CODE',
      labelText: labelText ?? '$identifierType: $resourceId',
      isNonSensitive: true,
    );
  }

  @override
  Future<BarcodeScanResultModel> scanBarcode(String scannedPayload) async {
    return BarcodeScanResultModel(
      identifierType: 'PATIENT',
      resourceId: 'UHID-2026-0001',
      displayTitle: 'Satya Narayan (UHID-2026-0001)',
      metadata: {
        'uhid': 'UHID-2026-0001',
        'name': 'Satya Narayan',
        'phone': '+91 9876543210',
        'gender': 'Male',
      },
      isValid: true,
    );
  }

  @override
  Future<List<DocumentAuditLogModel>> getDocumentAuditLogs(String documentId) async {
    return [
      const DocumentAuditLogModel(
        id: 'log-1',
        documentId: 'doc-test-1',
        userId: 'user-doc',
        action: 'UPLOAD',
        ipAddress: '127.0.0.1',
        createdAt: '2026-10-12T10:00:00Z',
      ),
      const DocumentAuditLogModel(
        id: 'log-2',
        documentId: 'doc-test-1',
        userId: 'user-doc',
        action: 'DOWNLOAD',
        ipAddress: '127.0.0.1',
        createdAt: '2026-10-12T10:15:00Z',
      ),
    ];
  }
}

void main() {
  testWidgets('DocumentCaptureScreen renders page viewfinder, reel, rotate, and PDF preview', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: DocumentCaptureScreen(
            patientUhid: 'UHID-2026-0001',
            patientName: 'Satya Narayan',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Medical Document Capture'), findsOneWidget);
    expect(find.text('Page 1'), findsWidgets);
    expect(find.text('Crop Page'), findsOneWidget);
    expect(find.text('Rotate 90°'), findsOneWidget);
    expect(find.text('Perspective Correction'), findsOneWidget);
    expect(find.text('Multipage PDF Preview'), findsOneWidget);
    expect(find.text('Review Before Upload'), findsOneWidget);

    // Test Rotate 90 degrees
    await tester.tap(find.text('Rotate 90°'));
    await tester.pumpAndSettle();
    expect(find.text('90° rotation'), findsOneWidget);

    // Test Multipage PDF preview
    await tester.tap(find.text('Multipage PDF Preview'));
    await tester.pumpAndSettle();
    expect(find.text('OPD CONNECT+ CLINICAL ARCHIVE'), findsOneWidget);
    expect(find.text('Close Preview'), findsOneWidget);

    await tester.tap(find.text('Close Preview'));
    await tester.pumpAndSettle();
  });

  testWidgets('DocumentCaptureScreen renders permission-denied modal with explanation and fallback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: DocumentCaptureScreen(
            patientUhid: 'UHID-2026-0001',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Toggle simulated permission denied
    await tester.tap(find.byTooltip('Toggle Camera Permission'));
    await tester.pumpAndSettle();

    expect(find.text('Camera Permission Denied'), findsOneWidget);
    expect(find.text('Grant Access'), findsOneWidget);
    expect(find.text('Use Gallery'), findsOneWidget);

    // Fallback to gallery resolves block
    await tester.tap(find.text('Use Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Camera Permission Denied'), findsNothing);
  });

  testWidgets('DocumentCaptureScreen renders offline banner with local queue option', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: DocumentCaptureScreen(
            patientUhid: 'UHID-2026-0001',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Toggle offline mode
    await tester.tap(find.byIcon(Icons.wifi));
    await tester.pumpAndSettle();

    expect(find.text('Offline Mode - Local Queue Available'), findsOneWidget);
    expect(find.text('Queue Locally'), findsOneWidget);
  });

  testWidgets('DocumentOcrVerificationScreen renders side-by-side view, confidence, and handwritten safety badge', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 950));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: DocumentOcrVerificationScreen(documentId: 'doc-test-1'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('OCR Clinical Verification'), findsOneWidget);
    expect(find.text('Clinical Safety Requirement: Manual Clinician Review Mandatory'), findsOneWidget);
    expect(find.text('Source Document Scan (Original Preserved)'), findsOneWidget);
    expect(find.text('Extracted Clinical Fields & Confidence'), findsOneWidget);

    // Verify confidence indicators
    expect(find.text('98% Conf'), findsOneWidget);
    expect(find.text('65% Conf'), findsOneWidget); // Uncertain

    // Verify handwritten prescription safety badge
    expect(find.text('Handwritten Medication - Clinician Sign-Off Required'), findsOneWidget);

    // Verify actions
    expect(find.text('Clinician Sign-off & Finalize'), findsOneWidget);
  });

  testWidgets('BarcodeScannerModal renders identifier generator and scanner with non-sensitive policy', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: BarcodeScannerModal(
              initialResourceId: 'UHID-2026-0001',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Barcode & QR Identifier Manager'), findsOneWidget);
    expect(find.text('Non-sensitive Identifier Policy: QR codes encode reference tokens only (e.g. UHID:xxxx). Confidential medical histories, clinical diagnoses, or payment credentials are never embedded directly in QR codes.'), findsOneWidget);
    expect(find.text('Generate Verified QR Identifier'), findsOneWidget);

    // Switch to Scanner Tab
    await tester.tap(find.text('Scan Barcode / QR'));
    await tester.pumpAndSettle();

    expect(find.text('Position QR or Barcode within reticle'), findsOneWidget);
    expect(find.text('Quick Test Barcodes:'), findsOneWidget);
    expect(find.text('Resolve'), findsOneWidget);

    // Test resolve using quick test chip
    await tester.tap(find.text('UHID:UHID-2026-0001'));
    await tester.pumpAndSettle();

    expect(find.text('Satya Narayan (UHID-2026-0001)'), findsOneWidget);
  });

  testWidgets('DocumentManagerWorkspaceView renders document archive, search, filters, and actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          documentRepositoryProvider.overrideWithValue(MockDocumentRepository()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: DocumentManagerWorkspaceView(
              patientUhid: 'UHID-2026-0001',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Medical Documents & OCR Archive'), findsOneWidget);
    expect(find.text('Capture / Upload Document'), findsOneWidget);
    expect(find.text('Scan / Generate Barcode'), findsOneWidget);
    expect(find.text('opd_booklet_consultation_sheet.pdf'), findsOneWidget);
    expect(find.text('handwritten_prescription_pad.jpg'), findsOneWidget);
    expect(find.text('Review OCR Extractions'), findsWidgets);
    expect(find.text('15-Min Signed Link'), findsWidgets);
    expect(find.text('Audit History'), findsWidgets);
  });
}
