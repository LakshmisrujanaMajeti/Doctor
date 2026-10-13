from datetime import datetime
from sqlalchemy import Column, String, Integer, Float, Boolean, ForeignKey, Text, DateTime
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class MedicalDocument(Base, TimestampMixin):
    """
    Secure document attachments including scanned physical OPD booklet pages,
    diagnostic imaging, ECGs, prescriptions, and digital lab reports.
    """
    __tablename__ = "medical_documents"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="SET NULL"), nullable=True, index=True)
    uploaded_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    document_type = Column(String(50), default="OPD_BOOKLET_SCAN", nullable=False, index=True)
    # Types: OPD_BOOKLET_SCAN, LAB_REPORT, PRESCRIPTION_SCAN, INVOICE_SCAN, DISCHARGE_SUMMARY, ID_PROOF
    file_name = Column(String(255), nullable=False)
    file_path = Column(String(500), nullable=False)  # Local storage path or object store key
    file_size_bytes = Column(Integer, nullable=False)
    mime_type = Column(String(100), nullable=False)
    storage_bucket = Column(String(100), default="medical-documents", nullable=False)
    is_private = Column(Boolean, default=True, nullable=False)
    description = Column(Text, nullable=True)
    page_count = Column(Integer, default=1, nullable=False)
    checksum_sha256 = Column(String(64), nullable=True)

    # Verification workflow
    is_verified = Column(Boolean, default=False, nullable=False)
    verification_status = Column(String(30), default="UNVERIFIED", nullable=False, index=True)
    # Statuses: UNVERIFIED, IN_REVIEW, VERIFIED, REJECTED
    verified_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    verified_at = Column(DateTime, nullable=True)

    # Soft deletion
    is_deleted = Column(Boolean, default=False, nullable=False)
    deleted_at = Column(DateTime, nullable=True)
    deleted_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    # Relationships
    patient = relationship("Patient", back_populates="documents")
    visit = relationship("OPDVisit", back_populates="documents")
    uploaded_by = relationship("User", foreign_keys=[uploaded_by_user_id])
    verified_by = relationship("User", foreign_keys=[verified_by_user_id])
    deleted_by = relationship("User", foreign_keys=[deleted_by_user_id])

    pages = relationship(
        "DocumentPage",
        back_populates="document",
        cascade="all, delete-orphan",
        order_by="DocumentPage.page_number"
    )
    ocr_extractions = relationship(
        "DocumentOCRExtraction",
        back_populates="document",
        cascade="all, delete-orphan"
    )
    audit_logs = relationship(
        "DocumentAuditLog",
        back_populates="document",
        cascade="all, delete-orphan",
        order_by="DocumentAuditLog.created_at.desc()"
    )


class DocumentPage(Base, TimestampMixin):
    """
    Individual page representation for multi-page captures, booklet scans,
    supporting crop, rotation, and perspective correction.
    """
    __tablename__ = "document_pages"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    document_id = Column(String(36), ForeignKey("medical_documents.id", ondelete="CASCADE"), nullable=False, index=True)
    page_number = Column(Integer, nullable=False)
    file_path = Column(String(500), nullable=False)
    file_size_bytes = Column(Integer, default=0, nullable=False)
    width = Column(Integer, default=1200, nullable=False)
    height = Column(Integer, default=1600, nullable=False)
    rotation_angle = Column(Integer, default=0, nullable=False)  # 0, 90, 180, 270
    has_perspective_correction = Column(Boolean, default=False, nullable=False)
    contrast_enhanced = Column(Boolean, default=False, nullable=False)

    document = relationship("MedicalDocument", back_populates="pages")


class DocumentOCRExtraction(Base, TimestampMixin):
    """
    Structured OCR extracted fields from scanned booklets and clinical records.
    Every field preserves source bounding box, confidence, and strict verification tracking.
    """
    __tablename__ = "document_ocr_extractions"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    document_id = Column(String(36), ForeignKey("medical_documents.id", ondelete="CASCADE"), nullable=False, index=True)
    page_number = Column(Integer, default=1, nullable=False)

    field_category = Column(String(50), nullable=False, index=True)
    # Categories: PATIENT_IDENTIFIER, DATE, OBSERVATION, TEST_NAME, PRESCRIPTION, INVOICE
    field_name = Column(String(100), nullable=False, index=True)
    # e.g.: uhid, patient_name, consultation_date, blood_pressure, complaint, diagnosis, test_name,
    #       medicine_name, dosage, frequency, duration, invoice_number, total_amount

    raw_text = Column(Text, nullable=False)
    normalized_value = Column(Text, nullable=True)
    confidence = Column(Float, nullable=False, default=1.0)  # 0.0 to 1.0
    is_uncertain = Column(Boolean, default=False, nullable=False)
    is_handwritten = Column(Boolean, default=False, nullable=False)

    bounding_box_json = Column(Text, nullable=True)  # JSON: {"x": 100, "y": 200, "width": 300, "height": 50}

    # Clinical Verification Status
    verification_status = Column(String(30), default="UNVERIFIED", nullable=False, index=True)
    # UNVERIFIED, CONFIRMED, EDITED, REJECTED
    verified_value = Column(Text, nullable=True)
    verified_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    verified_at = Column(DateTime, nullable=True)
    rejection_reason = Column(Text, nullable=True)

    document = relationship("MedicalDocument", back_populates="ocr_extractions")
    verified_by = relationship("User", foreign_keys=[verified_by_user_id])


class DocumentAuditLog(Base):
    """
    Traceable security log recording every document operation, authorization check,
    signed link generation, download, and clinical verification action.
    """
    __tablename__ = "document_audit_logs"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    document_id = Column(String(36), ForeignKey("medical_documents.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    action = Column(String(50), nullable=False, index=True)
    # Actions: UPLOAD, PREVIEW, DOWNLOAD, SIGNED_LINK_GENERATED, OCR_EXTRACT, FIELD_VERIFY, VERIFY_ALL, APPLY_TO_VISIT, DELETE
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(255), nullable=True)
    details_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    document = relationship("MedicalDocument", back_populates="audit_logs")
    user = relationship("User", foreign_keys=[user_id])
