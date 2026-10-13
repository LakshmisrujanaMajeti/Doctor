from datetime import datetime
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.core.database import Base
from app.models.base import TimestampMixin, generate_uuid


class LabOrder(Base, TimestampMixin):
    __tablename__ = "lab_orders"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    order_number = Column(String(50), nullable=True, unique=True, index=True)
    visit_id = Column(String(36), ForeignKey("opd_visits.id", ondelete="CASCADE"), nullable=False, index=True)
    patient_id = Column(String(36), ForeignKey("patients.id", ondelete="CASCADE"), nullable=False, index=True)
    ordered_by_doctor_id = Column(String(36), ForeignKey("doctors.id"), nullable=False, index=True)

    test_name = Column(String(150), nullable=False, index=True)  # e.g. Glucose Fasting, Haemoglobin (Hb)
    test_category = Column(String(50), default="HAEMATOLOGY", nullable=False, index=True)  # BIOCHEMISTRY, HAEMATOLOGY, MICROBIOLOGY
    status = Column(String(30), default="ORDERED", nullable=False, index=True)  # ORDERED, COLLECTED, RECEIVED, PROCESSING, COMPLETED, REJECTED, CANCELLED
    clinical_indication = Column(Text, nullable=True)

    # Specimen Lifecycle Tracking
    specimen_id = Column(String(50), nullable=True, index=True)  # e.g. SPEC-20261012-0001
    specimen_type = Column(String(80), nullable=True)  # e.g. Whole Blood (EDTA), Plasma (Fluoride), Serum, Urine
    specimen_status = Column(String(30), default="PENDING_COLLECTION", nullable=False, index=True)  # PENDING_COLLECTION, COLLECTED, RECEIVED, PROCESSING, REJECTED
    collected_at = Column(DateTime, nullable=True)
    collected_by_name = Column(String(100), nullable=True)
    received_at = Column(DateTime, nullable=True)
    received_by_name = Column(String(100), nullable=True)
    rejection_reason = Column(Text, nullable=True)

    # Clinical Safety, Rules & Privacy
    is_sensitive = Column(Boolean, default=False, nullable=False, index=True)  # HIV, VDRL stricter authorization
    requires_review = Column(Boolean, default=False, nullable=False)  # Flagged if abnormal or critical
    verified_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)
    verified_by_name = Column(String(100), nullable=True)
    verified_at = Column(DateTime, nullable=True)
    verification_notes = Column(Text, nullable=True)
    published_to_visit = Column(Boolean, default=False, nullable=False)

    ordered_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    completed_at = Column(DateTime, nullable=True)

    visit = relationship("OPDVisit", back_populates="lab_orders")
    patient = relationship("Patient")
    ordered_by_doctor = relationship("Doctor")
    verified_by_user = relationship("User", foreign_keys=[verified_by_user_id])
    results = relationship("LabResult", back_populates="lab_order", cascade="all, delete-orphan")


class LabResult(Base, TimestampMixin):
    __tablename__ = "lab_results"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    lab_order_id = Column(String(36), ForeignKey("lab_orders.id", ondelete="CASCADE"), nullable=False, index=True)
    verified_by_user_id = Column(String(36), ForeignKey("users.id"), nullable=True)

    parameter_name = Column(String(100), nullable=False)  # e.g. Fasting Blood Glucose, Haemoglobin
    result_value = Column(String(50), nullable=False)    # e.g. 102, 13.5
    unit = Column(String(30), nullable=True)            # e.g. mg/dL, g/dL
    reference_range = Column(String(100), nullable=True)  # Optional configured reference range (not invented)
    is_abnormal = Column(Boolean, default=False, nullable=False)
    is_critical = Column(Boolean, default=False, nullable=False)
    flag = Column(String(20), default="NORMAL", nullable=False)  # NORMAL, ABNORMAL, CRITICAL
    notes = Column(Text, nullable=True)

    reported_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    verified_at = Column(DateTime, nullable=True)

    lab_order = relationship("LabOrder", back_populates="results")
