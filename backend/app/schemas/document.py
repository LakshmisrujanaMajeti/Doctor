from datetime import datetime
from typing import List, Optional, Dict, Any
from pydantic import Field, field_validator
from app.schemas.common import BaseSchema


class DocumentPageRead(BaseSchema):
    id: str
    document_id: str
    page_number: int
    file_path: str
    file_size_bytes: int = 0
    width: int = 1200
    height: int = 1600
    rotation_angle: int = 0
    has_perspective_correction: bool = False
    contrast_enhanced: bool = False
    created_at: Optional[datetime] = None


class DocumentOCRExtractionRead(BaseSchema):
    id: str
    document_id: str
    page_number: int = 1
    field_category: str
    field_name: str
    raw_text: str
    normalized_value: Optional[str] = None
    confidence: float
    is_uncertain: bool
    is_handwritten: bool
    bounding_box_json: Optional[str] = None
    verification_status: str  # UNVERIFIED, CONFIRMED, EDITED, REJECTED
    verified_value: Optional[str] = None
    verified_by_user_id: Optional[str] = None
    verified_at: Optional[datetime] = None
    rejection_reason: Optional[str] = None


class FieldVerificationRequest(BaseSchema):
    verification_status: str  # CONFIRMED, EDITED, REJECTED
    verified_value: Optional[str] = None
    rejection_reason: Optional[str] = None

    @field_validator("verification_status")
    @classmethod
    def validate_status(cls, v: str) -> str:
        valid = ["CONFIRMED", "EDITED", "REJECTED"]
        if v.upper() not in valid:
            raise ValueError(f"Status must be one of {valid}")
        return v.upper()


class DocumentVerifyAllRequest(BaseSchema):
    clinician_notes: Optional[str] = None


class ApplyToVisitRequest(BaseSchema):
    visit_id: str
    apply_vitals: bool = True
    apply_complaints: bool = True
    apply_diagnosis: bool = True
    apply_prescriptions: bool = True
    apply_lab_orders: bool = True


class MedicalDocumentBase(BaseSchema):
    document_type: str = "OPD_BOOKLET_SCAN"
    file_name: str
    file_size_bytes: int
    mime_type: str
    description: Optional[str] = None


class MedicalDocumentCreate(MedicalDocumentBase):
    patient_id: str
    visit_id: Optional[str] = None
    file_path: Optional[str] = None


class MedicalDocumentRead(MedicalDocumentBase):
    id: str
    patient_id: str
    visit_id: Optional[str] = None
    file_path: str
    storage_bucket: str = "medical-documents"
    is_private: bool = True
    page_count: int = 1
    checksum_sha256: Optional[str] = None
    is_verified: bool = False
    verification_status: str = "UNVERIFIED"
    verified_by_user_id: Optional[str] = None
    verified_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    pages: Optional[List[DocumentPageRead]] = None
    ocr_extractions: Optional[List[DocumentOCRExtractionRead]] = None


class SignedUrlResponse(BaseSchema):
    document_id: str
    access_token: str
    preview_url: str
    expires_at: datetime
    is_short_lived: bool = True
    validity_minutes: int = 15


class BarcodeGenerateRequest(BaseSchema):
    identifier_type: str  # PATIENT, VISIT, LAB_ORDER, SPECIMEN
    resource_id: str
    label_text: Optional[str] = None

    @field_validator("identifier_type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        valid = ["PATIENT", "VISIT", "LAB_ORDER", "SPECIMEN"]
        if v.upper() not in valid:
            raise ValueError(f"Identifier type must be one of {valid}")
        return v.upper()


class BarcodeGenerateResponse(BaseSchema):
    identifier_type: str
    token: str  # e.g. UHID:UHID-2026-0001
    format: str = "QR_CODE"
    svg_data: Optional[str] = None
    base64_png: Optional[str] = None
    label_text: str
    is_non_sensitive: bool = True


class BarcodeScanRequest(BaseSchema):
    scanned_payload: str  # e.g. "UHID:UHID-2026-0001" or raw token string


class BarcodeScanResponse(BaseSchema):
    identifier_type: str
    resource_id: str
    display_title: str
    metadata: Dict[str, Any]
    is_valid: bool = True


class DocumentAuditLogRead(BaseSchema):
    id: str
    document_id: str
    user_id: Optional[str] = None
    action: str
    ip_address: Optional[str] = None
    user_agent: Optional[str] = None
    details_json: Optional[str] = None
    created_at: datetime
