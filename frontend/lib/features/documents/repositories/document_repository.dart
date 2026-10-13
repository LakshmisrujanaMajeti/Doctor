import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:opd_connect/core/network/dio_client.dart';
import 'package:opd_connect/core/network/api_endpoints.dart';
import 'package:opd_connect/features/documents/models/document_models.dart';

class DocumentRepository {
  final DioClient _client;

  DocumentRepository(this._client);

  Future<MedicalDocumentModel> uploadDocument({
    required String patientId,
    required String fileName,
    required Uint8List fileBytes,
    String documentType = 'OPD_BOOKLET_SCAN',
    String? visitId,
    String? description,
    int pageCount = 1,
    ProgressCallback? onSendProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      'patient_id': patientId,
      'document_type': documentType,
      if (visitId != null) 'visit_id': visitId,
      if (description != null) 'description': description,
      'page_count': pageCount,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      ),
    });

    final response = await _client.dio.post(
      ApiEndpoints.uploadDocument,
      data: formData,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    );

    return MedicalDocumentModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<MedicalDocumentModel>> getDocumentsByPatient(
    String patientId, {
    String? documentType,
    String? verificationStatus,
  }) async {
    final response = await _client.dio.get(
      ApiEndpoints.documentsByPatient(patientId),
      queryParameters: {
        if (documentType != null) 'document_type': documentType,
        if (verificationStatus != null) 'verification_status': verificationStatus,
      },
    );

    final list = response.data['data'] as List<dynamic>;
    return list.map((d) => MedicalDocumentModel.fromJson(d as Map<String, dynamic>)).toList();
  }

  Future<MedicalDocumentModel> getDocument(String documentId) async {
    final response = await _client.dio.get(ApiEndpoints.documentById(documentId));
    return MedicalDocumentModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String documentId) async {
    await _client.dio.delete(ApiEndpoints.documentById(documentId));
  }

  Future<SignedUrlModel> generateSignedUrl(String documentId, {int validityMinutes = 15}) async {
    final response = await _client.dio.post(
      ApiEndpoints.documentSignedUrl(documentId),
      queryParameters: {'validity_minutes': validityMinutes},
    );
    return SignedUrlModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DocumentOcrFieldModel>> triggerOcr(String documentId, {String? rawText}) async {
    final response = await _client.dio.post(
      ApiEndpoints.documentOcrExtract(documentId),
      data: FormData.fromMap({
        if (rawText != null) 'raw_text': rawText,
      }),
    );
    final list = response.data['data'] as List<dynamic>;
    return list.map((e) => DocumentOcrFieldModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<DocumentOcrFieldModel>> getOcrFields(String documentId) async {
    final response = await _client.dio.get(ApiEndpoints.documentOcr(documentId));
    final list = response.data['data'] as List<dynamic>;
    return list.map((e) => DocumentOcrFieldModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DocumentOcrFieldModel> verifyField({
    required String documentId,
    required String extractionId,
    required String status,
    String? verifiedValue,
    String? rejectionReason,
  }) async {
    final response = await _client.dio.put(
      ApiEndpoints.documentVerifyField(documentId, extractionId),
      data: {
        'verification_status': status,
        if (verifiedValue != null) 'verified_value': verifiedValue,
        if (rejectionReason != null) 'rejection_reason': rejectionReason,
      },
    );
    return DocumentOcrFieldModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<MedicalDocumentModel> verifyAllFields(String documentId, {String? clinicianNotes}) async {
    final response = await _client.dio.post(
      ApiEndpoints.documentVerifyAll(documentId),
      data: {
        if (clinicianNotes != null) 'clinician_notes': clinicianNotes,
      },
    );
    return MedicalDocumentModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> applyToVisit({
    required String documentId,
    required String visitId,
    bool applyVitals = true,
    bool applyComplaints = true,
    bool applyDiagnosis = true,
    bool applyPrescriptions = true,
    bool applyLabOrders = true,
  }) async {
    final response = await _client.dio.post(
      ApiEndpoints.documentApplyToVisit(documentId),
      data: {
        'visit_id': visitId,
        'apply_vitals': applyVitals,
        'apply_complaints': applyComplaints,
        'apply_diagnosis': applyDiagnosis,
        'apply_prescriptions': applyPrescriptions,
        'apply_lab_orders': applyLabOrders,
      },
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<BarcodeIdentifierModel> generateBarcode({
    required String identifierType,
    required String resourceId,
    String? labelText,
  }) async {
    final response = await _client.dio.post(
      ApiEndpoints.barcodeGenerate,
      data: {
        'identifier_type': identifierType,
        'resource_id': resourceId,
        if (labelText != null) 'label_text': labelText,
      },
    );
    return BarcodeIdentifierModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<BarcodeScanResultModel> scanBarcode(String scannedPayload) async {
    final response = await _client.dio.post(
      ApiEndpoints.barcodeScan,
      data: {'scanned_payload': scannedPayload},
    );
    return BarcodeScanResultModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<DocumentAuditLogModel>> getDocumentAuditLogs(String documentId) async {
    final response = await _client.dio.get(ApiEndpoints.documentAuditLogs(documentId));
    final list = response.data['data'] as List<dynamic>;
    return list.map((l) => DocumentAuditLogModel.fromJson(l as Map<String, dynamic>)).toList();
  }
}
