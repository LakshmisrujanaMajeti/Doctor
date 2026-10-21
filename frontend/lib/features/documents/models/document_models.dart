import 'dart:convert';
import 'package:flutter/material.dart';

class MedicalDocumentModel {
  final String id;
  final String patientId;
  final String? visitId;
  final String documentType;
  final String fileName;
  final int fileSizeBytes;
  final String mimeType;
  final String storageBucket;
  final bool isPrivate;
  final String? description;
  final int pageCount;
  final String? checksumSha256;
  final bool isVerified;
  final String verificationStatus; // UNVERIFIED, IN_REVIEW, VERIFIED, REJECTED
  final String? verifiedByUserId;
  final String? verifiedAt;
  final String? createdAt;
  final List<DocumentPageModel>? pages;
  final List<DocumentOcrFieldModel>? ocrExtractions;

  const MedicalDocumentModel({
    required this.id,
    required this.patientId,
    this.visitId,
    required this.documentType,
    required this.fileName,
    required this.fileSizeBytes,
    required this.mimeType,
    this.storageBucket = 'medical-documents',
    this.isPrivate = true,
    this.description,
    this.pageCount = 1,
    this.checksumSha256,
    this.isVerified = false,
    this.verificationStatus = 'UNVERIFIED',
    this.verifiedByUserId,
    this.verifiedAt,
    this.createdAt,
    this.pages,
    this.ocrExtractions,
  });

  factory MedicalDocumentModel.fromJson(Map<String, dynamic> json) {
    return MedicalDocumentModel(
      id: json['id'] as String,
      patientId: json['patient_id'] as String,
      visitId: json['visit_id'] as String?,
      documentType: json['document_type'] as String? ?? 'OPD_BOOKLET_SCAN',
      fileName: json['file_name'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type'] as String? ?? 'application/pdf',
      storageBucket: json['storage_bucket'] as String? ?? 'medical-documents',
      isPrivate: json['is_private'] as bool? ?? true,
      description: json['description'] as String?,
      pageCount: (json['page_count'] as num?)?.toInt() ?? 1,
      checksumSha256: json['checksum_sha256'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String? ?? 'UNVERIFIED',
      verifiedByUserId: json['verified_by_user_id'] as String?,
      verifiedAt: json['verified_at'] as String?,
      createdAt: json['created_at'] as String?,
      pages: (json['pages'] as List<dynamic>?)
          ?.map((p) => DocumentPageModel.fromJson(p as Map<String, dynamic>))
          .toList(),
      ocrExtractions: (json['ocr_extractions'] as List<dynamic>?)
          ?.map((e) => DocumentOcrFieldModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'patient_id': patientId,
      'visit_id': visitId,
      'document_type': documentType,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'storage_bucket': storageBucket,
      'is_private': isPrivate,
      'description': description,
      'page_count': pageCount,
      'checksum_sha256': checksumSha256,
      'is_verified': isVerified,
      'verification_status': verificationStatus,
      'verified_by_user_id': verifiedByUserId,
      'verified_at': verifiedAt,
      'created_at': createdAt,
    };
  }
}

class DocumentPageModel {
  final String id;
  final String documentId;
  final int pageNumber;
  final String filePath;
  final int fileSizeBytes;
  final int width;
  final int height;
  final int rotationAngle;
  final bool hasPerspectiveCorrection;
  final bool contrastEnhanced;

  const DocumentPageModel({
    required this.id,
    required this.documentId,
    required this.pageNumber,
    required this.filePath,
    this.fileSizeBytes = 0,
    this.width = 1200,
    this.height = 1600,
    this.rotationAngle = 0,
    this.hasPerspectiveCorrection = false,
    this.contrastEnhanced = false,
  });

  factory DocumentPageModel.fromJson(Map<String, dynamic> json) {
    return DocumentPageModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      filePath: json['file_path'] as String,
      fileSizeBytes: (json['file_size_bytes'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 1200,
      height: (json['height'] as num?)?.toInt() ?? 1600,
      rotationAngle: (json['rotation_angle'] as num?)?.toInt() ?? 0,
      hasPerspectiveCorrection: json['has_perspective_correction'] as bool? ?? false,
      contrastEnhanced: json['contrast_enhanced'] as bool? ?? false,
    );
  }
}

class DocumentOcrFieldModel {
  final String id;
  final String documentId;
  final int pageNumber;
  final String fieldCategory; // PATIENT_IDENTIFIER, DATE, OBSERVATION, TEST_NAME, PRESCRIPTION, INVOICE
  final String fieldName;
  final String rawText;
  final String? normalizedValue;
  final double confidence; // 0.0 to 1.0
  final bool isUncertain;
  final bool isHandwritten;
  final String? boundingBoxJson;
  final String verificationStatus; // UNVERIFIED, CONFIRMED, EDITED, REJECTED
  final String? verifiedValue;
  final String? verifiedByUserId;
  final String? verifiedAt;
  final String? rejectionReason;

  const DocumentOcrFieldModel({
    required this.id,
    required this.documentId,
    this.pageNumber = 1,
    required this.fieldCategory,
    required this.fieldName,
    required this.rawText,
    this.normalizedValue,
    required this.confidence,
    required this.isUncertain,
    required this.isHandwritten,
    this.boundingBoxJson,
    this.verificationStatus = 'UNVERIFIED',
    this.verifiedValue,
    this.verifiedByUserId,
    this.verifiedAt,
    this.rejectionReason,
  });

  factory DocumentOcrFieldModel.fromJson(Map<String, dynamic> json) {
    return DocumentOcrFieldModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 1,
      fieldCategory: json['field_category'] as String,
      fieldName: json['field_name'] as String,
      rawText: json['raw_text'] as String,
      normalizedValue: json['normalized_value'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      isUncertain: json['is_uncertain'] as bool? ?? false,
      isHandwritten: json['is_handwritten'] as bool? ?? false,
      boundingBoxJson: json['bounding_box_json'] as String?,
      verificationStatus: json['verification_status'] as String? ?? 'UNVERIFIED',
      verifiedValue: json['verified_value'] as String?,
      verifiedByUserId: json['verified_by_user_id'] as String?,
      verifiedAt: json['verified_at'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  bool get isConfirmed => verificationStatus == 'CONFIRMED' || verificationStatus == 'EDITED';
  bool get isRejected => verificationStatus == 'REJECTED';
  bool get isPendingReview => verificationStatus == 'UNVERIFIED';

  Map<String, dynamic>? get parsedBoundingBox {
    if (boundingBoxJson == null || boundingBoxJson!.isEmpty) return null;
    try {
      return jsonDecode(boundingBoxJson!) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class SignedUrlModel {
  final String documentId;
  final String accessToken;
  final String previewUrl;
  final String expiresAt;
  final bool isShortLived;
  final int validityMinutes;

  const SignedUrlModel({
    required this.documentId,
    required this.accessToken,
    required this.previewUrl,
    required this.expiresAt,
    this.isShortLived = true,
    this.validityMinutes = 15,
  });

  factory SignedUrlModel.fromJson(Map<String, dynamic> json) {
    return SignedUrlModel(
      documentId: json['document_id'] as String,
      accessToken: json['access_token'] as String,
      previewUrl: json['preview_url'] as String,
      expiresAt: json['expires_at'] as String,
      isShortLived: json['is_short_lived'] as bool? ?? true,
      validityMinutes: (json['validity_minutes'] as num?)?.toInt() ?? 15,
    );
  }
}

class BarcodeIdentifierModel {
  final String identifierType;
  final String token;
  final String format;
  final String? svgData;
  final String? base64Png;
  final String labelText;
  final bool isNonSensitive;

  const BarcodeIdentifierModel({
    required this.identifierType,
    required this.token,
    this.format = 'QR_CODE',
    this.svgData,
    this.base64Png,
    required this.labelText,
    this.isNonSensitive = true,
  });

  factory BarcodeIdentifierModel.fromJson(Map<String, dynamic> json) {
    return BarcodeIdentifierModel(
      identifierType: json['identifier_type'] as String,
      token: json['token'] as String,
      format: json['format'] as String? ?? 'QR_CODE',
      svgData: json['svg_data'] as String?,
      base64Png: json['base64_png'] as String?,
      labelText: json['label_text'] as String? ?? '',
      isNonSensitive: json['is_non_sensitive'] as bool? ?? true,
    );
  }
}

class BarcodeScanResultModel {
  final String identifierType;
  final String resourceId;
  final String displayTitle;
  final Map<String, dynamic> metadata;
  final bool isValid;

  const BarcodeScanResultModel({
    required this.identifierType,
    required this.resourceId,
    required this.displayTitle,
    required this.metadata,
    this.isValid = true,
  });

  factory BarcodeScanResultModel.fromJson(Map<String, dynamic> json) {
    return BarcodeScanResultModel(
      identifierType: json['identifier_type'] as String,
      resourceId: json['resource_id'] as String,
      displayTitle: json['display_title'] as String,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
      isValid: json['is_valid'] as bool? ?? true,
    );
  }
}

class DocumentAuditLogModel {
  final String id;
  final String documentId;
  final String? userId;
  final String action;
  final String? ipAddress;
  final String? userAgent;
  final String? detailsJson;
  final String createdAt;

  const DocumentAuditLogModel({
    required this.id,
    required this.documentId,
    this.userId,
    required this.action,
    this.ipAddress,
    this.userAgent,
    this.detailsJson,
    required this.createdAt,
  });

  factory DocumentAuditLogModel.fromJson(Map<String, dynamic> json) {
    return DocumentAuditLogModel(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      userId: json['user_id'] as String?,
      action: json['action'] as String,
      ipAddress: json['ip_address'] as String?,
      userAgent: json['user_agent'] as String?,
      detailsJson: json['details_json'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// In-memory captured page state for mobile capture manipulation
class CapturedPageItem {
  final String id;
  int pageNumber;
  int rotationAngle; // 0, 90, 180, 270
  bool hasPerspectiveCorrection;
  bool contrastEnhanced;
  Rect? cropRect;
  String? label;

  CapturedPageItem({
    required this.id,
    required this.pageNumber,
    this.rotationAngle = 0,
    this.hasPerspectiveCorrection = false,
    this.contrastEnhanced = false,
    this.cropRect,
    this.label,
  });

  void rotateClockwise() {
    rotationAngle = (rotationAngle + 90) % 360;
  }

  void togglePerspectiveCorrection() {
    hasPerspectiveCorrection = !hasPerspectiveCorrection;
  }

  void toggleContrast() {
    contrastEnhanced = !contrastEnhanced;
  }
}
