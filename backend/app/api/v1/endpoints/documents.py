from typing import Optional, List
from fastapi import APIRouter, Depends, UploadFile, File, Form, Request, Query, status
from fastapi.responses import FileResponse, Response
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.responses import success_response
from app.core.dependencies import get_current_user
from app.core.exceptions import NotFoundException, ForbiddenException
from app.models.document import MedicalDocument, DocumentOCRExtraction, DocumentAuditLog
from app.models.user import User
from app.schemas.document import (
    MedicalDocumentRead,
    DocumentOCRExtractionRead,
    FieldVerificationRequest,
    DocumentVerifyAllRequest,
    ApplyToVisitRequest,
    SignedUrlResponse,
    BarcodeGenerateRequest,
    BarcodeGenerateResponse,
    BarcodeScanRequest,
    BarcodeScanResponse,
    DocumentAuditLogRead,
)
from app.services.document_service import DocumentService
from app.services.barcode_service import BarcodeService

router = APIRouter()


@router.post("/upload", status_code=status.HTTP_201_CREATED, summary="Upload Medical Document Scan")
async def upload_document(
    request: Request,
    patient_id: str = Form(...),
    document_type: str = Form("OPD_BOOKLET_SCAN"),
    visit_id: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    page_count: int = Form(1),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Securely uploads a medical document with file-size and MIME type validation,
    calculates a SHA-256 integrity checksum, and logs the upload audit.
    """
    doc = await DocumentService.upload_document(
        db=db,
        patient_id=patient_id,
        file=file,
        document_type=document_type,
        visit_id=visit_id,
        description=description,
        page_count=page_count,
        current_user=current_user,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(
        data=MedicalDocumentRead.model_validate(doc).model_dump(),
        message="Medical document uploaded and secured successfully",
        status_code=201,
    )


@router.get("/patient/{patient_id}", summary="List Documents for Patient")
def list_patient_documents(
    patient_id: str,
    document_type: Optional[str] = Query(None),
    verification_status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Lists all active documents for a patient with optional type and status filtering."""
    query = db.query(MedicalDocument).filter(
        MedicalDocument.patient_id == patient_id,
        MedicalDocument.is_deleted == False,
    )
    if document_type:
        query = query.filter(MedicalDocument.document_type == document_type)
    if verification_status:
        query = query.filter(MedicalDocument.verification_status == verification_status)

    docs = query.order_by(MedicalDocument.created_at.desc()).all()
    return success_response(
        data=[MedicalDocumentRead.model_validate(d).model_dump() for d in docs],
        message="Patient documents retrieved",
    )


@router.get("/{document_id}", summary="Get Medical Document Details")
def get_document_details(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieves document metadata, pages, and OCR extractions."""
    doc = DocumentService.get_document(
        db=db,
        doc_id=document_id,
        current_user=current_user,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        log_view=True,
    )
    return success_response(
        data=MedicalDocumentRead.model_validate(doc).model_dump(),
        message="Medical document retrieved",
    )


@router.get("/{document_id}/download", summary="Download Original Document")
def download_document(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Downloads original file with authorization enforcement and audit tracking.
    """
    doc = DocumentService.get_document(db=db, doc_id=document_id, current_user=current_user)
    
    DocumentService.log_audit(
        db=db,
        document_id=doc.id,
        user_id=current_user.id,
        action="DOWNLOAD",
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        details={"file_name": doc.file_name},
    )

    return FileResponse(
        path=doc.file_path,
        filename=doc.file_name,
        media_type=doc.mime_type,
    )


@router.post("/{document_id}/signed-url", summary="Generate Short-lived Signed Preview Link")
def generate_signed_preview_url(
    document_id: str,
    request: Request,
    validity_minutes: int = Query(15, ge=1, le=60),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Generates an expiring HMAC-SHA256 signed URL for authorized temporary preview.
    """
    doc = DocumentService.get_document(db=db, doc_id=document_id, current_user=current_user)
    link_data = DocumentService.generate_signed_access_url(
        doc=doc,
        user_id=current_user.id,
        validity_minutes=validity_minutes,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
        db=db,
    )
    return success_response(
        data=link_data,
        message=f"Short-lived signed access link generated (expires in {validity_minutes} minutes)",
    )


@router.get("/preview/{token}", summary="Preview Document via Signed Link")
def preview_signed_document(
    token: str,
    request: Request,
    db: Session = Depends(get_db),
):
    """
    Validates HMAC signature and expiration timestamp to stream document preview.
    No session bearer header required, making it safe for image components and webviews.
    """
    doc = DocumentService.verify_signed_token(db=db, token=token)
    
    DocumentService.log_audit(
        db=db,
        document_id=doc.id,
        user_id=None,
        action="PREVIEW_VIA_SIGNED_LINK",
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )

    return FileResponse(
        path=doc.file_path,
        filename=doc.file_name,
        media_type=doc.mime_type,
    )


@router.delete("/{document_id}", summary="Delete Document")
def delete_document(
    document_id: str,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Soft deletes document and records deletion in audit trail."""
    DocumentService.delete_document(
        db=db,
        doc_id=document_id,
        current_user=current_user,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(message="Medical document deleted successfully")


# -------------------------------------------------------------
# OCR Extraction & Verification Endpoints
# -------------------------------------------------------------
@router.post("/{document_id}/ocr/extract", summary="Trigger OCR Extraction")
def trigger_ocr(
    document_id: str,
    request: Request,
    raw_text: Optional[str] = Form(None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Extracts text, patient identifiers, vitals, test names, prescriptions, and invoice fields.
    Flags uncertain text and preserves bounding boxes and confidence metrics.
    """
    extractions = DocumentService.trigger_ocr_extraction(
        db=db,
        doc_id=document_id,
        current_user=current_user,
        raw_text_content=raw_text,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(
        data=[DocumentOCRExtractionRead.model_validate(e).model_dump() for e in extractions],
        message=f"OCR processed successfully. Extracted {len(extractions)} fields with confidence scores.",
    )


@router.get("/{document_id}/ocr", summary="Get OCR Extracted Fields")
def get_ocr_extractions(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieves all OCR extracted fields for review alongside source bounding boxes."""
    doc = DocumentService.get_document(db=db, doc_id=document_id, current_user=current_user)
    extractions = db.query(DocumentOCRExtraction).filter(
        DocumentOCRExtraction.document_id == doc.id
    ).order_by(DocumentOCRExtraction.page_number, DocumentOCRExtraction.field_category).all()

    return success_response(
        data=[DocumentOCRExtractionRead.model_validate(e).model_dump() for e in extractions],
        message="OCR fields retrieved",
    )


@router.put("/{document_id}/ocr/{extraction_id}/verify", summary="Verify Individual OCR Field")
def verify_ocr_field(
    document_id: str,
    extraction_id: str,
    payload: FieldVerificationRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Allows authorized staff to confirm, edit, or reject an extracted OCR field.
    STRICT POLICY: Handwritten prescriptions & medication dosages require authorized clinician role.
    """
    ext = DocumentService.verify_ocr_field(
        db=db,
        extraction_id=extraction_id,
        current_user=current_user,
        verification_status=payload.verification_status,
        verified_value=payload.verified_value,
        rejection_reason=payload.rejection_reason,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(
        data=DocumentOCRExtractionRead.model_validate(ext).model_dump(),
        message=f"Field '{ext.field_name}' verification updated to {payload.verification_status}",
    )


@router.post("/{document_id}/verify-all", summary="Clinician Final Document Sign-Off")
def verify_all_document(
    document_id: str,
    payload: DocumentVerifyAllRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Clinician sign-off confirming the document and all reviewed fields.
    Rejects if any handwritten medication remains unreviewed.
    """
    doc = DocumentService.verify_all_fields(
        db=db,
        doc_id=document_id,
        current_user=current_user,
        clinician_notes=payload.clinician_notes,
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(
        data=MedicalDocumentRead.model_validate(doc).model_dump(),
        message="Medical document fully verified and signed off by clinician",
    )


@router.post("/{document_id}/apply-to-visit", summary="Apply Verified Clinical Data to Visit Record")
def apply_to_visit(
    document_id: str,
    payload: ApplyToVisitRequest,
    request: Request,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Safely transfers verified clinical observations and prescriptions into the patient's visit.
    SAFETY BLOCK: Refuses to convert unverified or uncertain OCR items.
    """
    result = DocumentService.apply_verified_data_to_visit(
        db=db,
        doc_id=document_id,
        visit_id=payload.visit_id,
        current_user=current_user,
        options={
            "apply_vitals": payload.apply_vitals,
            "apply_complaints": payload.apply_complaints,
            "apply_diagnosis": payload.apply_diagnosis,
            "apply_prescriptions": payload.apply_prescriptions,
            "apply_lab_orders": payload.apply_lab_orders,
        },
        ip_address=request.client.host if request.client else None,
        user_agent=request.headers.get("user-agent"),
    )
    return success_response(
        data=result,
        message="Verified clinical data transferred to patient visit record successfully",
    )


# -------------------------------------------------------------
# Barcode & QR Endpoints
# -------------------------------------------------------------
@router.post("/barcode/generate", summary="Generate Non-sensitive Barcode or QR Identifier")
def generate_barcode(
    payload: BarcodeGenerateRequest,
    current_user: User = Depends(get_current_user),
):
    """
    Generates QR code tokens for patient registration, OPD visits, laboratory orders, and specimen labels.
    Enforces non-sensitive identifiers and refuses confidential medical history payloads.
    """
    result = BarcodeService.generate_identifier(
        identifier_type=payload.identifier_type,
        resource_id=payload.resource_id,
        label_text=payload.label_text or "",
    )
    return success_response(
        data=result,
        message="Non-sensitive QR code identifier generated",
    )


@router.post("/barcode/scan", summary="Scan and Resolve Barcode or QR Identifier")
def scan_barcode(
    payload: BarcodeScanRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """
    Resolves a scanned barcode/QR payload into patient, visit, or lab order records.
    """
    resolved = BarcodeService.scan_and_resolve(db=db, scanned_payload=payload.scanned_payload)
    return success_response(
        data=resolved,
        message="Barcode resolved successfully",
    )


@router.get("/{document_id}/audit-logs", summary="Get Document Audit History")
def get_document_audit_logs(
    document_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Retrieves complete audit trail of views, previews, downloads, verifications, and signed links."""
    doc = DocumentService.get_document(db=db, doc_id=document_id, current_user=current_user, include_deleted=True)
    logs = db.query(DocumentAuditLog).filter(
        DocumentAuditLog.document_id == doc.id
    ).order_by(DocumentAuditLog.created_at.desc()).all()

    return success_response(
        data=[DocumentAuditLogRead.model_validate(l).model_dump() for l in logs],
        message="Document audit logs retrieved",
    )
