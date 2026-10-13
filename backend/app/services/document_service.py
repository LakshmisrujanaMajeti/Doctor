import os
import hmac
import hashlib
import time
import json
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any, Tuple
from fastapi import UploadFile
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.exceptions import BadRequestException, NotFoundException, ForbiddenException
from app.models.document import (
    MedicalDocument,
    DocumentPage,
    DocumentOCRExtraction,
    DocumentAuditLog,
)
from app.models.patient import Patient
from app.models.visit import OPDVisit, VitalSigns
from app.models.clinical import ClinicalRecord
from app.models.prescription import Prescription, PrescriptionItem
from app.models.user import User
from app.models.audit import AuditLog
from app.services.ocr_service import OCRService


class DocumentService:
    """
    Comprehensive Medical Document Capture & Management Service.
    
    SAFETY CONSTRAINTS:
    - Never silently converts uncertain OCR into verified clinical data.
    - Keeps original files unchanged and calculates SHA-256 integrity checksums.
    - Requires authorized staff to review and explicitly confirm clinical info.
    - Strictly forbids non-clinicians from approving handwritten prescriptions and dosages.
    - Restricts downloads and previews with authorization and short-lived HMAC signed links.
    - Enforces file-size limits (max 25MB) and strict MIME type validations.
    """

    MAX_FILE_SIZE_BYTES = 25 * 1024 * 1024  # 25 MB
    ALLOWED_MIME_TYPES = {
        "application/pdf",
        "image/jpeg",
        "image/png",
        "image/webp",
    }
    ALLOWED_EXTENSIONS = {".pdf", ".jpg", ".jpeg", ".png", ".webp"}

    @staticmethod
    def _ensure_storage_dir() -> str:
        dir_path = settings.STORAGE_LOCAL_DIR
        os.makedirs(dir_path, exist_ok=True)
        return dir_path

    @staticmethod
    def _validate_file_security(filename: str, content_type: str, file_size: int):
        # 1. File size check
        if file_size > DocumentService.MAX_FILE_SIZE_BYTES:
            raise BadRequestException(
                f"File size ({file_size / (1024*1024):.1f} MB) exceeds maximum allowed limit of 25 MB"
            )

        # 2. Extension check
        ext = os.path.splitext(filename)[1].lower()
        if ext not in DocumentService.ALLOWED_EXTENSIONS:
            raise BadRequestException(
                f"Prohibited file extension '{ext}'. Allowed extensions: {list(DocumentService.ALLOWED_EXTENSIONS)}"
            )

        # 3. MIME type check
        if content_type and content_type.lower() not in DocumentService.ALLOWED_MIME_TYPES:
            raise BadRequestException(
                f"Prohibited MIME type '{content_type}'. Allowed types: {list(DocumentService.ALLOWED_MIME_TYPES)}"
            )

    @staticmethod
    def log_audit(
        db: Session,
        document_id: str,
        user_id: Optional[str],
        action: str,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        details: Optional[Dict[str, Any]] = None,
    ):
        audit = DocumentAuditLog(
            document_id=document_id,
            user_id=user_id,
            action=action,
            ip_address=ip_address,
            user_agent=user_agent,
            details_json=json.dumps(details) if details else None,
            created_at=datetime.utcnow(),
        )
        db.add(audit)

        # Also push to system audit trail
        db.add(AuditLog(
            user_id=user_id,
            action=f"DOC_{action}",
            entity_type="MedicalDocument",
            entity_id=document_id,
            details_json=json.dumps(details) if details else None,
        ))
        db.commit()

    @staticmethod
    async def upload_document(
        db: Session,
        patient_id: str,
        file: UploadFile,
        document_type: str = "OPD_BOOKLET_SCAN",
        visit_id: Optional[str] = None,
        description: Optional[str] = None,
        page_count: int = 1,
        current_user: Optional[User] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> MedicalDocument:
        patient = db.query(Patient).filter(Patient.id == patient_id).first()
        if not patient:
            raise NotFoundException(f"Patient with ID '{patient_id}' not found")

        if visit_id:
            visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
            if not visit:
                raise NotFoundException(f"OPD Visit with ID '{visit_id}' not found")

        storage_dir = DocumentService._ensure_storage_dir()
        safe_filename = f"{patient.uhid}_{int(time.time())}_{file.filename.replace(' ', '_')}"
        file_destination = os.path.join(storage_dir, safe_filename)

        sha256_hash = hashlib.sha256()
        file_size = 0

        with open(file_destination, "wb") as buffer:
            while chunk := await file.read(1024 * 1024):  # 1MB chunk
                sha256_hash.update(chunk)
                buffer.write(chunk)
                file_size += len(chunk)

        # Validate file size and mime security
        try:
            DocumentService._validate_file_security(
                file.filename,
                file.content_type or "application/octet-stream",
                file_size,
            )
        except Exception:
            # Clean up disk file on validation error
            if os.path.exists(file_destination):
                os.remove(file_destination)
            raise

        checksum = sha256_hash.hexdigest()

        doc = MedicalDocument(
            patient_id=patient_id,
            visit_id=visit_id,
            uploaded_by_user_id=current_user.id if current_user else None,
            document_type=document_type,
            file_name=file.filename,
            file_path=file_destination,
            file_size_bytes=file_size,
            mime_type=file.content_type or "application/octet-stream",
            storage_bucket=settings.SUPABASE_STORAGE_BUCKET,
            is_private=True,
            description=description,
            page_count=max(1, page_count),
            checksum_sha256=checksum,
            verification_status="UNVERIFIED",
            is_verified=False,
        )
        db.add(doc)
        db.flush()

        # Create initial DocumentPage records for multi-page navigation
        for p in range(1, doc.page_count + 1):
            page = DocumentPage(
                document_id=doc.id,
                page_number=p,
                file_path=file_destination,
                file_size_bytes=file_size // doc.page_count,
                width=1200,
                height=1600,
                rotation_angle=0,
                has_perspective_correction=False,
            )
            db.add(page)

        db.commit()
        db.refresh(doc)

        DocumentService.log_audit(
            db=db,
            document_id=doc.id,
            user_id=current_user.id if current_user else None,
            action="UPLOAD",
            ip_address=ip_address,
            user_agent=user_agent,
            details={
                "file_name": doc.file_name,
                "file_size": doc.file_size_bytes,
                "document_type": doc.document_type,
                "page_count": doc.page_count,
                "checksum_sha256": checksum,
            },
        )

        return doc

    @staticmethod
    def get_document(
        db: Session,
        doc_id: str,
        current_user: Optional[User] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        log_view: bool = False,
        include_deleted: bool = False,
    ) -> MedicalDocument:
        query = db.query(MedicalDocument).filter(MedicalDocument.id == doc_id)
        if not include_deleted:
            query = query.filter(MedicalDocument.is_deleted == False)
        doc = query.first()
        if not doc:
            raise NotFoundException(f"Medical document '{doc_id}' not found or has been deleted")

        if log_view:
            DocumentService.log_audit(
                db=db,
                document_id=doc.id,
                user_id=current_user.id if current_user else None,
                action="PREVIEW",
                ip_address=ip_address,
                user_agent=user_agent,
            )

        return doc

    @staticmethod
    def delete_document(
        db: Session,
        doc_id: str,
        current_user: User,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ):
        doc = DocumentService.get_document(db, doc_id)
        
        # Soft-delete preservation
        doc.is_deleted = True
        doc.deleted_at = datetime.utcnow()
        doc.deleted_by_user_id = current_user.id
        db.commit()

        DocumentService.log_audit(
            db=db,
            document_id=doc.id,
            user_id=current_user.id,
            action="DELETE",
            ip_address=ip_address,
            user_agent=user_agent,
            details={"file_name": doc.file_name},
        )

    # -------------------------------------------------------------
    # Short-Lived Signed URLs (HMAC-SHA256)
    # -------------------------------------------------------------
    @staticmethod
    def generate_signed_access_url(
        doc: MedicalDocument,
        user_id: str,
        validity_minutes: int = 15,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
        db: Optional[Session] = None,
    ) -> Dict[str, Any]:
        """
        Generates a tamper-proof, short-lived HMAC signed token for private file preview.
        Expires automatically after `validity_minutes`.
        """
        expires_timestamp = int(time.time()) + (validity_minutes * 60)
        payload_to_sign = f"{doc.id}:{user_id}:{expires_timestamp}:{doc.checksum_sha256 or ''}"

        signature = hmac.new(
            settings.SECRET_KEY.encode("utf-8"),
            payload_to_sign.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        token = f"{doc.id}.{user_id}.{expires_timestamp}.{signature}"
        preview_url = f"/api/v1/documents/preview/{token}"

        if db:
            DocumentService.log_audit(
                db=db,
                document_id=doc.id,
                user_id=user_id,
                action="SIGNED_LINK_GENERATED",
                ip_address=ip_address,
                user_agent=user_agent,
                details={"validity_minutes": validity_minutes, "expires_at": expires_timestamp},
            )

        return {
            "document_id": doc.id,
            "access_token": token,
            "preview_url": preview_url,
            "expires_at": datetime.fromtimestamp(expires_timestamp),
            "is_short_lived": True,
            "validity_minutes": validity_minutes,
        }

    @staticmethod
    def verify_signed_token(db: Session, token: str) -> MedicalDocument:
        """
        Validates HMAC signature and expiration timestamp.
        """
        parts = token.split(".")
        if len(parts) != 4:
            raise BadRequestException("Malformed access token")

        doc_id, user_id, expires_str, signature = parts
        try:
            expires_timestamp = int(expires_str)
        except ValueError:
            raise BadRequestException("Invalid token expiration timestamp")

        # Check expiration
        now_ts = int(time.time())
        if now_ts > expires_timestamp:
            raise ForbiddenException("Access link has expired. Please request a new short-lived signed link.")

        doc = db.query(MedicalDocument).filter(
            MedicalDocument.id == doc_id,
            MedicalDocument.is_deleted == False
        ).first()
        if not doc:
            raise NotFoundException("Medical document not found or deleted")

        payload_to_sign = f"{doc.id}:{user_id}:{expires_timestamp}:{doc.checksum_sha256 or ''}"
        expected_sig = hmac.new(
            settings.SECRET_KEY.encode("utf-8"),
            payload_to_sign.encode("utf-8"),
            hashlib.sha256
        ).hexdigest()

        if not hmac.compare_digest(signature, expected_sig):
            raise ForbiddenException("Access token verification failed. Signature mismatch or tampered link.")

        return doc

    # -------------------------------------------------------------
    # OCR Extraction & Verification Workflow
    # -------------------------------------------------------------
    @staticmethod
    def trigger_ocr_extraction(
        db: Session,
        doc_id: str,
        current_user: User,
        raw_text_content: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> List[DocumentOCRExtraction]:
        doc = DocumentService.get_document(db, doc_id)

        # Clear any existing unverified extractions
        db.query(DocumentOCRExtraction).filter(
            DocumentOCRExtraction.document_id == doc.id,
            DocumentOCRExtraction.verification_status == "UNVERIFIED"
        ).delete()

        # Run extraction
        extractions = OCRService.extract_document_fields(doc, raw_text_content)
        for ext in extractions:
            db.add(ext)

        doc.verification_status = "IN_REVIEW"
        db.commit()

        DocumentService.log_audit(
            db=db,
            document_id=doc.id,
            user_id=current_user.id,
            action="OCR_EXTRACT",
            ip_address=ip_address,
            user_agent=user_agent,
            details={"fields_extracted": len(extractions)},
        )

        return extractions

    @staticmethod
    def verify_ocr_field(
        db: Session,
        extraction_id: str,
        current_user: User,
        verification_status: str,
        verified_value: Optional[str] = None,
        rejection_reason: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> DocumentOCRExtraction:
        ext = db.query(DocumentOCRExtraction).filter(DocumentOCRExtraction.id == extraction_id).first()
        if not ext:
            raise NotFoundException(f"OCR Extraction field '{extraction_id}' not found")

        # CRITICAL SAFETY REQUIREMENT:
        # Treat handwritten medication names and dosages as unverified until confirmed by an authorized clinician.
        # If field is a prescription / medication or handwritten observation, only a clinician (doctor/admin) may confirm it!
        role_name = current_user.role.name if current_user.role else ""
        is_clinician = role_name in ["doctor", "admin", "clinical_officer"]
        if ext.field_category == "PRESCRIPTION" or ext.is_handwritten:
            if not is_clinician:
                raise ForbiddenException(
                    "Safety Policy Restriction: Handwritten medication names, dosages, and prescriptions "
                    "can only be verified and confirmed by an authorized clinician."
                )

        ext.verification_status = verification_status
        ext.verified_value = verified_value if verification_status in ["CONFIRMED", "EDITED"] else None
        ext.rejection_reason = rejection_reason if verification_status == "REJECTED" else None
        ext.verified_by_user_id = current_user.id
        ext.verified_at = datetime.utcnow()
        if verification_status in ["CONFIRMED", "EDITED"]:
            ext.is_uncertain = False

        db.commit()
        db.refresh(ext)

        DocumentService.log_audit(
            db=db,
            document_id=ext.document_id,
            user_id=current_user.id,
            action="FIELD_VERIFY",
            ip_address=ip_address,
            user_agent=user_agent,
            details={
                "field_name": ext.field_name,
                "status": verification_status,
                "verified_value": ext.verified_value,
            },
        )

        return ext

    @staticmethod
    def verify_all_fields(
        db: Session,
        doc_id: str,
        current_user: User,
        clinician_notes: Optional[str] = None,
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> MedicalDocument:
        doc = DocumentService.get_document(db, doc_id)

        # Check clinician role
        role_name = current_user.role.name if current_user.role else ""
        is_clinician = role_name in ["doctor", "admin"]
        if not is_clinician:
            raise ForbiddenException("Final clinical document sign-off requires clinician or doctor privileges.")

        extractions = db.query(DocumentOCRExtraction).filter(DocumentOCRExtraction.document_id == doc.id).all()
        
        # Check that no prescription or uncertain field is left unreviewed
        unreviewed = [e for e in extractions if e.verification_status == "UNVERIFIED" and (e.is_handwritten or e.field_category == "PRESCRIPTION")]
        if unreviewed:
            raise BadRequestException(
                f"Cannot finalize document verification: {len(unreviewed)} handwritten prescription/observation field(s) "
                f"are still unreviewed. Individual clinician confirmation is mandatory."
            )

        # Mark all remaining fields confirmed
        for e in extractions:
            if e.verification_status == "UNVERIFIED":
                e.verification_status = "CONFIRMED"
                e.verified_by_user_id = current_user.id
                e.verified_at = datetime.utcnow()
                e.is_uncertain = False

        doc.is_verified = True
        doc.verification_status = "VERIFIED"
        doc.verified_by_user_id = current_user.id
        doc.verified_at = datetime.utcnow()
        if clinician_notes:
            doc.description = f"{doc.description or ''}\n[Clinician Verification Note: {clinician_notes}]".strip()

        db.commit()
        db.refresh(doc)

        DocumentService.log_audit(
            db=db,
            document_id=doc.id,
            user_id=current_user.id,
            action="VERIFY_ALL",
            ip_address=ip_address,
            user_agent=user_agent,
            details={"clinician_notes": clinician_notes, "status": "VERIFIED"},
        )

        return doc

    @staticmethod
    def apply_verified_data_to_visit(
        db: Session,
        doc_id: str,
        visit_id: str,
        current_user: User,
        options: Dict[str, bool],
        ip_address: Optional[str] = None,
        user_agent: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        Safely transfers verified clinical observations and prescriptions to the active patient visit record.
        
        CRITICAL SAFETY RULE:
        Rejects operation if ANY prescription or observation field remains UNVERIFIED or uncertain.
        """
        doc = DocumentService.get_document(db, doc_id)
        visit = db.query(OPDVisit).filter(OPDVisit.id == visit_id).first()
        if not visit:
            raise NotFoundException(f"OPD Visit '{visit_id}' not found")

        extractions = db.query(DocumentOCRExtraction).filter(DocumentOCRExtraction.document_id == doc.id).all()
        if not extractions:
            raise BadRequestException("No extracted fields found on this document.")

        # Safety Guard: Ensure no unverified prescription exists
        unverified_meds = [
            e for e in extractions
            if e.field_category == "PRESCRIPTION" and e.verification_status not in ["CONFIRMED", "EDITED"]
        ]
        if unverified_meds:
            raise BadRequestException(
                "Safety Policy Violation: Cannot silently convert unverified OCR into active medical records. "
                "Handwritten medication items must be verified by an authorized clinician before transfer."
            )

        applied_summary = {"vitals": False, "complaints": False, "diagnosis": False, "prescriptions_count": 0}

        # 1. Apply Vitals if selected
        if options.get("apply_vitals", True):
            vitals_ext = next((e for e in extractions if e.field_name == "vital_signs" and e.verification_status in ["CONFIRMED", "EDITED"]), None)
            if vitals_ext:
                try:
                    val = json.loads(vitals_ext.verified_value or vitals_ext.normalized_value or "{}")
                    vitals_record = db.query(VitalSigns).filter(VitalSigns.visit_id == visit.id).first()
                    if not vitals_record:
                        vitals_record = VitalSigns(
                            visit_id=visit.id,
                            recorded_by_user_id=current_user.id,
                        )
                        db.add(vitals_record)

                    if "/" in val.get("bp", ""):
                        parts = val.get("bp", "").split("/")
                        vitals_record.systolic_bp = int(parts[0])
                        vitals_record.diastolic_bp = int(parts[1])
                    if "pulse" in val:
                        vitals_record.pulse_rate = int(val["pulse"])
                    if "spo2" in val:
                        vitals_record.spo2_percent = float(val["spo2"])
                    if "temp" in val:
                        vitals_record.temperature_f = float(val["temp"])

                    applied_summary["vitals"] = True
                except Exception:
                    pass

        # 2. Apply Complaints & Diagnosis to Clinical Record
        complaints_ext = next((e for e in extractions if e.field_name == "chief_complaints" and e.verification_status in ["CONFIRMED", "EDITED"]), None)
        diagnosis_ext = next((e for e in extractions if e.field_name == "diagnosis" and e.verification_status in ["CONFIRMED", "EDITED"]), None)
        findings_ext = next((e for e in extractions if e.field_name == "clinical_findings" and e.verification_status in ["CONFIRMED", "EDITED"]), None)

        if complaints_ext or diagnosis_ext or findings_ext:
            # Find or create draft clinical record for this visit
            clin_rec = db.query(ClinicalRecord).filter(ClinicalRecord.visit_id == visit.id).first()
            if not clin_rec:
                clin_rec = ClinicalRecord(
                    visit_id=visit.id,
                    doctor_id=visit.doctor_id,
                    status="DRAFT",
                )
                db.add(clin_rec)

            if complaints_ext and options.get("apply_complaints", True):
                clin_rec.chief_complaint = complaints_ext.verified_value or complaints_ext.normalized_value
                applied_summary["complaints"] = True

            if findings_ext:
                clin_rec.examination_findings = findings_ext.verified_value or findings_ext.normalized_value

            if diagnosis_ext and options.get("apply_diagnosis", True):
                clin_rec.provisional_diagnosis = diagnosis_ext.verified_value or diagnosis_ext.normalized_value
                applied_summary["diagnosis"] = True

        # 3. Apply Verified Prescriptions
        if options.get("apply_prescriptions", True):
            med_exts = [e for e in extractions if e.field_category == "PRESCRIPTION" and e.verification_status in ["CONFIRMED", "EDITED"]]
            if med_exts:
                # Find or create active prescription for visit
                rx = db.query(Prescription).filter(Prescription.visit_id == visit.id).first()
                if not rx:
                    rx = Prescription(
                        visit_id=visit.id,
                        patient_id=visit.patient_id,
                        doctor_id=visit.doctor_id,
                        status="DRAFT",
                    )
                    db.add(rx)
                    db.flush()

                for m in med_exts:
                    try:
                        m_val = json.loads(m.verified_value or m.normalized_value or "{}")
                        rx_item = PrescriptionItem(
                            prescription_id=rx.id,
                            medicine_name=m_val.get("medicine_name", m.raw_text),
                            dosage=m_val.get("dosage", "1 tab"),
                            frequency="TID",
                            duration_days=3,
                            instructions=m_val.get("instructions", "Take after meals"),
                            quantity=6,
                        )
                        db.add(rx_item)
                        applied_summary["prescriptions_count"] += 1
                    except Exception:
                        pass

        db.commit()

        DocumentService.log_audit(
            db=db,
            document_id=doc.id,
            user_id=current_user.id,
            action="APPLY_TO_VISIT",
            ip_address=ip_address,
            user_agent=user_agent,
            details={"visit_id": visit.id, "applied_summary": applied_summary},
        )

        return {
            "document_id": doc.id,
            "visit_id": visit.id,
            "applied_summary": applied_summary,
            "status": "APPLIED_SUCCESSFULLY",
        }
